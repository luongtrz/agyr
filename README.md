# agyr

Rotate between multiple Google accounts for `agy` (Antigravity CLI) when an account runs out of quota, and inspect each account's real quota.

- Uses only the official `agy` binary. No proxy, and never reads or prints token contents: it only swaps authentication tokens between saved slots.
- First-class support for both Linux and Windows.
- Using multiple accounts this way may conflict with Google's terms of service. Use in moderation.

## Platform backends

- **Linux (`file` backend):** agy stores its login in the token file (`~/.gemini/antigravity-cli/antigravity-oauth-token`). `agyr` and `agy-run` hide the GNOME keyring over D-Bus (`DBUS_SESSION_BUS_ADDRESS=unix:path=/nonexistent`) so agy reads the swapped token file instead of falling back to system keyring credentials.
- **Windows (`wincred` backend):** agy stores its login in Windows Credential Manager (`gemini:antigravity`). `agyr` swaps slots directly into Credential Manager. Both Git Bash shell scripts and Windows `.cmd` wrappers are generated, allowing `agyr`, `agy-run`, and `agy-task` to be invoked directly from Git Bash, Windows PowerShell, and Command Prompt (CMD).

## Quick install

Requires `bash`, `git`, and `jq`.

```bash
git clone https://github.com/luongtrz/rotate-agy.git ~/tools/agy-acct

# Unified auto-detect installer (recommended):
bash ~/tools/agy-acct/install.sh

# Or invoke the specific platform installer directly:
bash ~/tools/agy-acct/platforms/linux/install.sh       # Linux: symlinks into ~/.local/bin
bash ~/tools/agy-acct/platforms/windows/install.sh     # Windows: Git Bash + .cmd wrappers into ~/.local/bin
```

AI agents installing this repository should follow [AGENT.MCP.md](AGENT.MCP.md).

## Usage

```bash
agyr                  # start agy with the selected account
agyr list             # quota of all accounts (* marks the selected account)
agyr use <name>       # switch account
agyr save <name>      # save a manually logged-in account as a slot
agyr forget           # drop the local login before signing in to another account
agyr help             # command overview; agyr help <command> for details
```

Google sign-in is interactive: sign in with `agyr`, then run `agyr save <name>`.

## Documentation

- [docs/reference.md](docs/reference.md): how it works, full command reference, Linux and Windows platform backends, environment variables, known limitations.
- [docs/agent-setup.md](docs/agent-setup.md): how to install the `skills/agy` skill and configure `CLAUDE.md` / `GEMINI.md` / `AGENTS.md` for AI agent orchestration.
- [AGENT.MCP.md](AGENT.MCP.md): installation and verification guide for AI agents.

## Repository layout

- `bin/`: `agyr`, `agy-run`, `agy-task`
- `install.sh`: unified root installer (auto-detects OS via `uname -s`)
- `platforms/linux/`: Linux platform layer and installer (symlinks)
- `platforms/windows/`: Windows platform layer, Credential Manager helpers (`cred.sh`, `cred.ps1`, `inspect-cred.ps1`), and installer (Git Bash + `.cmd` wrappers)
- `skills/agy/`: skill for Claude Code / Antigravity / Gemini to delegate tasks through `agy-task` and `agy-run`
- `templates/`: runtime templates used by `agy-task` (`hard-rules.txt`, `agy-task.conf.example`)
- `docs/`: technical reference (`reference.md`) and orchestrator setup guide (`agent-setup.md`)
- `test/`: test runner (`run.sh`), shared core suite (`core.sh`), and platform suites (`linux.sh`, `windows.sh`)

## Tests

```bash
bash test/run.sh              # run all suites (core + linux + windows; 800 checks, never touches real logins)
bash test/run.sh core         # run only platform-independent core tests
bash test/run.sh linux        # run only Linux platform tests
bash test/run.sh windows      # run only Windows platform tests
```

## License

MIT, see [LICENSE](LICENSE).
