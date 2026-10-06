# 503 "No capacity" -> fall back to `gemini-3.7-flash-high` (user rule, 2026-09-29)

Read this when a run ends with, or a running session keeps showing, `UNAVAILABLE (code 503): No capacity available for model gemini-3.8-flash-high on the server`.

**When to switch:** 3.8 keeps failing — the session's result is that error, or `~/.gemini/antigravity-cli/log/cli-*.log` shows repeated 503 / `retrying in …` with no successful `streamGenerateContent` for ~5+ minutes (or the same after one fresh relaunch). Then use `--model gemini-3.7-flash-high` (exact name from `agy models`) instead of waiting it out, and tell the user you switched and why.

**Not a reason to switch:** a single 503 that clears on its own — just retry once after ~60 s.

- 503 is Google-side capacity, not quota/auth: re-login, account switch or relaunching on 3.8 does not help (seen 2026-09-29: ~30 min of stalls, three relaunches, zero edits).
- `agy-run` does not handle 503: it ends with exit 1 and the 503 in the log.
- Before relaunching on 3.7: `kill` the stuck `agy -p` pids, check the worktree is still clean (or note the partial edits in the new prompt), archive the old `.jsonl`, reuse the same prompt file unchanged, and relaunch through `agy-run … --model gemini-3.7-flash-high` (never a bare `agy`).
- 3.7 quality (three small fixes, 2026-09-29): on par with 3.8 — stayed in scope, minimal diffs, matching tests, verify passed, ~3–5 min per session with no 503s. Review its output exactly as strictly as 3.8's.
- Go back to 3.8 for the next new task; 3.7 is the outage fallback, not the new default. No other models, ever. When the user says 3.8 is slow or congested ("nghẽn", "dùng 3.7 đi"), prefer 3.7 for new runs until they say it recovered.
- 3.7 nit: it once left a trailing blank line that gofmt flagged — run `gofmt -l` on any Go file it touched.

**Stalled or erroring without a clean 503 (2026-10-01, products-page work):** one 3.8 session sat at 2 events for 10 min (no model response; `INTERNAL 500` / 503 retries in `~/.gemini/antigravity-cli/log/cli-*.log`, conversation id missing from the log) and another ended `status ERROR … INTERNAL (code 500)` with zero edits. Relaunching both on 3.7 finished in ~5–8 min each, and ~14 later sessions on 3.7 had no failure. Rule of thumb: a session with <5 events after ~5 min, or a `result` of ERROR/500 with a clean worktree → kill it (`pgrep -P <agy-run pid>`), archive the jsonl, relaunch on 3.7.
