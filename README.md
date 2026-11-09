# agyr

Rotate seamlessly between multiple Google accounts for `agy` (Antigravity CLI / Google DeepMind coding agent) without hitting quota walls, and inspect each account's real quota in real time.

![agyr list](docs/assets/agyr-list.svg)

---

## 3 Core USPs (Unique Selling Points)

- 🔒 **100% Local & Privacy-First**
  No external servers, no cloud middleman. Your OAuth tokens stay strictly on your local disk (`chmod 600`) or native OS credential store (Windows Credential Manager / Linux secret store). `agyr` never reads or sends your credentials anywhere.
- 🛡️ **Zero-Ban Risk**
  No reverse-engineered proxy server, no datacenter IP blacklists, and no TLS/HTTP fingerprint anomalies. `agyr` invokes the official `agy` binary directly with genuine client authentication.
- ⚡ **Seamless Auto-Rotation on 429**
  Instantly detects 429 quota exhaustion, sets a precise cooldown based on Google's reset header, picks the ready account whose weekly limit resets soonest, and resumes the exact same conversation with `agy --conversation` without losing context.

![Auto-rotation demo](docs/assets/auto-rotate-demo.svg)

---

## Why agyr? (Architecture Comparison)

| Feature | `agyr` (Native CLI Swapper) | Proxy Routers (e.g. `9router`) |
|:---|:---|:---|
| **Architecture** | **Direct local CLI execution** via official `agy` binary | Local/remote reverse HTTP/SOCKS proxy daemon |
| **Account Ban Risk** | **Zero** — Uses authentic Google CLI binary &amp; TLS fingerprints | **High** — Fake TLS fingerprints, cloud/datacenter IP flags |
| **Credential Privacy** | **100% Local** — Tokens stay `chmod 600` on your machine | Tokens intercepted or relayed through proxy daemon |
| **Antigravity CLI Updates** | **Immediate** — Compatible with official `agy` updates instantly | Frequently breaks whenever Google updates API schemas or SSE |
| **429 Failover &amp; Resume** | **Native resume** — Automatically resumes conversation context | Drops session or requires expensive prompt replay |
| **Resource Usage** | **Pure Bash** — 0 MB background RAM, no persistent daemon | Background Node.js / Go / Docker container running 24/7 |
| **Platform Support** | Linux (D-Bus keyring isolation) &amp; Windows (Credential Manager) | Varies; often requires complex Docker or loopback setups |

---

## Quick Installation

Requires `bash`, `git`, and `jq`.

### One-Line Install (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/luongtrz/rotate-agy/main/install.sh | bash
```

To install into a custom directory (e.g., `~/bin`):
```bash
curl -fsSL https://raw.githubusercontent.com/luongtrz/rotate-agy/main/install.sh | bash -s -- ~/bin
```

### Manual Clone

```bash
git clone https://github.com/luongtrz/rotate-agy.git ~/tools/agy-acct

# Unified auto-detect installer (recommended):
bash ~/tools/agy-acct/install.sh

