---
name: agy
description: Delegate a well-scoped investigation or mechanical coding task to the local `agy` CLI — a separate multi-model coding agent installed on this machine (Gemini/Claude/GPT-OSS backends, see `agy models`) — instead of doing it directly, to save tokens or to run an independent investigation as a real subprocess. Use only when the task can be written as a self-contained prompt and has a mechanical or independently-checkable way to verify the result. Never for architecture decisions or ambiguous requirements. CRITICAL: agy ignores the invoking shell's cwd by default — always pass `--add-dir <target-path>` or it silently writes into `~/.gemini/antigravity-cli/scratch/` instead of your repo. Runs with `--dangerously-skip-permissions`, so every prompt needs a HARD RULES block and implement tasks run only inside a dedicated git worktree.
---

# Delegate work to agy

`agy` is a separate coding-agent CLI installed at `~/.local/bin/agy` (v1.2.10 on 2026-09-25; auto-updated to v1.2.14 on 2026-10-02, which moved the login into the OS keyring — see the "Keyring trap" below). It's multi-model under the hood (`agy models` lists other backends — Claude/GPT-OSS/other Gemini variants) but **this skill uses `gemini-3.8-flash-high` by default, always pass `--model` explicitly.** User confirmed 2026-09-22: this model, not "default to it" — do not substitute another backend even for cross-checking, and do not omit `--model` and let it fall back to whatever agy's own default is. **The single allowed exception is the 503 fallback below.**

### 503 "No capacity" → fall back to `gemini-3.7-flash-high` (user rule, 2026-09-29)

If 3.8 keeps failing with `UNAVAILABLE (code 503): No capacity available for model gemini-3.8-flash-high on the server` — i.e. a session's result is that error, or a running session shows repeated 503 / `retrying in …` in `~/.gemini/antigravity-cli/log/cli-*.log` with no successful `streamGenerateContent` for ~5+ minutes (or the same after one fresh relaunch) — switch to **`--model gemini-3.7-flash-high`** (exact name from `agy models`) instead of waiting it out. Tell the user you switched and why.
- 503 is server capacity, not quota/auth: re-login, account switch or relaunching on 3.8 does not help (seen 2026-09-29: ~30 min of stalls, three relaunches, zero edits).
- Before relaunching on 3.7: `kill` the stuck `agy -p` pids, check the worktree is still clean (or note partial edits in the new prompt), archive the old `.jsonl`, reuse the same prompt file unchanged, and relaunch through `agy-run … --model gemini-3.7-flash-high` (never a bare `agy`, see the keyring trap).
- 3.7 quality observed 2026-09-29 (three small fixes): on par with 3.8 — stayed in scope, minimal diffs, added matching tests, verify passed; each session ~3–5 min with no 503s. Review its output exactly as strictly as 3.8's.
- Go back to 3.8 for the next new task; 3.7 is the outage fallback, not the new default. No other models, ever.
- One-off errors that already resolved (a single 503 then success) are not a reason to switch — just retry once after ~60 s.

There is **no web UI / attach flow for agy** (confirmed: `agy --help` has no `web`/`serve` subcommand, unlike `opencode`). For real-time visibility into a running task, use `--output-format stream-json` (not `text`) and `tail -f` the log — see "Real-time log streaming" below.

## Auth & quota — rotate on 429, stop on auth failure or exhausted pool

agy uses interactive Google OAuth (consumer account). The user has **several accounts** (`acct1@…`, `acct2@…`, `acct3@…`) and rotates between them when one runs out. Login **cannot** be done non-interactively.

