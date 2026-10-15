# 503 "No capacity" -> fall back to `gemini-3.8-flash-medium`, then `gemini-3.8-flash-low` (user rule, 2026-10-13)

Read this when a run ends with, or a running session keeps showing, `UNAVAILABLE (code 503): No capacity available for model gemini-3.8-flash-high on the server`.

**When to switch:** 3.8-high keeps failing — the session's result is that error, or `~/.gemini/antigravity-cli/log/cli-*.log` shows repeated 503 / `retrying in …` with no successful `streamGenerateContent` for ~5+ minutes (or the same after one fresh relaunch). Then relaunch on `--model gemini-3.8-flash-medium` (exact name from `agy models`) instead of waiting it out, and tell the user you switched and why.

**Low is the last step:** only if `gemini-3.8-flash-medium` also keeps failing with the same 503 (same trigger) relaunch on `--model gemini-3.8-flash-low`. Never go to low while medium still answers.

**Not a reason to switch:** a single 503 that clears on its own — just retry once after ~60 s.

- 503 is Google-side capacity, not quota/auth: re-login, account switch or relaunching on the same model does not help.
- `agy-run` does not handle 503: it ends with exit 1 and the 503 in the log.
- Before relaunching on a fallback model: kill the stuck run (the `agy-run` pid and its `agy -p` child, `pgrep -P <agy-run pid>`), check the worktree is still clean (or note partial edits in the new prompt), archive the old `.jsonl` by renaming it (do not delete), reuse the same prompt file unchanged, and relaunch through `agy-run … --model gemini-3.8-flash-medium` (never a bare `agy`).
- Go back to `gemini-3.8-flash-high` for the next new task. Medium and low are outage fallbacks, not the new default. No other models, ever (no Claude, GPT-OSS).
- Review output from a fallback model as strictly as 3.8-high's: run the tests yourself and read the diff.

**Stalled or erroring without a clean 503 (2026-10-01):** a session that sits under ~5 events after ~5 min, or a `result` of ERROR/500 with a clean worktree → kill it (`pgrep -P <agy-run pid>`), archive the jsonl, relaunch on `gemini-3.8-flash-medium`.
