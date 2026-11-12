import base64
import hashlib
import json
import os
from pathlib import Path
import socket
import struct
import subprocess
import sys
import tempfile
import threading
import time
import unittest
import uuid


SCRIPT = Path(__file__).resolve().parents[1] / "scripts/agy_callback.py"


class FakeAppServer(threading.Thread):
    def __init__(self, path, marker, drop_after_send=False, thread_status="active", stop_after_preflight=False):
        super().__init__(daemon=True)
        self.path, self.marker, self.drop_after_send = path, marker, drop_after_send
        self.thread_status = thread_status
        self.stop_after_preflight = stop_after_preflight
        self.requests = []
        self.error = None
        self.ready = threading.Event()

    def run(self):
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as server:
                server.bind(str(self.path))
                server.listen(1)
                self.ready.set()
                server.settimeout(10)
                for attempt in range(2):
                    conn, _ = server.accept()
                    self.handle_connection(conn)
                    if attempt == 0 and self.stop_after_preflight:
                        break
        except Exception as exc:
            self.error = exc
            self.ready.set()

    def handle_connection(self, conn):
        with conn:
            conn.settimeout(10)
            reader = conn.makefile("rb")
            headers = {}
            reader.readline()
            while True:
                line = reader.readline()
                if line == b"\r\n":
                    break
                key, value = line.split(b":", 1)
                headers[key.lower()] = value.strip()
            accept = base64.b64encode(hashlib.sha1(headers[b"sec-websocket-key"] + b"258EAFA5-E914-47DA-95CA-C5AB0DC85B11").digest())
            conn.sendall(b"HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: " + accept + b"\r\n\r\n")
            while True:
                header = reader.read(2)
                if not header:
                    break
                size = header[1] & 127
                if size == 126:
                    size = struct.unpack("!H", reader.read(2))[0]
                elif size == 127:
                    size = struct.unpack("!Q", reader.read(8))[0]
                mask = reader.read(4)
                payload = reader.read(size)
                message = json.loads(bytes(value ^ mask[i % 4] for i, value in enumerate(payload)))
                self.requests.append(message)
                method = message["method"]
                if method == "initialized":
                    continue
                if method == "turn/start" and not self.marker.exists():
                    raise AssertionError("callback arrived before agy exited")
                if method == "turn/start" and self.drop_after_send:
                    break
                result = {"thread": {"status": {"type": self.thread_status}}} if method == "thread/read" else {}
                encoded = json.dumps({"id": message["id"], "result": result}).encode()
                frame = bytes((0x81, len(encoded))) if len(encoded) < 126 else bytes((0x81, 126)) + struct.pack("!H", len(encoded))
                conn.sendall(frame + encoded)


class CallbackTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.repo = self.root / "repo"
        self.repo.mkdir()
        subprocess.run(["git", "init", "-q", str(self.repo)], check=True)
        (self.repo / ".gitignore").write_text(".agy-sessions/\n")
        self.bin = self.root / "bin"
        self.bin.mkdir()
        for name in ("agy-run", "agy-task"):
            fake = self.bin / name
            fake.write_text('#!/bin/sh\nsleep 0.2\nprintf done > "$FAKE_MARKER"\nexit "${FAKE_EXIT:-0}"\n')
            fake.chmod(0o755)
        self.marker = self.root / "completed"
        self.sock = self.root / "app.sock"
        self.thread_id = str(uuid.uuid4())
        self.env = os.environ.copy()
        self.env.update(PATH=str(self.bin) + os.pathsep + self.env["PATH"], FAKE_MARKER=str(self.marker), FAKE_EXIT="3")

    def tearDown(self):
        self.temp.cleanup()

    def launch(self, name="demo", result=None, command_log=None):
        result = result or self.repo / ".agy-sessions/demo.jsonl"
        return subprocess.run([sys.executable, str(SCRIPT), "--name", name, "--repo", str(self.repo),
                               "--result", str(result), "--thread", self.thread_id, "--socket", str(self.sock),
                               "--", "agy-run", "--log", str(command_log or result)],
                              env=self.env, text=True, capture_output=True)

    def wait_for_state(self, target):
        path = self.repo / ".agy-sessions/demo.callback.json"
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            if path.exists():
                state = json.loads(path.read_text())
                if state.get("status") in target:
                    return state
            time.sleep(0.05)
        self.fail("callback worker did not reach a terminal state")

    def test_callback_arrives_after_job_and_is_not_duplicated(self):
        server = FakeAppServer(self.sock, self.marker)
        server.start()
        self.assertTrue(server.ready.wait(2))
        launched = self.launch()
        self.assertEqual(launched.returncode, 0, launched.stderr)
        state = self.wait_for_state({"delivered", "callback_failed", "delivery_unknown"})
        self.assertEqual(state["status"], "delivered", state)
        self.assertEqual(state["exit_code"], 3)
        server.join(2)
        self.assertIsNone(server.error)
        starts = [m for m in server.requests if m["method"] == "turn/start"]
        self.assertEqual(len(starts), 1)
        params = starts[0]["params"]
        self.assertEqual(params["threadId"], self.thread_id)
        self.assertEqual(params["input"], [])
        self.assertIn("exit code 3", params["toolOutput"]["output"])
        self.assertIn("demo.jsonl", params["toolOutput"]["output"])
        self.assertNotEqual(self.launch().returncode, 0)

    def test_missing_socket_prevents_job_from_starting(self):
        self.assertNotEqual(self.launch().returncode, 0)
        self.assertFalse(self.marker.exists())

    def test_socket_failure_after_preflight_is_recorded(self):
        server = FakeAppServer(self.sock, self.marker, stop_after_preflight=True)
        server.start()
        self.assertTrue(server.ready.wait(2))
        self.assertEqual(self.launch().returncode, 0)
        state = self.wait_for_state({"delivered", "callback_failed", "delivery_unknown"})
        self.assertEqual(state["status"], "callback_failed", state)
        self.assertEqual(state["exit_code"], 3)
        server.join(2)
        self.assertIsNone(server.error)

    def test_unloaded_thread_is_resumed_before_callback(self):
        server = FakeAppServer(self.sock, self.marker, thread_status="notLoaded")
        server.start()
        self.assertTrue(server.ready.wait(2))
        self.assertEqual(self.launch().returncode, 0)
        state = self.wait_for_state({"delivered", "callback_failed", "delivery_unknown"})
        self.assertEqual(state["status"], "delivered", state)
        server.join(2)
        self.assertIsNone(server.error)
        methods = [m["method"] for m in server.requests]
        self.assertLess(methods.index("thread/resume"), methods.index("turn/start"))

    def test_lost_ack_is_marked_unknown_without_retry(self):
        server = FakeAppServer(self.sock, self.marker, drop_after_send=True)
        server.start()
        self.assertTrue(server.ready.wait(2))
        self.assertEqual(self.launch().returncode, 0)
        state = self.wait_for_state({"delivered", "callback_failed", "delivery_unknown"})
        self.assertEqual(state["status"], "delivery_unknown", state)
        server.join(2)
        self.assertIsNone(server.error)
        self.assertEqual(sum(m["method"] == "turn/start" for m in server.requests), 1)

    def test_result_outside_sessions_is_rejected(self):
        launched = self.launch(result=self.root / "outside.jsonl")
        self.assertNotEqual(launched.returncode, 0)
        self.assertFalse(self.marker.exists())

    def test_mismatched_log_is_rejected(self):
        launched = self.launch(command_log=self.repo / ".agy-sessions/other.jsonl")
        self.assertNotEqual(launched.returncode, 0)
        self.assertFalse(self.marker.exists())

    def test_existing_output_is_not_overwritten(self):
        sessions = self.repo / ".agy-sessions"
        sessions.mkdir()
        output = sessions / "demo.callback.log"
        output.write_text("existing output")
        self.assertNotEqual(self.launch().returncode, 0)
        self.assertEqual(output.read_text(), "existing output")
        self.assertFalse((sessions / "demo.callback.json").exists())

    def test_agy_task_callback_uses_matching_summary(self):
        server = FakeAppServer(self.sock, self.marker)
        server.start()
        self.assertTrue(server.ready.wait(2))
        result = self.repo / ".agy-sessions/demo.summary.txt"
        launched = subprocess.run([sys.executable, str(SCRIPT), "--name", "demo", "--repo", str(self.repo),
                                   "--result", str(result), "--thread", self.thread_id, "--socket", str(self.sock),
                                   "--", "agy-task", "run", "--name", "demo"],
                                  env=self.env, text=True, capture_output=True)
        self.assertEqual(launched.returncode, 0, launched.stderr)
        state = self.wait_for_state({"delivered", "callback_failed", "delivery_unknown"})
        self.assertEqual(state["status"], "delivered", state)
        server.join(2)
        self.assertIsNone(server.error)
        self.assertIn("demo.summary.txt", server.requests[-1]["params"]["toolOutput"]["output"])


if __name__ == "__main__":
    unittest.main()