**Account pool (user, 2026-10-01): quota 429 is rotated automatically by `agy-run`, no user action.** The tool lives in `~/tools/agy-acct` (GitHub: private repo `luongtrz/rotate-agy`; the commands `agyr` and `agy-run` are symlinked into `~/.local/bin`; see its README) and keeps one token slot per account in `~/.gemini/antigravity-cli/accounts/` (`agyr list` shows slots, the active one `*` and cooldowns). Run every implement/explore session through `agy-run` instead of a bare `agy -p`: on `Individual quota reached` it kills agy at once, records the cooldown from `Resets in …`, switches to the next ready account and resumes the same conversation. Setup is one-time and manual: the user logs each account in with `! agy` and then `! agyr save <name>` (names are free-form: letters, digits, `-`, `_`); re-run `save` after any manual re-login, otherwise the next `use` overwrites that slot with another account's token. To switch account by hand don't use agy's logout (unknown whether it revokes the refresh token) — `rm` the local token file, run `agy`, then `save`. Don't read token contents: in normal work only `agyr` and `stat` touch the files (the user allowed one structure-only look on 2026-10-01: fields `token.access_token` (expires after 1 h), `token.refresh_token`, `token.expiry`, `id_token`; the access token is refreshed automatically from the refresh token). `agyr` decides which account is active by matching the real token file's `refresh_token` against the slots, not by the name stored in its state — so if the user logs in by hand the table and `use` stay correct; an unsaved login shows as a warning ("matches no slot") and needs `agyr save <name>`. Claude may test the tool with `bash ~/tools/agy-acct/test/run.sh` (fake agy, fake tokens). Other commands: `agyr list` (measures every account's real 5 h / weekly Gemini % via `agy -p /quota` — 0 tokens, ~10–20 s, runs in parallel in throwaway HOME dirs so it never touches the real token file and is safe while an `agy-run` or the user's agy is running; `*` marks the account the real token file belongs to; `agyr list -c` prints the saved numbers without calling agy; a cheap pre-flight before a big batch), `agyr rotate` (when the user's own interactive `agy` ran dry: they exit agy, run `agyr rotate`, then `agy -c`). **Report reset times to the user in UTC+7** (user rule, 2026-10-01; `agyr` already prints them that way). **Keyring trap (agy >= 1.2.14, seen 2026-10-02):** agy keeps its login in the GNOME keyring (libsecret over D-Bus) and ignores the swapped token file while the keyring is reachable, so plain `agy` ignores `agyr use` and every account measured the same quota. `agyr list`, `agyr run` and `agy-run` therefore start agy with `DBUS_SESSION_BUS_ADDRESS=unix:path=/nonexistent`, which makes agy fall back to the token file. Never launch agy for the pool without that (use `agy-run` / `agyr run`, not a bare `agy`), and tell the user to start their own interactive agy with plain `agyr` (same as `agyr run`; `agyr -c` continues the last conversation, any agy flag works, e.g. `agyr -p "..."`) instead of a bare `agy`. For Claude's own calls prefer the explicit form `agyr run <args>` (a first argument that does not start with `-` is read as an agyr command, so `agyr run models`, not `agyr models`). If `agyr list` ever shows identical numbers for every account again, the keyring bypass has stopped working. **Stale-429 trap (seen 2026-10-01):** when a conversation is resumed, agy may echo the OLD quota error inside the final `{"event":"result"}` JSON line (status ERROR, same `Resets in` value as before, no plain-text `error:` / `AGY_ERROR:` lines) even though the new run worked — `agy-run` ignores JSON lines for 429 detection, so such a run ends with exit 1 and the reason in its message; read the log's `response` to see whether the task actually finished, and never treat that as a real quota stop. Caveat: parallel `agy-run`s share one pool best-effort — a sibling's switch changes the token file under the others, which is fine because each tracks its own account for cooldowns.

