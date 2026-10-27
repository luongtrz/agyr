# Quota, login and the account pool (agy-run exit 4 / 5 / 6, 429, auth errors)

Read this when `agy-run` exits 4, 5 or 6, a log shows a 429 / auth error, or the user asks about accounts or quota.

agy uses interactive Google OAuth (consumer accounts). The user has several accounts (`acc1@…`, `acc2@…`, `acc3@…` seen 2026-09-25) and rotates between them. Login **cannot** be done non-interactively.

## STOP rule (user, 2026-09-25)

If a run ends with an auth failure, or `agy-run` exits **4** (login error / no active account) or **5** (whole pool on cooldown): **STOP immediately and tell the user.** Don't retry in a loop and don't silently do the task yourself.
- Exit 4: tell the user (logging in is theirs to do) and wait.
- Exit 5: tell the user the earliest reset time from the `agy-run` message, **in UTC+7**.
- Exit 6: agy-run switched accounts too many times; look at `agyr list` and the log before relaunching.
- Resume the same task automatically once the re-login is detected (see "Auto-continue" below); the user does not need to type "continue".

Error strings that mean logged out / quota:
- `Error: authentication required. Run 'agy' to log in, then retry.` / `"error":"authentication failed or timed out"` (`num_turns:0`, `total_tokens:0`)
- `You are not logged into Antigravity` (in `~/.gemini/antigravity-cli/log/cli-*.log`)
- `RESOURCE_EXHAUSTED (code 429): Individual quota reached … Resets in <duration>` — agy retries ~8 times with backoff, then fails. With the pool, `agy-run` rotates; it is a STOP only when every account is on cooldown (exit 5) or when running a bare `agy -p` without the pool.
- `agyr run models` → `Please sign in to view available models` also means logged out. (`agy models` only lists models; use `agyr list` to see every slot's account — a dead slot shows `measure failed`.)

## The pool (user, 2026-10-01: 429 is rotated automatically, no user action)

- Tool: `~/tools/agy-acct` (GitHub repo `luongtrz/agyr`, README there). `agyr` and `agy-run` are symlinked into `~/.local/bin`. One token slot per account in `~/.gemini/antigravity-cli/accounts/`.
- On `Individual quota reached`, `agy-run` kills agy at once, records the cooldown from `Resets in …`, switches to the next ready account and resumes the same conversation.
- Logging accounts in and saving their slots is the user's own operation; Claude neither runs nor explains it.
- **Duplicate slots:** `agyr save` does not check whether that login is already saved under another name (2026-10-05: `acc10` and `acc11` held the same login: identical numbers in `agyr list` and the same email in the agy banner, so the pool silently had one account less). If two rows of `agyr list` are identical, tell the user; they fix it themselves (don't touch the token file or run account commands while an `agy-run` is using it).
- `agyr` decides which account is active by matching the token file's `refresh_token` against the slots, not by its stored state, so manual logins keep the table correct; an unsaved login shows a warning ("matches no slot"); if you see it, tell the user.
- Commands: `agyr list` (measures every account's real 5 h / weekly Gemini % via `agy -p /quota`: 0 tokens, ~10–20 s, runs in parallel in throwaway HOME dirs so it is safe while an `agy-run` or the user's agy is running; `*` marks the account of the real token file), `agyr list -c` (saved numbers, no agy call), `agyr rotate` (when the user's own interactive agy ran dry: they exit agy, run `agyr rotate`, then `agyr -c`), `agyr test [name…]` (one real "Hi" request per account to start each 5 h window — uses real quota, premise unverified; **only when the user asks**), `agyr rename <old> <new>` (renames a slot with its login, cooldown and quota data; refuses an existing name), `agyr run <args>` (a first argument that does not start with `-` is an agyr command, so `agyr run models`, not `agyr models`). The user starts their own interactive agy with plain `agyr` (`agyr -c` continues the last conversation; any agy flag works).
- Report reset times to the user in **UTC+7** (`agyr` already prints them so).
- Never read token file contents; only `agyr` and `stat` touch the files. (The user allowed one structure-only look on 2026-10-01: `token.access_token` (expires after 1 h, refreshed automatically), `token.refresh_token`, `token.expiry`, `id_token`.)
- Test the tool: `bash ~/tools/agy-acct/test/run.sh` (fake agy, fake tokens).
- Parallel `agy-run`s share one pool best-effort: a sibling's switch changes the token file under the others, which is fine because each tracks its own account for cooldowns.

## Keyring trap (agy >= 1.2.14, seen 2026-10-02)

agy keeps its login in the GNOME keyring (libsecret over D-Bus) and ignores the swapped token file while the keyring is reachable, so a plain `agy` ignores `agyr use` and every account measured the same quota. `agyr list`, `agyr run` and `agy-run` therefore start agy with `DBUS_SESSION_BUS_ADDRESS=unix:path=/nonexistent`, which makes agy fall back to the token file. Never launch agy for the pool without that: use `agy-run` / `agyr run`, not a bare `agy`. If `agyr list` ever shows identical numbers for every account again, the keyring bypass has stopped working. (agy v1.2.10 on 2026-09-25 auto-updated to v1.2.14 on 2026-10-02, which moved the login into the keyring.)

Fallback only if `agy-run` itself is unavailable (same flags, no account rotation; the `DBUS_SESSION_BUS_ADDRESS` prefix is what makes agy use the selected account's token file):
```bash
DBUS_SESSION_BUS_ADDRESS=unix:path=/nonexistent agy -p "$(cat "$REPO/.agy-sessions/<task>.txt")" \
    --add-dir "$TARGET" --model gemini-3.8-flash-high \
    --dangerously-skip-permissions --output-format stream-json > "$REPO/.agy-sessions/<task>.jsonl" 2>&1
```
Cheap pre-flight before a big batch: `agyr list` (0 tokens) shows every account's remaining 5 h / weekly %.

## Stale-429 trap (seen 2026-10-01)

When a conversation is resumed, agy may echo the OLD quota error inside the final `{"event":"result"}` JSON line (status ERROR, same `Resets in`, no plain-text `error:` / `AGY_ERROR:` lines) even though the new run worked. `agy-run` ignores JSON lines for 429 detection, so such a run ends with exit 1 and the reason in its message. Read the log's `response` to see whether the task actually finished, and never treat it as a real quota stop. How to tell: the "Resets in" text is identical to the original failure; only a fresh `RESOURCE_EXHAUSTED` with a new timestamp in `~/.gemini/antigravity-cli/log/cli-*.log` is a real hit. Related resume quirk: `"The stream was interrupted. Please continue…"` — the edits so far are kept; resume once more (or finish with a small direct edit).

## Auto-continue after the user re-logs in (user, 2026-09-25)

The user does NOT want to type "continue" after re-logging in; detect it and resume.
1. Run multi-step work as a sequential loop that breaks on failure, one log per session, so a dead account never lets later sessions start:
   ```bash
   for t in task-a task-b task-c; do
     agy-task run --name $t --task .agy-sessions/$t.task.txt --scope '<paths>'   # or: agy-run --prompt … --add-dir … --log … for read-only tasks
     rc=$?; echo "$t: exit $rc"; [ "$rc" -eq 0 ] || break
   done
   ```
   Run it with `run_in_background: true`. Steps 2–5 apply only after exit 4 or 5 (`agy-task` passes agy-run's 4/5 through and keeps the worktree); `agy-run` already resumes itself when it rotates.
2. Tell the user which session stopped, then **watch the token file's mtime** (`stat -c %Y ~/.gemini/antigravity-cli/antigravity-oauth-token`; never read it). It is rewritten on every login **and on automatic token refresh** (`token.expiry` = mtime + 1 h), so a changed mtime alone does not prove a re-login — confirm with step 3. Use Monitor with an until-loop on the mtime changing (or, if the mtime is already newer than the failed session's start, continue immediately). If `stat` fails, confirm with `agyr list` instead.
3. When it changes: confirm with `agyr list` (0 tokens) that the account is signed in and measures its own numbers; then resume only the failed session — sessions that already returned SUCCESS stay.
4. Resume: agy has `--continue`/`-c` (most recent conversation) and `--conversation <id>` (the id is in each log's first `{"event":"init",…}` line). Confirmed 2026-09-28 that a conversation survives an account switch:
   `agyr run --conversation <id> -p "Continue the task from where you stopped …" --add-dir … --model … --dangerously-skip-permissions --output-format stream-json > <task>-resume.jsonl`
   If resume errors, re-run the original prompt with a note that partial uncommitted edits may already exist in the worktree and must be finished/verified, not reverted. The worktree keeps agy's partial edits either way.
5. A running process does NOT pick up a new login (confirmed 2026-09-28): it keeps the old token and keeps retrying 429. After the user switches, `kill` those `agy -p` pids and resume each by conversation id (step 4).

## Quota model

Per-account **5-hour limit** + **weekly limit** (shared by Gemini Flash & Pro), visible in the interactive TUI's "Models & Quota" view and via `agy -p "/quota"` (0 tokens, `num_turns:0`; tab-separated `<group>\t<metric>\t<pct>\t<UTC reset>`, e.g. `Gemini Models\tFive Hour Limit Remaining\t74%\t2026-10-01T10:53:39Z`). Use `agyr list` for it (a plain `agy -p /quota` reports the keyring's account, not the selected one). A Gemini group at 0% means that account cannot run Gemini until its reset time (`agyr list` then sets the cooldown itself and clears a stale cooldown when the measured quota is above 0). Why quota burns fast and how to spend less: `references/logs-and-costs.md`.