# Or invoke the specific platform installer directly:
bash ~/tools/agy-acct/platforms/linux/install.sh       # Linux: symlinks into ~/.local/bin
bash ~/tools/agy-acct/platforms/windows/install.sh     # Windows: Git Bash + .cmd wrappers into ~/.local/bin
```

AI agents installing this repository should follow [AGENT.MCP.md](AGENT.MCP.md).

---

## Platform Backends

- **Linux (`file` backend):** `agy` stores its login in the token file (`~/.gemini/antigravity-cli/antigravity-oauth-token`). `agyr` and `agy-run` isolate the GNOME keyring over D-Bus (`DBUS_SESSION_BUS_ADDRESS=unix:path=/nonexistent`) so `agy` reads the swapped token file instead of falling back to system keyring credentials.
- **Windows (`wincred` backend):** `agy` stores its login in Windows Credential Manager (`gemini:antigravity`). `agyr` swaps slots directly into Credential Manager. Both Git Bash shell scripts and Windows `.cmd` wrappers are generated, allowing `agyr`, `agy-run`, and `agy-task` to be invoked directly from Git Bash, Windows PowerShell, and Command Prompt (CMD).

---

## Command Reference

### Daily Account Management

```bash
agyr list                  # Show real-time quota table for all accounts (* = active; 0 tokens)
agyr list --claude         # Include Claude 5-hour and weekly quota columns
agyr list -w               # Wide format: prevent auto-collapsing optional model columns
agyr list -c               # Display cached quota data without making API calls
agyr use <name>            # Switch active account to <name>
agyr save <name>           # Save current interactive sign-in as an account slot
agyr swapui <n1> <n2>      # Swap UI display order of two accounts in 'agyr list' (--reset to restore)
agyr del <name>            # Permanently delete an account slot (alias: rm)
agyr rotate [cooldown]     # Manually rotate to the next ready account with cooldown
agyr test [name...]        # Send "Hi" to every account to start its 5-hour quota window
agyr forget                # Clear local active login before signing in to a new account
agyr help [command]        # Detailed command documentation
```

### Automation & AI Agents

- **`agy-run`**: Runs `agy` non-interactively with automatic 429 failover. When quota runs out, `agy-run` terminates the process immediately, sets account cooldown, switches to the next account whose weekly limit resets soonest, and resumes the exact same conversation.
- **`agy-task`**: Orchestrates coding tasks in dedicated, isolated git worktrees for AI orchestrators (Claude Code, Antigravity, Gemini).

---

## AI Agent Orchestration

`agyr` includes a first-class skill in `skills/agy/` designed for Claude Code, Antigravity, and Gemini agents to delegate implementation and investigation tasks to `agy` as a sub-agent.

For complete setup instructions, see:
- [docs/agent-setup.md](docs/agent-setup.md): Configure `CLAUDE.md`, `GEMINI.md`, and `AGENTS.md`.
- [AGENT.MCP.md](AGENT.MCP.md): Agent setup and verification protocol.

---

## Hướng dẫn Tiếng Việt

`agyr` là công cụ dòng lệnh (CLI) giúp quản lý và xoay vòng nhiều tài khoản Google cho `agy` (Google Antigravity CLI). Khi một tài khoản chạm giới hạn (lỗi `429 Quota Exceeded`), `agyr` tự động phát hiện, đưa tài khoản đó vào thời gian chờ (cooldown) và chuyển sang tài khoản sẵn sàng tiếp theo mà không làm gián đoạn công việc của bạn.

### Điểm nổi bật
- **An toàn tuyệt đối:** Gọi trực tiếp binary `agy` chính thức từ Google, không dùng proxy trung gian nên không bao giờ bị khóa tài khoản (Zero-Ban Risk).
- **Bảo mật 100%:** Token OAuth được lưu an toàn trên máy cục bộ với quyền `chmod 600` hoặc Windows Credential Manager.
- **Tự động khôi phục phiên:** Khi đổi tài khoản, `agy-run` tự động phục hồi đúng session ID (`--conversation`) để tiếp tục ngữ cảnh đang làm việc.

### Cài đặt nhanh 1 dòng lệnh

Mở terminal (Linux hoặc Git Bash trên Windows) và chạy:

```bash
curl -fsSL https://raw.githubusercontent.com/luongtrz/rotate-agy/main/install.sh | bash
```

*(Yêu cầu máy đã cài sẵn `git` và `jq`).*

### Các bước thêm tài khoản Google

1. **Đăng nhập và lưu tài khoản đầu tiên:**
   ```bash
   agyr              # Mở trình duyệt để đăng nhập tài khoản Google thứ 1
   agyr save acc1    # Lưu tài khoản vừa đăng nhập vào slot 'acc1'
   ```

2. **Thêm tài khoản thứ hai (và các tài khoản tiếp theo):**
   ```bash
   agyr forget       # Xóa phiên đăng nhập hiện tại trên máy (slot acc1 vẫn an toàn)
   agyr              # Trình duyệt mở ra, đăng nhập tài khoản Google thứ 2
   agyr save acc2    # Lưu vào slot 'acc2'
   ```

3. **Kiểm tra trạng thái hạn ngạch (quota):**
   ```bash
   agyr list         # Xem bảng quota trực quan: xanh (đầy), vàng (trung bình), đỏ (sắp hết/cooldown)
   ```

4. **Chuyển đổi tài khoản thủ công:**
   ```bash
   agyr use acc1     # Chuyển sang dùng acc1
   agyr use acc2     # Chuyển sang dùng acc2
   ```

5. **Chạy tác vụ tự động:**
   ```bash
   # Tự động chuyển tài khoản khi gặp lỗi 429 và tiếp tục phiên làm việc:
   agy-run --add-dir . --prompt "Viết unit test cho auth service"
   ```

---

## Documentation

- [docs/reference.md](docs/reference.md): In-depth technical architecture, full command specifications, Linux and Windows platform backends, environment variables, known limitations.
- [docs/agent-setup.md](docs/agent-setup.md): Complete guide to installing `skills/agy` and configuring AI orchestrators.
- [AGENT.MCP.md](AGENT.MCP.md): Guide for AI agents installing and verifying `agyr`.

---

## Repository Layout

- `bin/`: `agyr`, `agy-run`, `agy-task` executables.
- `install.sh`: Unified installer (supports both local execution and `curl ... | bash` piping).
- `platforms/linux/`: Linux platform backend (D-Bus keyring bypass, symlink installer).
- `platforms/windows/`: Windows platform backend (`wincred`, Credential Manager helpers, Git Bash + `.cmd` wrappers).
- `skills/agy/`: AI agent skill for delegating tasks via `agy-task` and `agy-run`.
- `templates/`: Templates used by `agy-task` (`hard-rules.txt`, `agy-task.conf.example`).
- `docs/`: Technical reference (`reference.md`), orchestrator guide (`agent-setup.md`), and visual assets (`docs/assets/`).
- `test/`: Test runner (`run.sh`), shared core suite (`core.sh`), and platform suites (`linux.sh`, `windows.sh`).

---

## Tests

The test suite runs with fake tokens and a simulated `agy` binary; it never modifies real user credentials or consumes Google quota.

```bash
bash test/run.sh              # Run all suites (core + linux + windows; 930+ checks, never touches real logins)
bash test/run.sh core         # Run platform-independent core tests
bash test/run.sh linux        # Run Linux platform tests
bash test/run.sh windows      # Run Windows platform tests
```

---

## License

MIT, see [LICENSE](LICENSE).