**Rule (user, 2026-09-25): if a run ends with an auth failure, or `agy-run` exits 5 (whole pool on cooldown), STOP immediately and tell the user so they can re-login** (suggest they type `! agyr` in the prompt (plain `agyr` = `agyr run`) — not a bare `! agy`, which would log in through the keyring and leave the token file stale — possibly switching account, then `! agyr save <name>`; **not yet verified (2026-10-02)** that a login done under `agyr` lands in the token file, so after the user's first re-login check with `agyr list` that the account shows up with its own numbers under the saved slot). Don't retry in a loop, don't silently fall back to doing the task yourself. Resume the same task automatically once the re-login is detected (see "Auto-continue after an account switch" below) — the user does not need to type "continue". For a pool-exhausted stop, tell the user the earliest reset time from the `agy-run` message.
- `Error: authentication required. Run 'agy' to log in, then retry.` / `"error":"authentication failed or timed out"` (seen 2026-09-25 — the session had been logged out; `num_turns:0`, `total_tokens:0`)
- `You are not logged into Antigravity` (in `~/.gemini/antigravity-cli/log/cli-*.log`)
- `RESOURCE_EXHAUSTED (code 429): Individual quota reached … Resets in <duration>` — agy retries ~8 times with backoff, then fails. With the account pool this is handled by `agy-run` (rotate + resume); it only becomes a STOP when every account is on cooldown (`agy-run` exit 5) or when running bare `agy -p` without the pool.
- `agyr run models` → `Please sign in to view available models` also means logged out. (`agy models` only lists models and never tells which account is signed in; use `agyr list` to see every slot's account, a dead slot shows `measure failed`.)

### Auto-continue after an account switch (user, 2026-09-25)

The user does NOT want to type "continue" after re-logging in — Claude detects the switch and resumes on its own:
1. **Run multi-step work as a sequential loop that breaks on failure**, one log per session, so an auth failure or an exhausted pool never lets later sessions start on a dead account. `agy-run` already rotates accounts on 429 and passes the HARD-RULES-relevant flags (`--model gemini-3.8-flash-high` by default, `--dangerously-skip-permissions`, `--output-format stream-json`); pass `--model gemini-3.7-flash-high` only for the 503 fallback. Its exit code is the loop condition (0 ok, 1 other agy failure, 4 auth, 5 pool exhausted, 6 too many switches):
   ```bash
   for t in task-a task-b task-c; do
     agy-run --prompt .agy-sessions/$t.txt --add-dir "$TARGET" --log .agy-sessions/$t.jsonl
     rc=$?; echo "$t: exit $rc"; [ "$rc" -eq 0 ] || break
   done
   ```
   Run it with `run_in_background: true` like any agy run. Steps 2–5 below now apply only after exit 4 or 5 (manual re-login needed), and `agy-run` already does step 4's resume itself when rotating.
2. On a quota/auth failure: tell the user which session stopped (they re-login with `! agyr`, possibly the other account, then `! agyr save <name>`), then **watch the OAuth token file's mtime** — `~/.gemini/antigravity-cli/antigravity-oauth-token` is rewritten on every login **and on automatic token refresh** (observed 2026-10-01: `token.expiry` = mtime + 1 h), so an mtime change alone does not prove a re-login — confirm with step 3 and `agyr list`. Only `stat -c %Y` it; **never read its contents**. Use Monitor with an until-loop on the mtime changing (or, if the mtime is already newer than the failed session's start, the user switched early — continue immediately).
3. When it changes: confirm with `agyr list` (free, 0 tokens) that the account is signed in and measures its own numbers, then resume from the failed session only — sessions that already returned SUCCESS stay as they are.
4. How to resume: agy has `--continue`/`-c` (most recent conversation) and `--conversation <id>` (the id is in each log's first `{"event":"init",…}` line). **Confirmed 2026-09-28: a conversation survives an account switch** — `agyr run --conversation <id> -p "Continue the task from where you stopped …" --add-dir … --model … --dangerously-skip-permissions --output-format stream-json > <task>-resume.jsonl` resumed two quota-killed sessions on the new account with context intact. If resume ever errors, re-run the session's original prompt with a note that partial uncommitted edits may already exist in the worktree and must be finished/verified, not reverted. The worktree keeps agy's partial edits either way.
5. A running process does NOT pick up a new login (confirmed 2026-09-28): it keeps the old token and keeps retrying 429 (`Resets in …` in `~/.gemini/antigravity-cli/log/cli-*.log`, `error_message` steps in the jsonl). After the user switches, `kill` those `agy -p` pids and resume each by conversation id (step 4). The oauth-token file exists as of 2026-10-01 (it did not on 2026-09-28) — if `stat` fails, confirm the switch with `agyr list` instead.

After every run, check the final `result` event: `grep '^{' <log>.jsonl | jq -c 'select(.event=="result") | .result | {status,error,num_turns,usage}'`. **The `grep '^{'` is required** — agy interleaves plain-text lines into the stream-json log (e.g. `root agent idle; waiting up to 15m0s for 1 background task(s)` when it backgrounds a long command), which makes bare `jq` fail with `parse error: Invalid numeric literal`. To audit what agy actually executed: `grep '^{' <log> | jq -r 'select(.step_update.state=="ACTIVE" and .step_update.tool_name=="run_command") | .step_update.tool_info.parameters.CommandLine'`.

Cost reference for a read-only MR review (3 small files, 2026-09-25): ~7 min, ~122 steps, ~642k tokens (3.4M cache-read) — a "small" review still burns far more than the 31k smoke test because agy explores (git log/blame, generated api-client, runs lint/type-check/tests on its own). Point it at exact files/lines and say which verify commands Claude already ran, to cut this.

**Quota model:** per-account **5-hour limit** + **weekly limit** (shared by Gemini Flash & Pro), visible in the interactive TUI's "Models & Quota" view **and via `agy -p "/quota"` (confirmed 2026-10-01: works in print mode, 0 tokens, `num_turns:0`; output is tab-separated `<group>\t<metric>\t<pct>\t<UTC reset>` lines, e.g. `Gemini Models\tFive Hour Limit Remaining\t74%\t2026-10-01T10:53:39Z`)**. Use `agyr list` for it (see "Account pool"; a plain `agy -p /quota` now reports the keyring's account, not the selected one); a Gemini group at 0% means that account cannot run Gemini until its reset time (`agyr list` then sets the cooldown itself, and clears a stale cooldown when the measured quota is above 0).

**Why quota burns fast (traced 2026-09-25 from `~/.gemini/antigravity-cli/conversations/*.db` `gen_metadata`):** every tool call is one model request that resends the whole conversation context. Baseline is ~20k tokens even for a 1-turn prompt; long sessions grow to the 256k context ceiling and then cost ~250k tokens *per tool call*. Worst observed: one conversation bundling 6 bugs = 437 requests, 56.5M context tokens total; 21–24/09 total ≈ 4.4k requests / 455M context tokens. Aggravators: bundling many tasks into one session, repeatedly viewing/editing huge files (e.g. 2000+ line locale JSON or service files), and ~10 overlapping sessions in parallel. Therefore:
- **One small task per session.** Never bundle multiple bugs/features into one prompt.
- **Point to exact files/lines** in the prompt so agy doesn't explore/re-read big files.
- Consider `--print-timeout` to cap runaway sessions.
- **Up to 3 agy runs at the same time** (user rule, 2026-09-28 — supersedes the earlier "one at a time" preference). See "Parallel runs" below for how to keep them from colliding.

### Parallel runs (max 3 concurrent)

When the user wants independent tasks done at once, launch up to **3** agy runs in parallel (separate `run_in_background` Bash calls, one log each). Rules:
- **Implement tasks: one git worktree per run**, all branched from the same base commit (`git worktree add .worktrees/agy-<task> -b agy/<task> <base-sha>`), each prepared with `pnpm install --frozen-lockfile --prefer-offline`, `pnpm api:gen`, and a copied `routeTree.gen.ts`. Never let two runs write to the same worktree — even disjoint files collide in concurrent vitest/tsc runs and make the diff impossible to attribute.
- Read-only review runs can share the main checkout (they must not write).
- **Integrate afterwards, one run at a time:** review each worktree's diff and re-run its verify commands, commit it on its own branch, then cherry-pick the commits in a fixed order onto one integration branch (e.g. the first run's branch). Tasks that touch the same files (validator + its test, same dialog) will usually conflict at the ends of test files — resolve by keeping both sides, then re-run the full verify on the integrated branch before fast-forwarding the MR branch.
- If the tasks touch the same files heavily, prefer running them sequentially in one worktree instead — parallelism is only worth it when the conflict surface is small.
- Each parallel run burns its own quota; a 429 in one run doesn't stop the others — check every run's `result` event.
- 3 concurrent `pnpm vitest`/`tsc` runs load the host noticeably; don't exceed 3.

