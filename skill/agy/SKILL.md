---
name: agy
description: Delegate a well-scoped coding or read-only investigation task to the local `agy` CLI (a separate agent) to save tokens. Implement tasks go through `agy-task run` (worktree, setup, scope check, compact summary; it runs no tests); read-only exploration through `agy-run`. Use only for self-contained tasks with a mechanical way to verify the result; never for architecture decisions or ambiguous requirements. agy runs with --dangerously-skip-permissions, so implement tasks run only in a dedicated git worktree and every prompt carries the HARD RULES block (agy-task adds it).
---

# Delegate work to agy

`agy` is a separate coding-agent CLI (`~/.local/bin/agy` on Linux, `agy.exe` on Windows). Launch it only through `agy-task` (implement) or `agy-run` (read-only). Paths like `references/…` are relative to this skill's base directory; **read a reference file only when its situation comes up** — they are kept out of this file on purpose to save context.

## Invariants

1. **Model:** `gemini-3.8-flash-high`, explicit (the default of `agy-run`/`agy-task`). No other backend, not even for cross-checks, and never omit `--model` on a raw agy call. Only exception: sustained 503 → `gemini-3.8-flash-medium`, then `gemini-3.8-flash-low` only if medium also fails (`--model` flag), see `references/503-fallback.md`.
2. **Never a bare `agy -p`.** agy >= 1.2.14 reads its login from the OS keyring (Linux) or Windows Credential Manager (Windows, see the Windows section) and ignores the token file that `agyr` swaps; `agy-run` neutralizes that and rotates accounts on 429. The user starts their own interactive agy with plain `agyr`, not `agy`.
3. **Never trust agy's exit code or report.** `agy-task` only checks scope and runs no tests (verify step removed 2026-10-08); you read the diff and run the tests yourself. agy has reported green while tsc was broken, and a resumed run can echo an old 429.
4. **Implement tasks only via `agy-task`** (it creates the worktree; never ask agy to `git worktree add`). Explore / bug-finding tasks target the main repo read-only via `agy-run --add-dir "$REPO"` (always pass `--add-dir`: without it agy silently writes into `~/.gemini/antigravity-cli/scratch/` and still reports success).
5. **One small task per session**, exact files/lines in the task file (quota burns with context size; `references/logs-and-costs.md`). At most **20 runs in parallel** (user rule 2026-10-12, raised from 12; `references/parallel.md`). Check running processes (`pgrep -fc '^bash .*agy-(task run --name|run --prompt)'` or process list) before launching more.
6. **Task files and logs live in `<repo>/.agy-sessions/`** (gitignored), never `/tmp` or agy's scratch dir. Keep the logs, delete prompt files when done. Never read the `.jsonl` unless debugging: the summary is the report.
7. **Report reset times to the user in UTC+7.** Never read the contents of the oauth token file (only `stat -c %Y` or `agyr list`).
8. **agy never runs tests** (user rule 2026-10-08: test runs lag the machine). No prompt may ask agy to run tests, builds, type-checks or linters, not even "one test file": the HARD RULES blocks and the `agy-task` prompt tail forbid it, so the task file must not contradict that (write acceptance criteria as observable code behavior, never "make `pnpm test` pass"). `agy-task` has no verify step either: the assistant is the only one who runs tests, after agy has answered and the diff is read, one targeted command at a time (never several suites in parallel).

`--dangerously-skip-permissions` (passed by `agy-run`) is the user's choice (2026-09-25); safety comes from the worktree isolation, the HARD RULES block and the scope check. If any permission classifier blocks that flag, tell the user instead of working around it.

## When to use / not

- **Use** when the task is small and self-contained enough for one prompt with no back-and-forth, and either mechanically verifiable (build/lint/test, diff mirrors an existing pattern) or a read-only investigation whose findings you can sanity-check; or when you want a real separate-process perspective.
- **Don't** for architecture/design decisions, security-sensitive code or nuanced judgment calls; anything you can't fully specify in one prompt (agy has zero context from this conversation); big multi-bug batches (split them); or when writing the task file takes the same research as doing it (then just do it). If you already found the exact line(s), edit directly.

## Workflow: implement task (`agy-task`)

