# agent.mcp.md: install and check agyr

Read this file when a user asks you to install agyr on a machine. You are an AI agent with shell access. This file is not an MCP server.

## 0. What you are installing

agyr switches between several Google accounts for the official `agy` CLI (Antigravity). When one account runs out of quota, `agy-run` moves the same task to the next ready account and resumes the same conversation. It also shows the real quota of each account.

- Repository: https://github.com/luongtrz/agyr (public, MIT).
- Commands it installs: `agyr`, `agy-run`, `agy-task`.
- Google login is interactive (browser). Only the user can log in. Your job is to install, verify, and hand the logins back to the user.

Using several accounts this way may conflict with Google's terms of service. Say so once to the user when you install it.

## 1. Hard rules

1. Never read, print, `cat`, `grep`, open or copy these: `~/.gemini/antigravity-cli/antigravity-oauth-token`, any file under `~/.gemini/antigravity-cli/accounts/`, and the Windows Credential Manager entry `gemini:antigravity`. Allowed: `test -f`, `stat -c %Y` (modification time), and listing file names.
2. Do not log in to Google. Do not run `agyr save`, `forget`, `rename`, `use`, `rotate`, `cooldown`, `clear` or `test` unless the user asks for that action in this conversation. `agyr test` sends real requests and spends quota.
3. Never start agy for this pool with a bare `agy`. Use `agyr` (plain, `agyr -c`, or `agyr run ...`), `agy-run` or `agy-task`. On Linux they hide the GNOME keyring, which is what makes account switching work.
4. Do not overwrite, move or delete any file outside the clone and the three commands you install. That includes `~/.claude/CLAUDE.md`, an existing `~/.claude/skills/agy`, and any existing file in the bin directory. Show the diff and ask first.
5. Do not commit, push, change git remotes, or edit the user's shell profile.
6. Do not uninstall, and do not delete `~/.gemini/antigravity-cli/accounts/`, unless the user asks in this conversation.
7. If a step opens a browser or asks for a password, stop and hand it to the user.

## 2. Check the machine

Run these and report the results to the user:

```bash
uname -s                                              # Linux, or MINGW*/MSYS*/CYGWIN* for Git Bash on Windows
for c in bash git jq; do command -v "$c" >/dev/null && echo "ok: $c" || echo "MISSING: $c"; done
command -v agy >/dev/null && agy --version 2>/dev/null | head -1 || echo "MISSING: agy"
ls -l ~/.local/bin 2>/dev/null | grep -E ' (agyr|agy-run|agy-task)$' || echo "no agyr commands in ~/.local/bin yet"
```

Requirements:

- **All platforms:** bash, git, jq.
- **Linux:** `timeout` and `setsid` are used when present (coreutils and util-linux). Not required.
- **Windows (Git Bash):** jq (`winget install jqlang.jq`), PowerShell (`powershell.exe` on PATH), and `cygpath` and `taskkill` (both come with Git for Windows).
- **agy:** the official Antigravity CLI, installed by the user. Tested with agy 1.4.7 on Linux. Do not install agy yourself unless the user asks.

If a required tool is missing, stop. Tell the user the install command for that system. Do not install packages without asking.

## 3. Get the code

Default location: `~/tools/agy-acct`. Use another path only if the user names one.

```bash
export REPO="$HOME/tools/agy-acct"
if [ -d "$REPO/.git" ]; then
  git -C "$REPO" status --short            # must print nothing; if it lists files, stop and ask the user
  git -C "$REPO" pull --ff-only
else
  git clone https://github.com/luongtrz/agyr.git "$REPO"
fi
git -C "$REPO" log --oneline -1
```

The repository has these folders: `bin/` (the three commands), `linux/` and `windows/` (platform code and install scripts), `skill/agy/` (Claude Code skill), `templates/`, `test/`, `docs/`.

## 4. Install the commands

The install scripts create the three commands in `~/.local/bin`, or in a directory given as the first argument.

Linux:

