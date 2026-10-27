# agent.mcp.md: install agyr on a machine

This file is for an AI agent asked to install this repo on a machine. It is not an MCP server. The user does every Google login and every account save by hand.

The repo is `luongtrz/agyr` (public, MIT). The skill copy uses example account names (acc1, acc2, …).

## Hard rules

1. Never read, print, `cat`, `grep`, or copy these: `~/.gemini/antigravity-cli/antigravity-oauth-token`, anything in `~/.gemini/antigravity-cli/accounts/`, and the Windows Credential Manager entry `gemini:antigravity`. Checking that a file exists, or reading its mtime with `stat -c %Y`, is fine.
2. Do not log in, and do not run `agyr save`, `forget`, `rename`, `use`, `rotate` or `test` unless the user asks for it in this conversation. `agyr test` spends real quota.
3. Never start agy with a bare `agy -p`. Use `agyr`, `agy-run` or `agy-task`: they carry the keyring bypass that makes account switching work.
4. Do not overwrite files outside this repo (`~/.local/bin/*`, `~/.claude/skills/agy`, `~/.claude/CLAUDE.md`) without showing the diff and getting a yes.
5. Do not commit or push.

## 1. Check prerequisites

```bash
uname -s                                   # Linux, or MINGW*/MSYS* on Git Bash
for c in bash git jq; do command -v "$c" >/dev/null || echo "MISSING: $c"; done
command -v agy >/dev/null || echo "MISSING: agy (official Antigravity CLI)"
```

Linux also needs `timeout` (coreutils) and `setsid` (util-linux). Windows (Git Bash) needs `jq` (`winget install jqlang.jq`) and PowerShell for the Credential Manager backend. Tested on Linux with agy 1.4.7.

If `agy` is missing, tell the user to install it. Do not install it yourself unless asked.

If the repo is not on the machine, clone it: `git clone https://github.com/luongtrz/agyr.git ~/tools/agy-acct`, or use another path the user confirms. Set `REPO` to the clone path for the steps below.

## 2. Link the commands

Linux:

```bash
bash "$REPO/linux/install.sh"        # symlinks in ~/.local/bin (or pass another directory as the argument)
```

Windows (Git Bash, no working symlinks):

```bash
bash "$REPO/windows/install.sh"      # small wrappers in ~/.local/bin that run this clone
```

Both scripts refuse to overwrite a regular file they did not write, and both stop with a message when `jq` or `git` is missing. If `~/.local/bin` is not on `PATH`, tell the user.

## 3. Skill and global instructions (only if this machine runs Claude Code)

- Skill: if `~/.claude/skills/agy` does not exist, copy it with `cp -r "$REPO/skill/agy" ~/.claude/skills/`. If it exists, run `diff -r` and show the user. Replace it only after a yes.
- Global instructions: `~/.claude/CLAUDE.md` belongs to the user. Do not create, change or copy it.

## 4. Verify (no login needed)

```bash
agyr help >/dev/null && echo "agyr ok"
agyr backend                              # "file" on Linux, "wincred" on Windows
LOG=$(mktemp)
bash "$REPO/test/run.sh" > "$LOG" 2>&1; grep '^result:' "$LOG"
```

On Linux, expect `result: 794 pass, 0 fail`. The suite takes several minutes. It uses a fake agy and fake tokens and never touches a real login. On Windows two checks are skipped on purpose. If the result differs, report it with the failing lines.

Do not run `agyr list` yet. It needs the logins that the user has not saved.

## 5. Hand over to the user

Tell the user these steps are theirs:

1. For each Google account: run `agyr` (it opens agy), log in, and quit. Then run `agyr save <name>`. Names may contain only letters, digits, `-` and `_`.
2. Before the next account, run `agyr forget` so agy asks for a fresh login. Do not use agy's own logout.
3. After all accounts are saved, `agyr list` should show different quota numbers for each slot. A slot that shows `measure failed` needs a new login and a new `save`.
4. Choose the daily account with `agyr use <name>`.

On Windows, `save` and `forget` work on the Credential Manager entry, so the user should run them in an interactive terminal.

## Known limits

See the "Giới hạn đã biết" section of `README.md` (in Vietnamese). In short: account switching has been tested only with a fake agy until the user verifies it with real accounts, and parallel `agy-run` runs share one token file.