1. **Plan, don't over-specify** (user rule 2026-09-25): goal, root cause / suspected area, relevant files, the pattern to mirror, acceptance criteria. Don't pre-trace every line or paste full code — the reviewer traces the code afterwards during review.
2. **Write ONLY the task part** to `<repo>/.agy-sessions/<task>.task.txt`: Repo/stack, Task, Plan, Acceptance criteria, an ENVIRONMENT NOTE ("the env is prepared; on an env failure STOP: no pnpm install, no symlinks, no copying from outside"). Do not write the working directory, scope, HARD RULES or verify list: the script adds them. Never tell agy to run or "make pass" any test/build/lint (invariant 8).
3. **Run in the background** (`run_in_background: true` / async wait) and wait for the completion notification — don't poll:
   ```bash
   agy-task run --name <task> --task <repo>/.agy-sessions/<task>.task.txt \
     --scope '<pathspec>' [--scope …] [--base <ref>] [--model <m>]
   ```
   Always give `--scope` (paths agy may change; a moved HEAD, i.e. an agy commit, is a violation too). Setup and file copies come from `<repo>/.agy-sessions/agy-task.conf` (any leftover `VERIFY`/`DEFAULT_VERIFY` there is ignored; `--verify*` flags no longer exist and fail with exit 2). `agy-task` runs NO tests: you run them afterwards (step 5); in a frontend project Go tests hit the shared dev DB, so use a targeted `cd backend && go test ./internal/foo/...`. stdout = a compact summary, also saved as `.agy-sessions/<task>.summary.txt`; progress goes to stderr. The user can watch with the live command in `references/logs-and-costs.md`.
4. **Read the exit code and the summary:**

   | exit | Meaning | Do |
   |---|---|---|
   | 0 | agy finished and scope is ok (`RESULT=OK`); NOTHING was tested | review (step 5), then run the tests yourself |
   | 8 | `RESULT=SCOPE_VIOLATION` | read the violation lines; send agy a corrected follow-up (see "Correction round" below), don't hand-fix |
   | 7 | setup failed (worktree kept) | fix the environment, rerun with `--reuse-worktree` (setup reruns) |
   | 2 | bad arguments, config, or worktree/branch conflict | fix the command |
   | 4 | login error / no active account | **STOP**, tell the user; `references/quota-auth.md` |
   | 5 | whole pool on cooldown | **STOP**, tell the user the earliest reset (UTC+7); `references/quota-auth.md` |
   | 1, 6 | other agy failure / too many account switches | read `references/quota-auth.md`; a 503 → `references/503-fallback.md`; status ERROR with a quota or "stream interrupted" echo → check the worktree before believing it |

   **A 429 on one account is NOT a stop, and the user does not switch accounts for it.** `agy-run` (and `agy-task`, which calls it) kills agy at once, puts that account on cooldown from its `Resets in`, switches to the next ready account and resumes the same conversation by itself. So do not tell the user "hết quota, đổi account" for a 429 and do not wait for them. Stop only on exit 4 (login) or exit 5 (every account on cooldown: tell the user the earliest reset in UTC+7). Never retry in a loop or fall back to doing the task yourself on 4/5.

   **Correction round** (review or your tests found a problem in what agy wrote): continue the SAME agy conversation, since agy wrote that code and its tests and remembers why. Write a short new task file (what is wrong, file/line, what it should do; the code already in the worktree is agy's earlier work, fix it, don't redo it) and run `agy-task run --name <task> --resume --task <new-task-file> --scope '<pathspec>'`. `--resume` takes the conversation id from the last `init` event of `.agy-sessions/<task>.jsonl` and implies `--reuse-worktree --no-setup`; it exits 2 if there is no log or id. Use `--reuse-worktree --no-setup` WITHOUT `--resume` (fresh conversation) only when the old conversation went the wrong way or has grown huge (quota burns with context size). Same rules as any run: agy runs no tests, you review the diff and test again afterwards.