Reference smoke test (2026-09-25, read-only "report the validator regexes + line numbers in `backend/internal/server/validator.go`"): SUCCESS, ~11s, 1 turn, ~31k tokens, correct answer, `--add-dir` respected, repo untouched. Use this as a cheap "is agy alive?" check.

## Real-time log streaming — use `--output-format stream-json`, not `text`

**Confirmed 2026-09-22: `--output-format text` writes NOTHING to stdout until the entire turn finishes** — a `tail -f` on a `text`-mode log stays empty the whole run, then dumps everything at once at the end (same pitfall as opencode piping through `tail` — see that skill). **`--output-format stream-json` genuinely streams**, one NDJSON event per line, appended incrementally as the run progresses (verified: log grew from 0B to a first `init` event within ~15s, then kept growing with a `step_update` event per token as the response was generated, well before the run finished).

Event shapes seen: `{"event":"init",...}` once at start (lists the tool names available to this agy session), then repeated `{"event":"step_update","step_update":{...,"step_type":"agent_response","text_delta":"..."}}` (or other `step_type`s for tool calls — not yet enumerated), and a final `{"event":"result","result":{"status":"SUCCESS","response":"<full text>","num_turns":…,"usage":{…}}}`.

For a human-readable live feed instead of raw NDJSON, pipe through `jq`:
```bash
tail -f "$LOGDIR/.agy-sessions/<task-name>.jsonl" | jq -r --unbuffered \
  'select(.event=="step_update") | .step_update.text_delta // empty'
```
Give the user this `tail -f | jq` command (not a bare `tail -f`) whenever they want to actually watch the response being generated rather than just confirm the process is alive. For your own post-hoc verification, the final `result` event's `.result.response` field has the complete text — no need to reassemble `text_delta` chunks yourself.