```bash
bash "$REPO/linux/install.sh"
```

This creates symbolic links from `~/.local/bin/<name>` to `$REPO/bin/<name>`.

Windows (Git Bash):

```bash
bash "$REPO/windows/install.sh"
```

Git Bash cannot make working symlinks here, so this writes one-line wrappers that run `$REPO/bin/<name>`. The clone path is written into the wrappers. If the clone is moved, run the script again.

Both scripts:

- stop with exit 1 when `jq` or `git` is missing;
- refuse to replace a regular file (Linux), or a file that is not a wrapper for this clone (Windows), and print why. If that happens, show the file to the user and ask. Do not delete it;
- print a note when the bin directory is not on `PATH`.

If `~/.local/bin` is not on `PATH`, tell the user to add `export PATH="$HOME/.local/bin:$PATH"` to their shell profile. Do not edit the profile yourself.

## 5. Verify without logging in

```bash
export PATH="$HOME/.local/bin:$PATH"
agyr help | head -1           # agyr — rotate between multiple agy (Antigravity CLI) accounts
agy-run --help | head -1      # agy-run — run one agy task headless, rotating accounts when one runs out of quota
agy-task --help | head -1     # agy-task — deterministic wrapper running one delegated implement task end to end
agyr backend                  # file on Linux, wincred on Windows
```

Then run the test suite. It uses a fake agy and fake credentials and never touches a real login. It takes several minutes, so run it with a long timeout or in the background:

```bash
LOG=$(mktemp)
bash "$REPO/test/run.sh" > "$LOG" 2>&1; echo "exit=$?"
grep '^result:' "$LOG"
```

Expected: `exit=0` and `result: 794 pass, 0 fail`. The number may change between versions. `0 fail` is the requirement. On Windows, two checks are skipped on purpose. If anything fails, report the lines that start with `FAIL` and stop.

Do not run `agyr list` yet. It needs logins that the user has not saved.

## 6. Hand the logins to the user

These steps need the user's Google account and a browser. Explain them, then wait for the user to confirm each account.

1. For each Google account, in a normal terminal: run `agyr`. It starts agy with the selected slot. Finish the Google login, then quit agy.
2. Save that login under a name: `agyr save <name>`. A name may contain only letters, digits, `-` and `_` (for example `work` or `personal`).
3. Before the next account, run `agyr forget`. It removes the login on this machine only. It does not sign out at Google. Do not use agy's own logout.
4. Repeat for each account.
5. Check: `agyr list` must show a different quota line for each saved account. A slot that shows `measure failed` has a revoked or broken login: the user logs in again and runs `agyr save <name>` for it.
6. Choose the account to use: `agyr use <name>`.

On Windows, `save` and `forget` work on the Credential Manager entry `gemini:antigravity`. The user must run them in an interactive Git Bash window.

After the user confirms the saves, you may run `agyr list -c`. It prints the saved numbers without starting agy. Do not run `agyr list` without asking, because it starts agy once per account (about 10–20 seconds in total).

## 7. Optional: the Claude Code skill

Install this only if the user runs Claude Code on this machine and wants the `agy` skill. The skill tells Claude how to hand work to agy through `agy-task` and `agy-run`.

```bash
SKILL="$HOME/.claude/skills/agy"
if [ -e "$SKILL" ]; then
  diff -r "$REPO/skill/agy" "$SKILL" && echo "skill already identical"
else
  mkdir -p "$HOME/.claude/skills" && cp -r "$REPO/skill/agy" "$SKILL" && echo "skill installed"
fi
```

If a different skill is already there, show the diff and ask. Do not touch `~/.claude/CLAUDE.md`: it belongs to the user.

## 8. What the commands do

