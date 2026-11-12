---
name: agy-codex
description: Delegate a well-scoped coding or read-only investigation task from Codex to the local `agy` CLI. Implement tasks go through `agy-task run` (worktree, setup, scope check, compact summary; it runs no tests); read-only exploration through `agy-run`. Use only for self-contained tasks with a mechanical way to verify the result; never for architecture decisions or ambiguous requirements. agy runs with --dangerously-skip-permissions, so implement tasks run only in a dedicated git worktree and every prompt carries the HARD RULES block (`agy-task` adds it). The Claude Code skill is maintained separately as `agy`.
---

# Delegate work to agy from Codex

`agy` is a separate coding-agent CLI (`~/.local/bin/agy`). Launch it only through `agy-task` (implement) or `agy-run` (read-only). Paths like `references/…` are relative to this skill's base directory; **read a reference file only when its situation comes up** — they are kept out of this file on purpose to save context.

## Invariants

1. **Model:** default `gemini-3.8-flash-high`. Always pass `--model` explicitly on every agy call, never omit it. No other backend or model family (`agy models` in agy 1.5.1 also lists `gemini-4-argon-{low,medium,high}`, `claude-opus-5-5-*`, `claude-sonnet-5-5-*`, `gpt-oss-120b-medium` — never use any of them, not even for cross-checks, unless the user explicitly asks). Only exception: sustained 503 → `gemini-3.8-flash-medium`, then `gemini-3.8-flash-low` only if medium also fails (`--model` flag), see `references/503-fallback.md`.
   - **`gemini-3.8-flash-high` (default):** every task unless the small-task test below passes. Use it for judgment-heavy work: a change that crosses layers (repo, service, API, DB query semantics), a change to a function's contract or default values, a choice between designs with trade-offs, or a task where a low run went wrong and one correction round did not fix it.
   - **`gemini-3.8-flash-low` (small tasks only):** use it only when all of these hold: the change stays in one layer (one package or one app), at most 2 files change (a test file counts), the fix mirrors an existing pattern in that package, the acceptance criteria are observable behavior, and no contract or default value changes. In our two-task comparison low was about 3x faster and cheaper with the same core logic on such tasks. It still left a formatting nit and a shallow test, so review its output as strictly as high's.
   - **`gemini-3.8-flash-medium`:** not chosen for normal work. It is only the 503 fallback.
2. **Never a bare `agy -p`.** agy >= 1.2.14 reads its login from the OS keyring and ignores the token file that `agyr` swaps; `agy-run` neutralizes that and rotates accounts on 429. The user starts their own interactive agy with plain `agyr`, not `agy`.
3. **Never trust agy's exit code or report.** `agy-task` only checks scope and runs no tests (verify step removed 2026-10-08); you read the diff and run the tests yourself. agy has reported green while tsc was broken, a resumed run can echo an old 429, and a content-filter block (agy >= 1.4.5/1.5.0) finishes with `RESULT=OK`, exit 0, and `changed files: (none)` ("This request was blocked by Gemini's filters…"). Always check that the worktree diff is non-empty.
4. **Implement tasks only via `agy-task`** (it creates the worktree; never ask agy to `git worktree add`). Explore / bug-finding tasks target the main repo read-only via `agy-run --add-dir "$REPO"` (always pass `--add-dir`: without it agy silently writes into `~/.gemini/antigravity-cli/scratch/` and still reports success).
5. **One small task per session**, exact files/lines in the task file (quota burns with context size; `references/logs-and-costs.md`). At most **20 runs in parallel** (user rule 2026-10-12, raised from 12; `references/parallel.md`). Check `pgrep -fc '^bash .*agy-(task run --name|run --prompt)'` before launching more. **Launch each `agy-task` or `agy-run` as its own separate background tool call** — never bundle multiple tasks into one shell loop, wrapper script (`launch.sh`), or `for pid in ...; wait` command (bundling hides per-task status from the user and blocks completion notifications until the slowest task finishes).
6. **Task files and logs live in `<repo>/.agy-sessions/`** (gitignored), never `/tmp` or agy's scratch dir. Keep the logs, delete prompt files when done. Never read the `.jsonl` unless debugging: the summary is the report.
7. **Report reset times to the user in UTC+7.** Never read the contents of the oauth token file (only `stat -c %Y`).
8. **agy never runs tests** (user rule 2026-10-08: test runs lag the machine). No prompt may ask agy to run tests, builds, type-checks or linters, not even "one test file": the HARD RULES blocks and the `agy-task` prompt tail forbid it, so the task file must not contradict that (write acceptance criteria as observable code behavior, never "make `pnpm test` pass"). `agy-task` has no verify step either: Codex runs checks after agy has answered and the diff is read, one targeted command at a time (never several suites in parallel).

`--dangerously-skip-permissions` (passed by `agy-run`) is the user's choice (2026-09-25); safety comes from the worktree isolation, the HARD RULES block and the scope check. If Codex's policy blocks that flag, tell the user instead of working around it.

## When to use / not

