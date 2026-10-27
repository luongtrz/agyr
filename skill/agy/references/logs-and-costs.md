# Reading agy logs, and why quota burns (read when auditing a run or planning a batch)

## stream-json log
`agy-run` always runs agy with `--output-format stream-json`. (Confirmed 2026-09-22: `--output-format text` writes NOTHING to stdout until the whole turn finishes, so `tail -f` stays empty; stream-json appends one NDJSON event per line as it goes.) There is no web UI / attach flow for agy.

Events: `{"event":"init",…}` once (lists the tools; the first line holds the conversation id), repeated `{"event":"step_update","step_update":{…,"step_type":"agent_response","text_delta":"…"}}` (other `step_type`s for tool calls), and a final `{"event":"result","result":{"status":"SUCCESS","response":"<full text>","num_turns":…,"usage":{…}}}`.

agy interleaves plain-text lines into the log (e.g. `root agent idle; waiting up to 15m0s for 1 background task(s)`), so **`grep '^{'` is required before `jq`**, otherwise `jq` fails with `parse error: Invalid numeric literal`.

```bash
# live feed for the user
tail -f "$LOG" | jq -r --unbuffered 'select(.event=="step_update") | .step_update.text_delta // empty'
# final result of a run
grep '^{' "$LOG" | jq -c 'select(.event=="result") | .result | {status,error,num_turns,usage}'
# full response text (no need to reassemble text_delta chunks)
grep '^{' "$LOG" | jq -r 'select(.event=="result") | .result.response'
# what agy actually executed
grep '^{' "$LOG" | jq -r 'select(.step_update.state=="ACTIVE" and .step_update.tool_name=="run_command") | .step_update.tool_info.parameters.CommandLine'
```
Give the user the `tail -f … | jq` command (not a bare `tail -f`) whenever they want to watch the response being generated.

## The `--add-dir` trap (confirmed 2026-09-22, reproduced twice)
Without `--add-dir`, agy does NOT operate on the shell's cwd — `--sandbox` and `--dangerously-skip-permissions` alike silently wrote the requested file into `~/.gemini/antigravity-cli/scratch/`, while agy's report read like a normal success (`"Created agytest.txt containing…"`), exit code `0`; only the fully-qualified `file://` link in the report showed the wrong directory. With `--add-dir <absolute-path>` the file landed correctly. So: every invocation has `--add-dir`, and after every run verify in the target dir itself (`git status`/`git diff --stat`, or `ls`/`cat` the exact file); glance at the directory of any `file://` link in the report.

## Why quota burns fast (traced 2026-09-25 from `~/.gemini/antigravity-cli/conversations/*.db` `gen_metadata`)
Every tool call is one model request that resends the whole conversation context. Baseline ~20k tokens even for a 1-turn prompt; long sessions reach the 256k context ceiling and then cost ~250k tokens *per tool call*. Worst observed: one conversation bundling 6 bugs = 437 requests, 56.5M context tokens; 21–24/09 total ≈ 4.4k requests / 455M context tokens. Aggravators: bundling many tasks into one session, repeatedly viewing/editing huge files (`vi/web-vendor.json` 2000+ lines, `backend/internal/vendor/service.go` 1900 lines), ~10 overlapping sessions in parallel. So:
- **One small task per session.** Never bundle several bugs/features into one prompt.
- **Point to exact files/lines** so agy doesn't explore or re-read big files; say which verify commands Claude already ran.
- Consider `--print-timeout` to cap runaway sessions.

Cost reference (read-only review of 3 small files, 2026-09-25): ~7 min, ~122 steps, ~642k tokens (3.4M cache-read) — a "small" review still burns far more than the smoke test because agy explores (git log/blame, generated api-client, runs lint/type-check/tests on its own).

Smoke test ("is agy alive?", 2026-09-25): read-only "report the vnphone/vntaxcode regexes + line numbers in `backend/internal/server/validator.go`" → SUCCESS, ~11 s, 1 turn, ~31k tokens, correct answer, `--add-dir` respected, repo untouched.
