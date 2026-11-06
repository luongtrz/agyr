# agyr: full reference

Overview and quick install: [README](../README.md).

Rotate between multiple Google accounts for `agy` (Antigravity CLI) when an account runs out of quota (429), and view the real quota of each account.

Works exclusively with the official `agy` binary by copying `~/.gemini/antigravity-cli/antigravity-oauth-token` back and forth between saved slots. No proxy, and never reads or prints token contents.

> Disclaimer: Google has previously restricted accounts that used third-party proxies or tools to harvest Antigravity quota. Swapping the local token file behaves the same as manually signing in to another account, but comes with no zero-risk guarantee. Use in moderation.

Provides three commands in `bin/`:

- `agyr`: manage slots, inspect quota, switch accounts. This is the command you run directly.
- `agy-run`: run a headless agy task and automatically switch accounts on quota exhaustion. Primarily called by an AI orchestrator via the `agy` skill; see [agy-run](#agy-run-for-ai-agents).
- `agy-task`: run an end-to-end implement task in a dedicated git worktree, check scope, and clean up; see [agy-task](#agy-task-for-ai-agents).

## Installation

If you are an AI agent asked to install this repository on a machine, read [AGENT.MCP.md](../AGENT.MCP.md) for the step-by-step instructions and hard rules (never log in, never save/modify slots, never read token files).

Requires `bash`, `git`, and `jq`. On Linux, `timeout` (coreutils) and `setsid` (util-linux) are used when available, though not required. Tested on Linux with agy 1.5.1.

```bash
bash linux/install.sh        # creates symlinks for agyr, agy-run, agy-task in ~/.local/bin
```

On Windows, use `bash windows/install.sh` (see the Windows section below). The install scripts only create symlinks or wrappers; they never sign in or read token files. After installation, `agyr help` should work and `bash test/run.sh` should report `795 pass, 0 fail` without needing any login. The `agy` skill and `CLAUDE.md` are separate copies; see [Skill `agy` (copy)](#skill-agy-copy).

### Repository layout

- `bin/`: the three entry-point commands (`agyr`, `agy-run`, `agy-task`), free of platform-specific code.
- `linux/`: `platform.sh` (Linux invocation layer: keyring bypass, `setsid`) and `install.sh`.
- `windows/`: `platform.sh` (Git Bash: path conversion, `taskkill`, argument conversion guard), `cred.sh` and `cred.ps1` (read/write Credential Manager entries), `inspect-cred.ps1` (prints metadata only), and `install.sh`.
- `skill/agy/`, `claude/`, `templates/`, `test/`: copy of the `agy` skill, copy of `CLAUDE.md`, `HARD RULES` templates, and test suite.

## Windows (Git Bash)

Run inside **Git Bash** with `jq` installed (e.g. `winget install jqlang.jq`). Install with:

```bash
bash windows/install.sh
```

Because Git Bash cannot create usable symlinks by default, the script writes three small wrapper scripts that invoke `bin/<name>` in the clone (`git pull` updates them in place). The clone path is embedded in the wrappers; re-run the script if you move the clone.

On Windows, `agy` stores its login in a **single Windows Credential Manager entry** (target `gemini:antigravity`, generic type, containing JSON identical to the Linux token file). There is no token file and no per-process way to redirect it, so `agyr` selects the `wincred` backend (`agyr backend`) and switches accounts by **overwriting that entry**:

- `agyr save <name>`: copies the current Credential Manager entry into slot `accounts/<name>.token` (same format as Linux).
- `agyr use <name>`: backs up the active login to `accounts/.last-token.bak`, then writes the slot over the Credential Manager entry. Afterwards, a bare `agy` and `agyr` behave identically (no D-Bus bypass needed on Windows).
- `agyr list`: **measures sequentially**, not in parallel (for each account: writes the login entry, runs `agy -p /quota`, and saves back the refreshed token). Restores the original active login when done, including on Ctrl+C or error. Do not open `agy` or sign in manually while `agyr list` is running.
- `agyr forget`: removes the active login **locally on this machine only** (nothing is revoked at Google) so `agy` prompts for a new login. Replaces `rm ~/.gemini/antigravity-cli/antigravity-oauth-token` on Linux. Refuses if the current login is not saved in any slot (unless `--force` is passed).
- Every write to Credential Manager acquires `accounts/.swap.lock` so concurrent `agy-run` and `agyr list` processes do not clobber each other. This lock also protects the file backend on Linux (see [Parallel runs and slot safety](#parallel-runs-and-slot-safety) below); it uses an exclusive file creation (`set -o noclobber`) rather than `mkdir`, because uutils coreutils `mkdir` (default on newer Ubuntu releases) is not atomic.

One-time setup on Windows:

```bash
agy                       # sign in to account 1, then quit
agyr save acct1
agyr forget
agy                       # sign in to account 2, then quit
agyr save acct2
agyr forget
agy                       # sign in to account 3...
agyr save acct3
agyr use acct1            # select daily account
agyr list                 # verify all slots are alive
```

Slots are regular files protected by your Windows user profile directory permissions (NTFS has no `chmod 600`). Windows-specific helpers live in `windows/`: `cred.sh` + `cred.ps1` (read/write/delete the Credential Manager entry without ever printing its secret) and `inspect-cred.ps1` (prints entry metadata only, for diagnostics). Override the target name with `AGY_CRED_TARGET`, or force a backend with `AGYR_BACKEND=file|wincred`.

## Important (Linux): agy >= 1.2.14 uses the OS keyring

Starting with version **1.2.14**, `agy` stores its login in the **GNOME keyring** (`libsecret` over D-Bus; item `Password for 'antigravity' on 'gemini'`) and **ignores the token file** whenever the keyring is reachable. As a result, `agyr use` swaps the token file, but a bare `agy` still uses the account stored in the keyring, and quota checks would measure the same account every time.

How `agyr` handles this: every `agy` process launched by `agyr` or `agy-run` runs with a non-existent D-Bus session bus address (`DBUS_SESSION_BUS_ADDRESS=unix:path=/nonexistent`), causing `agy` to fall back to the token file. `agyr list` and `agy-run` do this automatically. When starting `agy` interactively, run **`agyr`** instead of `agy`: plain `agyr` opens `agy`, `agyr -c` continues the most recent conversation, and any `agy` flag works (e.g. `agyr -p "..."`). A first argument that does not start with `-` is interpreted as an `agyr` subcommand (e.g. `agyr list`); to pass a subcommand word to `agy` itself, use `agyr run models`. A bare `agy` still uses the keyring account and ignores `agyr use`.

## One-time setup

Slot names are chosen by you and may contain only ASCII letters, digits, `-`, and `_` (e.g. `acct1`, `work`). No spaces, dots, `@`, or `/`.

For each account, sign in with `agyr` and save the slot. This must be done manually in a browser. **Do not use agy's built-in logout** (which may revoke the token on Google's side); instead run `agyr forget` (deletes the local token file while keeping your saved slots):

```bash
agyr save acct1                 # currently signed-in account
agyr forget                     # remove local login
agyr                            # sign in to account 2, then quit
agyr save acct2
agyr forget
agyr                            # sign in to account 3, then quit
agyr save acct3
```

Verify with `agyr list`: each slot must report its own quota numbers (a broken or revoked slot shows `measure failed`).

`agyr forget` refuses (exit 1, deleting nothing) when the active login has not been saved to a slot yet, preventing accidental loss; run `agyr save <name>` first, or `agyr forget -f` to discard it (a backup remains in `accounts/.last-token.bak` until the next `use` or `forget`). It only removes the local token file and does not sign out from Google.

After any manual sign-in, run `agyr save <name>`. If you forget, `agyr list` warns that the active token matches no slot, and `agyr use` will not overwrite any slot with it.

## Commands

```bash
agyr list                     # measure real quota of all accounts and print table (* = selected account)
agyr list -c                  # print cached numbers without calling agy (fast)
agyr use <name>               # switch account
agyr rotate                   # interactive agy ran out of quota: cool down current account + switch to ready account with soonest weekly reset
agyr cooldown <name> 4h13m    # mark an account on cooldown manually (also accepts "… Resets in 4h13m27s")
agyr clear <name>             # clear an account's cooldown
agyr next [-v]                # ready account whose weekly limit resets soonest (exit 3 if whole pool is on cooldown); -v explains why on stderr
agyr active                   # print active account name
agyr save <name>              # save current token as a slot
agyr rename <old> <new>       # rename a slot (login, cooldown, and quota snapshot move with it); refuses if <new> exists
agyr test [name...]           # send "Hi" to every account to start its 5-hour window (spends real quota; see below)
agyr forget                   # drop current local login to sign in to another account; refuses if unsaved (-f to force)
agyr                          # start agy with the selected account (replaces bare `agy`); agyr -c, agyr -p "..." also work
agyr run [agy args]           # identical to `agyr [agy args]`; use when the first arg is a word, e.g. `agyr run models`
agyr help [command]           # overview, or detailed help for one command (`agyr <command> --help` also works)
```

## When interactive agy runs out of quota

Exit `agy` (a running process keeps its old token in memory), then run:

```bash
agyr rotate        # cool down current account (reads "Resets in …" from agy log) + switch to ready account with soonest weekly reset
agyr -c            # reopen with the new account and continue the last conversation
```

`rotate [duration]` accepts a manual duration (e.g. `rotate 4h13m`) if the log has no quota error within the last hour (defaults to `5h`). If the entire pool is on cooldown, it exits with code `3` without changing the token.

## `agyr list`: inspecting quota

```
  ACCOUNT        GEMINI 5H                   GEMINI WEEK                 STATUS
  acct1            1%  01/10/2026 04:02 PM    67%  07/10/2026 09:24 AM   low
  acct2            1%  01/10/2026 03:03 PM    75%  07/10/2026 11:46 AM   low
* work            46%  01/10/2026 05:53 PM    74%  07/10/2026 02:02 PM   ready
  acct3          100%  01/10/2026 07:14 PM   100%  08/10/2026 02:02 PM   ready
Measured at 01/10/2026 02:58 PM   (* = selected account)
```

`agyr list` runs `agy -p /quota` (0 tokens, no model call) for **every account in parallel** (~10–20 seconds total) and caches the result. Each probe runs in a temporary `HOME` directory with a copy of the slot's token, so **it never touches the live token file** and never disturbs an open `agy` or a running `agy-run`. Each probe is detached from the terminal (`setsid`, `/dev/null` stdin) so parallel `agy` processes do not race on terminal mode settings.

- **Row order:** sorted by weekly reset time, soonest first (so quota about to renew is used first). Unmeasured or failed accounts appear last; ties break by name.
- **`*` marker:** marks the slot whose `refresh_token` matches the live token file, rather than relying on stored state. If you sign in manually to an unsaved account, the table warns that the active login matches no slot and omits `*`.
- **Colors** (terminal only): remaining percentage is **green** above 40%, **yellow** from 11% to 40%, **red** at 10% or below. Status column: `ready` green; `not measured` and `stale` yellow; `low`, `cooldown`, and `measure failed` red. Disable with `NO_COLOR=1` or `AGYR_COLOR=never`; force with `AGYR_COLOR=always`.
- **Automatic cooldown sync:** measuring `0%` sets a cooldown until the reported reset time; measuring `>0%` clears any stale cooldown.
- **Status values:** `ready`; `low` (≤10%); `weekly limit reached, 1h36m left` (when the weekly limit is exhausted, `agy` reports the 5-hour limit as `disabled` with no reset time, shown as `off` in the `GEMINI 5H` column, and sets a cooldown until the weekly reset); `cooldown, 15m left`; `not measured`; `stale, past reset time` (with `-c` only); `measure failed` (expired/revoked token or `agy` error; exits with code `1`).

## `agyr test`: sending "Hi" to each account

```
$ agyr test
Sending "Hi" to 3 account(s): one real request each, so it uses a little quota...
  ACCOUNT        HI                                             GEMINI 5H    RESETS
  acct3          ok in 11s: "Hello! How can I help yo"          16%>16%      05/10/2026 04:49 PM
  work           ok in 9s: "Hello! How can I help yo"           100%>99%     05/10/2026 07:31 PM (was 07:04 PM)
  acct1          skipped (cooldown, 45m left)
Measured at 05/10/2026 02:19 PM   (GEMINI 5H = before>after; RESETS = end of the account's current 5-hour window; "(was ...)" = it moved because of the Hi)
```

Each account has its quota measured (0 tokens), receives one `agy -p Hi` request (`--model gemini-3.8-flash-high`, no tools, empty temp directory), and is measured again. The table shows the response or error, the 5-hour quota before and after, and the reset time (with `(was ...)` if the request shifted the reset window).

- **Spends real quota:** one request per account (~20k baseline context tokens, <1% of the 5-hour limit).
- **Purpose:** trigger the 5-hour countdown window across accounts simultaneously. Note that the hypothesis "the 5-hour window starts on the first request" is unverified in official documentation; check whether `RESETS` prints `(was ...)` on a 100% account to see if the window moved.
- Without arguments, accounts on cooldown are skipped. Named accounts (`agyr test acct1 work`) are always tested.
- Never touches the active login. Timed out after `AGYR_TEST_TIMEOUT` seconds (default 120).
- Exit code: `0` if every tested account answered, `1` otherwise.

## Time zone

All displayed timestamps default to **UTC+7** in `dd/mm/yyyy hh:mm AM|PM` format (e.g. `01/10/2026 07:14 PM`), regardless of the host's locale or time zone. Override with `AGY_TZ` (e.g. `AGY_TZ=UTC`; in POSIX TZ syntax `UTC-7` means UTC+7, which is the default).

## `agy-run` (for AI agents)

`agy-run` runs a headless `agy` task with `--dangerously-skip-permissions --output-format stream-json`. As soon as the log shows `Individual quota reached`, it kills `agy` immediately (without waiting for backoff retries), sets a cooldown from `Resets in …`, switches to the next ready account, and resumes the same conversation via `--conversation <id>`.

To continue an existing conversation from the first attempt, pass `--conversation ID`: the first attempt runs `agy --conversation ID -p ...`, and any subsequent quota rotation continues resuming that same conversation.

**Account selection (`agyr next`):** among ready accounts (not on cooldown), picks the one with the **soonest weekly reset time** from the last `agyr list` snapshot. Unmeasured accounts come last; ties break by name; the currently active account is only kept if no other account is ready.

Exit codes: `0` done, `1` other `agy` failure, `2` bad arguments, `4` login error or no active account, `5` whole pool out of quota, `6` exceeded `AGY_RUN_MAX_SWITCH` (default 10) switches.

### Parallel runs and slot safety

Multiple `agy-run` processes can run in parallel while sharing a single live token file:

- **Single private snapshot per operation:** `use`, `forget`, and `list` take one private snapshot of the active login and make all identity checks and write-backs from that snapshot, preventing a concurrent switch from writing one account's token into another account's slot.
- **Cross-platform lock (`accounts/.swap.lock`):** serializes all login swaps, slot writes, and `state.json` updates across both `file` and `wincred` backends using atomic exclusive file creation (`set -o noclobber`).
- **Atomic file writes:** token files, slots, backups, and `state.json` are written to temporary files in the same directory and renamed into place.
- **Identity-checked measurement write-back:** `agyr list` only writes a refreshed token back to a slot if its `refresh_token` still belongs to that same account.

Remaining limitation: parallel `agy-run` processes still share one live token file, so if process B switches the active token between process A's `agyr use X` and `agy` reading the token file, a later cooldown in process A may be recorded against the wrong account name until the next `agyr list` reconciles the quota table.

## `agy-task` (for AI agents)

`agy-task` is a deterministic wrapper that runs a **single delegated implement task end to end** without any LLM in the wrapper: it creates an isolated git worktree, runs setup commands, invokes `agy-run`, checks scope and forbidden files, and writes a compact summary. It runs no tests itself; the reviewing agent verifies the diff and runs targeted tests afterwards. For read-only exploration, call `agy-run` directly against the main checkout.

### Typical workflow

1. Write the task specification to a file (e.g. `.agy-sessions/x.task.txt`).
2. Run `agy-task run --name x --task .agy-sessions/x.task.txt --scope 'paths' --model gemini-3.8-flash-high` in the background.
3. Read `.agy-sessions/x.summary.txt` and inspect `git diff` in `.worktrees/agy-x`.
4. For a correction round: write a follow-up task file and run `agy-task run --name x --resume --task fix.txt --scope 'paths' --model gemini-3.8-flash-high` (resumes the same conversation from the last `init` event in `.agy-sessions/x.jsonl` and implies `--reuse-worktree --no-setup`).
5. Commit verified changes and integrate into the target branch.
6. Clean up with `agy-task rm x -f`.

### Configuration file

`agy-task` sources `<repo>/.agy-sessions/agy-task.conf` (or `$AGY_TASK_CONF`) as a trusted bash file defining:

- `SETUP_CMDS`: array of bash commands executed in order inside the new worktree before `agy` starts.
- `COPY_FILES`: array of repo-relative file/directory paths copied from the main checkout into the worktree after `SETUP_CMDS`.

See [templates/agy-task.conf.example](../templates/agy-task.conf.example).

### `run` options

| Option | Meaning |
|---|---|
| `--name NAME` | Task name (`[a-z0-9-]+`, required). Creates worktree `<repo>/.worktrees/agy-NAME`, branch `agy/NAME`, and session files `<repo>/.agy-sessions/NAME.*`. |
| `--task FILE` | File containing only the task body of the prompt (required). |
| `--repo DIR` | Main checkout (default: current directory; resolves linked worktrees back to the main checkout). |
| `--base REF` | Commit-ish for the new branch (default: `HEAD`). |
| `--scope PATHSPEC` | Repeatable pathspec of files `agy` is allowed to modify (relative to worktree root). |
| `--allow-path PATH` | Repeatable override allowing `agy` to touch a normally forbidden path. |
| `--no-setup` | Skip `SETUP_CMDS` and `COPY_FILES`. |
| `--reuse-worktree` | Reuse an existing worktree instead of failing. |
| `--resume` | Resume the previous `agy` conversation from `.agy-sessions/NAME.jsonl` (implies `--reuse-worktree --no-setup`). |
| `--model M` | Model ID passed through to `agy-run`. |

### `rm` subcommand

```bash
agy-task rm NAME [-f] [--repo DIR]
```

Removes worktree `<repo>/.worktrees/agy-NAME`, branch `agy/NAME`, and `.agy-sessions/NAME.prompt.txt`, while keeping the audit logs (`NAME.jsonl`, `NAME.summary.txt`, `NAME.setup.log`, `usage.tsv`). Without `-f`, refuses (exit 2) if the worktree has uncommitted/untracked changes or if `agy/NAME` has commits not reachable from the main checkout's `HEAD`.

### Exit codes

- `0`: Success (`run`: `agy-run` succeeded and no scope violation; `rm`: removed).
- `1, 4, 5, 6`: Propagated from `agy-run`.
- `2`: Invalid arguments, config error, resume error, or `rm` refused.
- `7`: `SETUP_CMDS` failed.
- `8`: Scope or forbidden-file violation (`RESULT=SCOPE_VIOLATION`).

### Summary file layout

Written to `.agy-sessions/NAME.summary.txt` and printed to stdout:
- First line: `RESULT=OK`, `RESULT=SCOPE_VIOLATION`, `RESULT=SETUP_FAILED`, or `RESULT=AGY_FAILED`.
- Environment metadata: `worktree`, `branch`, `base`.
- `agy`: status, turns, tokens, elapsed seconds.
- `changed files`: `git diff --stat` and untracked files (`??`).
- `scope`: `scope: OK` or list of violation lines.
- `agy report`: up to 25 lines of `.result.response`.
- `logs`: paths to `.jsonl` and `.setup.log`.

### Scope and forbidden-path checks

- Forbidden by default unless allowed via `--allow-path`: `.env*`, lockfiles (`pnpm-lock.yaml`, `package-lock.json`, `yarn.lock`), and AI instruction files (`CLAUDE*.md`, `AGENTS.md`, `GEMINI*.md`).
- When `--scope` is given, any modified or untracked file outside the pathspecs triggers a violation.
- **HEAD movement:** `agy` is forbidden from committing. If `START_HEAD != NOW_HEAD`, `agy-task` flags `scope: violation: agy moved HEAD (committed)...`.

### Usage log (`usage.tsv`)

Every `agy-task run` that reaches summary output appends a tab-separated row to `<repo>/.agy-sessions/usage.tsv` with columns `timestamp`, `name`, `result`, `agy_status`, `turns`, `tokens`, `agy_seconds`, `exit_code`.

### Known limitations of `agy-task`

- The worktree starts from `--base` and does not inherit uncommitted changes from the main checkout.
- Scope and forbidden-file checks only see files reported by `git status` / `git diff` (gitignored files are invisible to git).

## Environment variables

| Variable | Default | Purpose |
|---|---|---|
| `AGY_HOME` | `~/.gemini/antigravity-cli` | `agy` data directory |
| `AGY_BIN` | `agy` | `agy` binary |
| `AGY_TZ` | `UTC-7` (UTC+7) | Time zone for displayed timestamps |
| `AGY_NOW` | current epoch | Test hook: override current time |
| `AGYR_COLOR` | `auto` | `auto` (colored on TTY when `NO_COLOR` is unset), `always`, or `never` |
| `AGYR_TEST_TIMEOUT` | `120` | Per-account timeout in seconds for `agyr test` |
| `AGY_RUN_MAX_SWITCH` | `10` | Maximum account switches per `agy-run` |
| `AGY_RUN_POLL` | `1` | Poll interval in seconds for `agy-run` |

## Skill `agy` (copy)

`skill/agy/` is a tracked copy of the `agy` skill (`SKILL.md` and `references/`):

```bash
rm -rf skill/agy && cp -r ~/.claude/skills/agy skill/agy                   # sync from local skill into repo
mkdir -p ~/.claude/skills && cp -r skill/agy ~/.claude/skills/              # install for Claude Code
mkdir -p ~/.gemini/config/skills && cp -r skill/agy ~/.gemini/config/skills/ # install for Antigravity / Gemini
```

`claude/CLAUDE.md` is a reference copy of global `CLAUDE.md` instructions for orchestrating `agy`. The `HARD RULES` block for implement tasks is in `templates/hard-rules.txt` (automatically appended by `agy-task`); the read-only exploration block is in `skill/agy/references/hard-rules-explore.txt`.

## Tests

```bash
bash test/run.sh
```

Runs 795 checks using fake tokens and `test/fake-agy` (emulating `init`, `429`, and `/quota` output) without touching real credentials. The `wincred` suite runs on all platforms against `test/fake-cred`. On Windows, two checks (POSIX `600`/`700` file modes and `pgrep`) are intentionally skipped.

## Known limitations

- Running `agy` processes keep their initial token in memory; `agy-run` always kills and resumes the conversation rather than hot-swapping tokens.
- `agy-run` only triggers a quota switch on plain-text `error: Individual quota reached …` or `AGY_ERROR: … RESOURCE_EXHAUSTED (code 429)` lines. When a conversation that previously hit 429 is resumed, `agy` still echoes the old quota error inside the final `{"event":"result"}` JSON (`status: "ERROR"`, `error: "Individual quota reached …"`) even when the resumed turn completed normally; `agy-run` ignores JSON lines so it does not switch accounts falsely, and returns exit `0` when `.result.response` is non-empty (or exit `1` if `response` is empty).
- `503 No capacity` errors are not switched automatically by `agy-run`; follow `skill/agy/references/503-fallback.md` (`gemini-3.8-flash-medium`, then `gemini-3.8-flash-low`).
- Parallel `agy-run` processes share one pool best-effort (see above).
- **Windows:** the `wincred` backend is tested against `test/fake-cred`; because each Credential Manager read/write spawns PowerShell (~1 s), `agyr list` measures accounts sequentially rather than in parallel, and you should not sign in manually while `agyr list` or `agyr use` is running.