## CRITICAL — always pass `--add-dir`, verify agy actually touched your repo

**Confirmed 2026-09-22, reproduced twice:** without `--add-dir`, `agy` does NOT operate on the invoking shell's `cwd`. Both `--sandbox` mode and plain `--dangerously-skip-permissions` mode (no `--add-dir`) silently wrote a requested file into a fixed default workspace at `~/.gemini/antigravity-cli/scratch/` instead of the current directory — while agy's own text report read like a normal success message (`"Created agytest.txt containing..."`) with only the fully-qualified `file://` link revealing the real (wrong) location. A skim of the report alone will not catch this.

Passing `--add-dir <absolute-path-to-target-dir>` fixed it — the file then landed exactly where expected (confirmed for both `--sandbox` and `--dangerously-skip-permissions`).

**Rules:**
- **Every invocation MUST include `--add-dir <absolute-path>`** — the main repo for read-only tasks, the worktree path for implement tasks (see below). Never rely on cwd alone.
- **After every run, verify independently in the target directory itself** — `git status`/`git diff --stat`, or `ls`/`cat` the exact file — before trusting anything agy's report says. Exit code was `0` even on misdirected runs.
- If a run's report shows a `file://` link, glance at the link's directory, not just the filename.

## When to use

- The task is small and self-contained enough to write as one prompt with no back-and-forth.
- Either it's mechanically verifiable (build/lint/test passes, diff matches an existing pattern) or it's a read-only investigation whose findings you can sanity-check yourself afterward.
- You want a genuinely separate process perspective (a real subprocess, not another in-process subagent), not just more of your own reasoning.

