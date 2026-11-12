# Callback to the originating Codex thread

Prefer this Linux/Unix workflow for background agy jobs when the user wants Codex to finish its current turn while the job continues. It needs Python 3.9 or newer and access to the local Codex app-server Unix socket. Obtain any required approval normally; do not bypass the sandbox or approval policy.

Prepare the task prompt and HARD RULES as usual. Launch **one helper call per job**. Capture the real `CODEX_THREAD_ID`; do not guess a thread or use a most-recent-session shortcut. Each name must be unique and `.agy-sessions/` must be gitignored.

For a read-only `agy-run` job:

```bash
python3 "${AGY_SKILL_DIR:-$HOME/.agents/skills/agy-codex}/scripts/agy_callback.py" \
  --name <task> --repo "$REPO" --result "$REPO/.agy-sessions/<task>.jsonl" -- \
  agy-run --prompt "$REPO/.agy-sessions/<task>.txt" --add-dir "$REPO" \
    --log "$REPO/.agy-sessions/<task>.jsonl" --model gemini-3.8-flash-high
```

For an implementation job, use the same helper with `--result "$REPO/.agy-sessions/<task>.summary.txt"` and the usual `agy-task run --name <task> --task ... --scope ... --model ...` command. `--repo` must be the main checkout whose `.agy-sessions` contains that summary. The helper only accepts `agy-run` and `agy-task`; it does not add HARD RULES or verify scope on their behalf.

Before starting agy, the helper verifies it can reach the specified thread; if that check fails, no job is launched. On success, it immediately prints the worker PID and state/output paths. The detached worker runs the command and, when it exits, sends a small `agy_callback` tool output to the originating thread through its local app-server. The message contains the task name, exit code, and result path, not the log contents. The app-server queues tool output if the thread is busy. Codex should then follow the existing task: read the `agy-task` summary or filter only the final `agy-run` `result` event, check the outcome and report it. Do not launch new agy jobs merely because a callback arrived.

State is stored in `<repo>/.agy-sessions/<task>.callback.json`; worker output is in `<task>.callback.log`. `delivered` means the app-server accepted the callback, not that Codex has already completed its follow-up. `launch_failed` means the worker could not start; `callback_failed` means the callback could not be delivered; `delivery_unknown` means the connection was lost after sending, so a retry might duplicate it. No automatic retry occurs. If the app-server is unavailable, the worker is killed, or the machine stops, inspect the state and output files before deciding what to do. Keep the agy logs for diagnosis.