5. **Review** (tiered): mechanical change → summary + skim the diff + one targeted check; risky (auth, payment, migrations, concurrency) → read the full `git -C <repo>/.worktrees/agy-<task> diff` and run the key checks yourself. Nothing has been tested before this point (neither agy nor `agy-task` runs tests), so this is the only test run: targeted, run in the worktree, one command at a time. agy reads code accurately but misjudges cross-file consequences and over-rates severity. Mutation-checking agy's tests: never undo the mutation with `git checkout -- <file>` while agy's changes are uncommitted (it wipes them; happened 2026-09-29): copy the file to the scratchpad or commit first. Run `gofmt -l` on Go files agy touched.
6. **Integrate and clean up:** stage only in-scope files explicitly (never `git add -A`), commit on the worktree branch `agy/<task>` (only when the user asks), cherry-pick/ff to the target branch, then `agy-task rm <task> -f` (without `-f` it refuses after a cherry-pick: the commits are not reachable from HEAD). It keeps the logs/summary and appends nothing else; `.agy-sessions/usage.tsv` accumulates tokens and seconds per task.

If `agy-task` is unavailable or too rigid: `references/manual-worktree.md`.

## Workflow: explore / bug-finding task (read-only, `agy-run`)

1. Write the task part to `.agy-sessions/<task>.task.txt` (mention files to inspect, observable questions, and note that it is read-only).
2. Append the read-only HARD RULES block from `references/hard-rules-explore.txt` (replacing `<ABS_PATH>` with the absolute path of the target repo) to create `.agy-sessions/<task>.txt`. (Use file tools directly, or via shell):
   ```bash
   { cat "$REPO/.agy-sessions/<task>.task.txt"; echo; \
     sed "s#<ABS_PATH>#$REPO#g" references/hard-rules-explore.txt; } > "$REPO/.agy-sessions/<task>.txt"
   ```
3. Run `agy-run` in the background and wait for completion:
   ```bash
   agy-run --prompt "$REPO/.agy-sessions/<task>.txt" --add-dir "$REPO" --log "$REPO/.agy-sessions/<task>.jsonl"
   ```
4. Inspect result and verify the repository remained clean:
   ```bash
   grep '^{' "$REPO/.agy-sessions/<task>.jsonl" | jq -c 'select(.event=="result") | .result | {status,error,num_turns,usage}'
   git -C "$REPO" status --short                                        # must still be clean
   ```
5. Check findings against the code before reporting them; delete the prompt files (`.task.txt` and `.txt`) afterwards, keep the `.jsonl` log.

## Windows (Git Bash)

- The shell commands in this skill run in **Git Bash** (the Bash tool), not PowerShell or cmd: `stat`, `grep`, heredocs and `$(...)` assume Git Bash. Use forward-slash paths (`/c/Users/<you>/...` or `C:/Users/<you>/...`) for `--add-dir` and redirects. If `jq` is not found in a shell that was started before it was installed, open a new shell.
- The Windows agy is `agy.exe` (usually under `%LOCALAPPDATA%\agy\bin`). Claude starts it only through `agy-task` or `agy-run`; the user starts their own interactive agy with `agyr`. The commands are on PATH from `~/.local/bin`.
- The login is one Windows Credential Manager entry (`gemini:antigravity`). `agyr` uses the `wincred` backend (`agyr backend` prints `wincred`): `agyr use` writes the chosen slot into that entry, and `agy-run` switches accounts through it.
- Do not run agy by hand while `agyr list` or `agyr use` is running: they write the same entry.
- Known: `bash test/run.sh` does not pass on Windows yet (see `docs/chi-tiet.md`, section "Tình trạng test trên Windows").

## References (read on demand)

- `references/quota-auth.md` — exit 4/5/6, 429, login, account pool (`agyr`), keyring / wincred trap, stale-429, auto-continue after a re-login
- `references/503-fallback.md` — `gemini-3.8-flash-medium`, then `gemini-3.8-flash-low`, fallback rules
- `references/parallel.md` — running several tasks at once, integration, queueing many tasks
- `references/logs-and-costs.md` — stream-json events, jq commands, the `--add-dir` trap, why quota burns, smoke test
- `references/manual-worktree.md` — the manual implement workflow `agy-task` automates
- `references/hard-rules-explore.txt` — HARD RULES block for read-only tasks (`<ABS_PATH>` placeholder); the implement block template is automatically loaded by `agy-task` from `templates/hard-rules.txt`