- **Use** when the task is small and self-contained enough for one prompt with no back-and-forth, and either mechanically verifiable (build/lint/test, diff mirrors an existing pattern) or a read-only investigation whose findings you can sanity-check; or when you want a real separate-process perspective.
- **Don't** for architecture/design decisions, security-sensitive code or nuanced judgment calls; anything you can't fully specify in one prompt (agy has zero context from this conversation); big multi-bug batches (split them); or when writing the task file takes the same research as doing it (then just do it). If you already found the exact line(s), edit directly.

## Workflow: implement task (`agy-task`)

1. **Plan, don't over-specify** (user rule 2026-09-25): goal, root cause / suspected area, relevant files, the pattern to mirror, acceptance criteria. Don't pre-trace every line or paste full code — Codex traces the code during review.
2. **Write ONLY the task part** to `<repo>/.agy-sessions/<task>.task.txt`: Repo/stack, Task, Plan, Acceptance criteria, an ENVIRONMENT NOTE ("the env is prepared; on an env failure STOP: no pnpm install, no symlinks, no copying from outside"). Do not write the working directory, scope, HARD RULES or verify list: the script adds them. Never tell agy to run or "make pass" any test/build/lint (invariant 8).
3. **Run in the background** (`run_in_background: true` / `WaitMsBeforeAsync: 500`, **one separate tool call per task** — never a batch script or `wait` loop) and wait for each completion notification — don't poll:
   ```bash
   agy-task run --name <task> --task <repo>/.agy-sessions/<task>.task.txt \
     --scope '<pathspec>' [--scope …] [--base <ref>] --model <gemini-3.8-flash-high|gemini-3.8-flash-low>
   ```
   `--model` takes the FULL model id from invariant 1 (`gemini-3.8-flash-high`, `-medium`, `-low`). The short words `high` / `low` are not model names: agy rejects them at once with `error: invalid model selection (--model "high" …)`, `turns=0`, exit 1, the worktree stays clean, and the message is not a quota or login problem. Check the spelling of `--model` first when a run fails this way.
   `--base`: commit-ish the worktree branches from (default: `HEAD` of the current worktree). **When running from a linked worktree (e.g. an MR/feature worktree) whose branch differs from the main checkout, ALWAYS pass `--base <branch|sha>` explicitly** (e.g. `--base HEAD` or `--base $(git rev-parse --short HEAD)`). `agy-task` resolves git paths back to the repository's main checkout, so explicitly pinning `--base` ensures all parallel tasks branch from the exact target commit and prevents any risk of drifting to the main checkout's branch.
   Always give `--scope` (paths agy may change; a moved HEAD, i.e. an agy commit, is a violation too). Setup and file copies come from `<repo>/.agy-sessions/agy-task.conf` (any leftover `VERIFY`/`DEFAULT_VERIFY` there is ignored; `--verify*` flags no longer exist and fail with exit 2). `agy-task` runs NO tests: you run them afterwards (step 5); when Go tests hit a shared dev DB, use a targeted `cd backend && go test ./internal/foo/...`. stdout = a compact summary, also saved as `.agy-sessions/<task>.summary.txt`; progress goes to stderr. The user can watch with the live command in `references/logs-and-costs.md`.