## When NOT to use

- Architecture/design decisions, security-sensitive code, anything requiring nuanced judgment calls — same reasoning as the `opencode` skill.
- Anything you can't fully specify in a single self-contained prompt (agy has zero context on this conversation).
- If producing the delegation prompt requires the same research/reasoning as just doing the task yourself, skip delegation and do it directly.
- Big multi-bug batches — split them (see quota section).

## Safety — `--dangerously-skip-permissions` + HARD RULES + worktree isolation

**User preference (2026-09-25): run agy with `--dangerously-skip-permissions`** to avoid constant permission prompts. With the user's explicit instruction, Claude Code's classifier allowed it (earlier, on 2026-09-22, it blocked the flag when used on Claude's own initiative — reason "Create Unsafe Agents"; if it gets blocked again, tell the user rather than working around it). `--sandbox` also works with `--add-dir` (wrote a real file + ran a shell check on 2026-09-22) and is the fallback if the user ever prefers it.

Because the flag auto-approves **every** tool call (file deletes, arbitrary shell, git), safety comes from two layers:

### 1. Task class decides where agy may operate (user rule, 2026-09-25)

| Task class | `--add-dir` | Writes |
|---|---|---|
| **Explore / bug-finding** (read-only) | main repo root | **none** — prompt forbids any file write or mutating command |
| **Implement** (changes code) | **a dedicated git worktree only**, never the main checkout | only the files listed in scope |

For implement tasks, **Claude creates the worktree itself before delegating** (don't ask agy to run `git worktree add` — that would require giving it write access to the main checkout first, defeating the isolation):
```bash
cd "$REPO" && git status --short            # must be clean
git worktree add ".worktrees/agy-<task>" -b "agy/<task>"   # from current branch
WT="$REPO/.worktrees/agy-<task>"
# install deps in the worktree yourself if verify needs them (e.g. pnpm install --frozen-lockfile)
```
In this repo `.worktrees/` is ignored via `.git/info/exclude` and `.agy-sessions/` via `.gitignore`. After verifying, bring the changes over / commit as the user wants, then `git worktree remove` + delete the branch (host has limited disk).

### 2. Every prompt carries a HARD RULES block

Paste verbatim, adapting `<ABS_PATH>` (repo for explore, worktree for implement):
```
HARD RULES (violating any = task failure):
- Work ONLY inside <ABS_PATH>. Never read or write outside it; never touch ~, /etc, other repos, or any other checkout of this repo.
- NO git commit/push/merge/rebase/reset/checkout/switch/stash/clean/branch -D/worktree add|remove; nothing with --force.
- NO rm -rf, and do not delete any file you did not create for this task.
- Do NOT edit .env*, credentials, CLAUDE.md, CLAUDE-*.md, AGENTS.md, GEMINI*.md, or lockfiles unless the task explicitly says so.
- NO installing/upgrading packages, NO docker / database / migration commands, NO network calls except what the verify step needs.
- Touch ONLY the files listed in scope. [Explore/bug-finding tasks: do NOT create, edit or delete ANY file.]
- If blocked or unsure, STOP and report instead of improvising.
- Finish by listing every file you changed (or "none") plus the output of each verify command.
```

## Where to store task files

Do **not** use `/tmp` or agy's own default scratch dir (`~/.gemini/antigravity-cli/scratch/`). Use `<main-repo-root>/.agy-sessions/` (also for implement tasks — keep prompts/logs out of the worktree agy works in):
1. `mkdir -p "$REPO/.agy-sessions"`; make sure `.agy-sessions/` is gitignored.
2. Write the prompt to `.agy-sessions/<task-name>.txt` (avoids shell-quoting breakage).
3. Keep the `.jsonl` logs as audit trail; delete only the prompt file once done.

## Workflow

1. **Plan, don't over-specify** (user rule 2026-09-25, see global CLAUDE.md "Role split"). Investigate only enough to write a clear plan: goal, root cause / suspected area, relevant files, pattern to mirror, acceptance criteria, verify commands. Don't pre-trace every line or paste full code into the prompt — that burns Claude tokens on agy's job; Claude traces the code afterwards during review. If Claude already found the exact line(s) to change, skip agy and edit directly. Keep the task small (one bug/change per session).
2. **Classify:** explore/bug-finding → `TARGET=$REPO`; implement → create the worktree (above), `TARGET=$WT`.
3. **Write the prompt to a file:**
   ```bash
   REPO=/absolute/path/to/repo
   mkdir -p "$REPO/.agy-sessions"
   cat > "$REPO/.agy-sessions/<task-name>.txt" <<'EOF'
   Repo: <brief stack description>. Working directory: <TARGET abs path>.
   Task: <goal, one paragraph>.
   Plan: <root cause / suspected area>, <relevant files>, <pattern to mirror>.
   Acceptance criteria: <observable behaviour that must hold when done>.
   <HARD RULES block from above, with <ABS_PATH> = TARGET>
   Verify before finishing: <exact build/lint/test commands, run inside TARGET>. All must pass.
   EOF
   ```
4. **Check `git status` is clean in TARGET**, then run non-interactively, in the background (`run_in_background: true`):
   ```bash
   agy-run --prompt "$REPO/.agy-sessions/<task-name>.txt" \
       --add-dir "$TARGET" \
       --log "$REPO/.agy-sessions/<task-name>.jsonl"
   ```
   `agy-run` is the standard launcher since 2026-10-01: it runs agy with `--model gemini-3.8-flash-high --dangerously-skip-permissions --output-format stream-json` (add `--model gemini-3.7-flash-high` only for the 503 fallback) and rotates accounts on 429 (see "Account pool" above). Optional 0-token pre-flight: `agyr list` for every account's remaining 5 h / weekly %. Fallback only if `agy-run` is unavailable (same flags, no rotation; the `DBUS_SESSION_BUS_ADDRESS` prefix makes agy ignore the keyring so it uses the selected account's token file):
   ```bash
   DBUS_SESSION_BUS_ADDRESS=unix:path=/nonexistent agy -p "$(cat "$REPO/.agy-sessions/<task-name>.txt")" \
       --add-dir "$TARGET" \
       --model gemini-3.8-flash-high \
       --dangerously-skip-permissions \
       --output-format stream-json \
       > "$REPO/.agy-sessions/<task-name>.jsonl" 2>&1
   ```
   Tell the user the `tail -f … | jq` command so they can watch live.
5. **Check the exit code and the result event** — `agy-run` exit 4 (auth) or 5 (whole pool on cooldown): stop and tell the user (re-login, or the earliest reset time in UTC+7; see "Auth & quota"); 429s were already rotated for you. `agy-run` does not handle 503: it ends with exit 1 and a 503 in the log — on repeated 503 "No capacity" errors, relaunch on `gemini-3.7-flash-high` (see "503 fallback").
6. **Verify independently in TARGET** — `git status` / `git diff --stat` / re-run build/lint/test yourself. For explore tasks, confirm `git status` is still clean and sanity-check findings against the code. Don't trust the self-report or exit code 0.
7. **Clean up the prompt file** (`rm -f .agy-sessions/<task-name>.txt`), keep the log.
8. **Stage only in-scope files explicitly** (never `git add -A`), commit only when the user asks; remove the worktree + branch when done.