- `agyr` (also `agyr -c`, `agyr -p "..."`): start agy with the selected account. On Linux a plain `agy` ignores the selected account, so always start agy through `agyr`.
- `agyr list`: measure every saved account (0 tokens). `agyr list -c`: show the saved numbers only.
- `agyr use <name>`: select an account. `agyr active`: print the selected one.
- `agyr next`: print the ready account whose weekly limit resets soonest. Exit 3 when every account is on cooldown.
- `agyr rotate`: for the user's own interactive agy that ran out of quota. It cools the current account down and switches.
- `agy-run --prompt FILE --add-dir DIR --log FILE.jsonl`: run one headless agy task. On "Individual quota reached" it switches accounts and resumes the same conversation. Exit codes: 0 done, 1 other failure, 2 bad arguments, 4 login error, 5 every account out of quota, 6 too many switches.
- `agy-task run --name NAME --task FILE --scope PATH`: run one implement task in its own git worktree. Read `agy-task --help` before using it.

On exit 4 (login), stop and tell the user to log in again. On exit 5, stop and report the earliest reset time from `agyr list -c` (give it in the user's time zone, UTC+7 by default).

## 9. Troubleshooting

| Symptom | Cause | What to do |
|---|---|---|
| `agyr: command not found` | `~/.local/bin` is not on `PATH` | Tell the user to add it (section 4). |
| `jq is required` | jq is missing | Install jq (Linux: package manager; Windows: `winget install jqlang.jq`). |
| Every account shows the same quota numbers | agy reads the login from the keyring (agy 1.2.14 or later) | Start agy with `agyr`, not `agy`. |
| `measure failed` for one slot | the login was revoked or has expired | The user logs in again and runs `agyr save <name>`. |
| `agyr list` warns that the login matches no slot | the user logged in but did not save | The user runs `agyr save <name>`. |
| `another agyr is switching accounts` | another agyr holds the lock | Wait a moment and retry. Do not delete the lock directory. |
| An install script refuses to replace a file | an unrelated file has the command name | Show the file to the user and ask. |
| `agyr backend` prints `file` on Windows | `AGYR_BACKEND=file` is set | Unset it. The Windows default is `wincred`. |

## 10. Environment variables

| Variable | Default | Purpose |
|---|---|---|
| `AGY_HOME` | `~/.gemini/antigravity-cli` | agy data directory |
| `AGY_BIN` | `agy` | agy binary |
| `AGY_TZ` | `UTC-7` (UTC+7) | time zone for displayed times |
| `AGYR_BACKEND` | by OS (`file` on Linux, `wincred` on Windows) | where the login lives |
| `AGY_CRED_TARGET` | `gemini:antigravity` | Credential Manager entry (Windows) |
| `AGYR_COLOR` | `auto` | `auto`, `always` or `never` |
| `AGY_RUN_MAX_SWITCH` | `10` | maximum account switches per `agy-run` |
| `AGY_RUN_POLL` | `1` | seconds between two looks at the log |

## 11. Update and uninstall

- Update (only when the clone has no local changes): `git -C "$REPO" pull --ff-only`. On Linux the symlinks need no change. On Windows, run `bash "$REPO/windows/install.sh"` again. Then repeat section 5.
- Uninstall (only when the user asks): remove the three links or wrappers in the bin directory. Remove the clone only if the user asks. Never delete `~/.gemini/antigravity-cli/accounts/`, which holds the user's saved logins, unless the user asks for that by name.

## 12. Known limits to tell the user

- Account switching has been tested with a fake agy only. It is confirmed when the user has real accounts and `agyr list` shows different numbers for each slot.
- Parallel `agy-run` processes share one token file. A switch by one process can change what another sees, so a cooldown may land on the wrong account. `agyr list` shows the current state.
- `agyr save` does not check whether the same login is already saved under another name.
- The Windows backend (`wincred`) is tested only with a fake Credential Manager helper.
- Google can revoke a refresh token (for example after a password change). The slot then shows `measure failed`.

## 13. Report back

When you finish, report to the user:

- the commit of the clone (`git -C "$REPO" log --oneline -1`);
- where the commands are installed and whether that directory is on `PATH`;
- the test result line (`result: ... pass, ... fail`);
- whether the skill was installed;
- the login steps still waiting for the user (section 6).