4. **Read the exit code and the summary:**

   | exit | Meaning | Do |
   |---|---|---|
   | 0 | agy finished and scope is ok (`RESULT=OK`); NOTHING was tested | check `changed files` is non-empty (if `(none)` with a "blocked by Gemini's filters" report, reword neutrally without exploit/race phrasing and rerun with `--reuse-worktree --no-setup`). Note: if an earlier turn hit 429 and rotated accounts, the summary may show `agy: status=ERROR … - agy reported ERROR - check the diff before trusting it` while `RESULT=OK` because `agy` echoes the old quota error in `result` JSON; review (step 5) and run the tests yourself |
   | 8 | `RESULT=SCOPE_VIOLATION` | read the violation lines; send agy a corrected follow-up (see "Correction round" below), don't hand-fix |
   | 7 | setup failed (worktree kept) | fix the environment, rerun with `--reuse-worktree` (setup reruns) |
   | 2 | bad arguments, config, or worktree/branch conflict | fix the command |
   | 4 | login error / no active account | **STOP**, tell the user; `references/quota-auth.md` |
   | 5 | whole pool on cooldown | **STOP**, tell the user the earliest reset (UTC+7); `references/quota-auth.md` |
   | 1, 6 | other agy failure / too many account switches | first check `changed files:` and `agy report:` in the summary — if the edits and report are already complete (e.g. a stream timeout or interrupt echo at the very end), check scope/diff and run tests instead of redoing the task. Otherwise check the log for `invalid model selection` (wrong `--model` value, see step 3); a 503 → `references/503-fallback.md`; other quota/auth errors → `references/quota-auth.md` |

   **A 429 on one account is NOT a stop, and the user does not switch accounts for it.** `agy-run` (and `agy-task`, which calls it) kills agy at once, puts that account on cooldown from its `Resets in`, switches to the next ready account and resumes the same conversation by itself. So do not tell the user "out of quota, switch accounts" for a 429 and do not wait for them. Stop only on exit 4 (login) or exit 5 (every account on cooldown: tell the user the earliest reset in UTC+7). Never retry in a loop or fall back to doing the task yourself on 4/5.

   **Correction round** (review or your tests found a problem in what agy wrote): continue the SAME agy conversation, since agy wrote that code and its tests and remembers why. Write a short new task file (what is wrong, file/line, what it should do; the code already in the worktree is agy's earlier work, fix it, don't redo it) and run `agy-task run --name <task> --resume --task <new-task-file> --scope '<pathspec>' --model <gemini-3.8-flash-high|gemini-3.8-flash-low>`. `--resume` takes the conversation id from the last `init` event of `.agy-sessions/<task>.jsonl` and implies `--reuse-worktree --no-setup`; it exits 2 if there is no log or id. Use `--reuse-worktree --no-setup` WITHOUT `--resume` (fresh conversation) only when the old conversation went the wrong way or has grown huge (quota burns with context size). Same rules as any run: agy runs no tests, you review the diff and test again afterwards.

   **Round limit:** at most 2 `--resume` rounds per task. Before declaring a run stuck, check `grep -c '^{' .agy-sessions/<task>.jsonl` and `tail -1` (stderr / `.err` only logs account switches and looks idle while `step_update` events are still growing). If the task still is not right after 2 rounds, or event count has stopped growing / produced no new file for ~10 min, stop it: `kill -KILL` the agy-task, agy-run and `agy --conversation` pids (SIGTERM does not stop the child; exit 137 is then expected). Commit the reviewed good part on `agy/<task>` (the worktree branch, not the target branch) so nothing is lost, then start a fresh conversation on the same worktree with a narrow task file: `agy-task run --name <task> --reuse-worktree --no-setup --task <narrow-task-file> --scope '<pathspec>' --model <gemini-3.8-flash-high|gemini-3.8-flash-low>`. Put the exact facts agy kept searching for into that task file.
5. **Review** (tiered): mechanical change → summary + skim the diff + one targeted check; risky (auth, payment, migrations, concurrency) → read the full `git -C <repo>/.worktrees/agy-<task> diff` and run the key checks yourself. Nothing has been tested before this point (neither agy nor `agy-task` runs tests), so this is the only test run: targeted, run in the worktree, one command at a time. agy reads code accurately but misjudges cross-file consequences and over-rates severity. Mutation-checking agy's tests: never undo the mutation with `git checkout -- <file>` while agy's changes are uncommitted (it wipes them; happened 2026-09-29): copy the file to the scratchpad or commit first. Run `gofmt -l` on Go files agy touched.
6. **Integrate and clean up:** stage only in-scope files explicitly (never `git add -A`), commit on the worktree branch `agy/<task>` (only when the user asks), cherry-pick/ff to the target branch, then `agy-task rm <task> -f` (without `-f` it refuses after a cherry-pick: the commits are not reachable from HEAD). It keeps the logs/summary and appends nothing else; `.agy-sessions/usage.tsv` accumulates tokens and seconds per task.

If `agy-task` is unavailable or too rigid: `references/manual-worktree.md`.

## Workflow: explore / bug-finding task (read-only, `agy-run`)

Write the task part to `.agy-sessions/<task>.task.txt` (say which checks Codex already ran and point at exact files), append the read-only HARD RULES, run, then confirm the repo is untouched:
```bash
{ cat "$REPO/.agy-sessions/<task>.task.txt"; echo; \
  sed "s#<ABS_PATH>#$REPO#g" "${AGY_SKILL_DIR:-$HOME/.agents/skills/agy-codex}/references/hard-rules-explore.txt"; } > "$REPO/.agy-sessions/<task>.txt"
agy-run --prompt "$REPO/.agy-sessions/<task>.txt" --add-dir "$REPO" --log "$REPO/.agy-sessions/<task>.jsonl" --model gemini-3.8-flash-high   # background
grep '^{' "$REPO/.agy-sessions/<task>.jsonl" | jq -c 'select(.event=="result") | .result | {status,finished_reason,error,num_turns,usage}'
git -C "$REPO" status --short                                        # must still be clean
```
`agy-run` exit codes are the same as above (0 ok, 1, 2, 4, 5, 6). Check findings against the code before reporting them; delete the prompt files afterwards.

## References (read on demand)

- `references/quota-auth.md` — exit 4/5/6, 429, login, account pool (`agyr`), keyring trap, stale-429, auto-continue after a re-login
- `references/503-fallback.md` — `gemini-3.8-flash-medium`, then `gemini-3.8-flash-low`, fallback rules
- `references/parallel.md` — running several tasks at once, integration, queueing many tasks
- `references/logs-and-costs.md` — stream-json events, jq commands, the `--add-dir` trap, why quota burns, smoke test
- `references/manual-worktree.md` — the manual implement workflow `agy-task` automates
- `references/hard-rules-explore.txt` — HARD RULES block for read-only tasks (`<ABS_PATH>` placeholder); the implement block is `~/tools/agy-acct/templates/hard-rules.txt`
