#!/usr/bin/env bash
# Independent core test section.
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$TEST_DIR/lib.sh"

echo "== agy-run"

setup
runit; rc=$?
eq "immediate success: exit 0" "0" "$rc"
eq "runs only once" "1" "$(lines)"
has "uses the acc1 token" "tok-acc1|" "$(cat "$FAKE_ARGS_LOG")"
has "passes --add-dir" "--add-dir $T/work" "$(cat "$FAKE_ARGS_LOG")"
has "passes --model gemini-3.8-flash-high" "--model gemini-3.8-flash-high" "$(cat "$FAKE_ARGS_LOG")"
has "passes --dangerously-skip-permissions" "--dangerously-skip-permissions" "$(cat "$FAKE_ARGS_LOG")"

setup
export FAKE_QUOTA_TOKENS="tok-acc1"
start=$SECONDS
runit; rc=$?
elapsed=$((SECONDS - start))
eq "acc1 out of quota -> switch to acc2, exit 0" "0" "$rc"
eq "runs twice" "2" "$(lines)"
second="$(sed -n 2p "$FAKE_ARGS_LOG")"
has "second run uses the acc2 token" "tok-acc2|" "$second"
has "second run resumes the same conversation" "--conversation conv-fake-1" "$second"
hasnt "second run does not resend the original prompt" "do the thing" "$second"
eq "acc1 cooldown 15199s (4h13m19s)" "$((1000000 + 15199))" "$(cd_of acc1)"
eq "active = acc2" "acc2" "$("$ACCT" active)"
[ "$elapsed" -lt 20 ] && pass "killed immediately, did not wait for agy's retries (${elapsed}s)" || fail "killed immediately, did not wait for agy's retries" "took ${elapsed}s"
sleep 0.3
if command -v pgrep >/dev/null; then
  eq "no fake-agy process left behind" "0" "$(leaked_fake_agy)"
else
  echo "  skip 'no fake-agy process left behind': no pgrep on this system"
fi

setup
export FAKE_QUOTA_TOKENS="tok-acc1 tok-acc2"
runit; rc=$?
eq "two accounts in a row out of quota -> exit 0" "0" "$rc"
eq "runs three times" "3" "$(lines)"
has "third run uses acc3" "tok-acc3|" "$(sed -n 3p "$FAKE_ARGS_LOG")"
has "third run still resumes the same conversation" "--conversation conv-fake-1" "$(sed -n 3p "$FAKE_ARGS_LOG")"

setup
export FAKE_QUOTA_TOKENS="tok-acc1 tok-acc2 tok-acc3"
runit; rc=$?
eq "whole pool out of quota -> exit 5" "5" "$rc"
has "reports the whole pool is out of quota" "whole pool is out of quota" "$(cat "$T/run.err")"
out="$("$ACCT" next 2>&1)"; eq "state: all 3 on cooldown" "3" "$?"

setup
export FAKE_QUOTA_TOKENS="tok-acc1 tok-acc2 tok-acc3" AGY_RUN_MAX_SWITCH=1
runit; rc=$?
eq "exceeding the max number of switches -> exit 6" "6" "$rc"

setup
export FAKE_AUTH=1
runit; rc=$?
eq "auth error -> exit 4" "4" "$rc"
eq "auth error: account is not switched" "acc1" "$("$ACCT" active)"
eq "auth error: runs only once" "1" "$(lines)"

# login-error phrases only count as plain lines or as the result event's error, never inside step_update content: a task
# that reads or edits a file containing one was killed with a false exit 4 (2026-11-13)
setup
export FAKE_AUTH_ECHO=1
runit; rc=$?
eq "login-error phrases inside a step_update (agy read a file) -> not a login error, exit 0" "0" "$rc"
eq "login-error phrases inside a step_update: runs only once" "1" "$(lines)"
unset FAKE_AUTH_ECHO

setup
export FAKE_AUTH_RESULT=1
runit; rc=$?
eq "login failure as the result event's error -> exit 4" "4" "$rc"
eq "login failure as the result event's error: account is not switched" "acc1" "$("$ACCT" active)"
unset FAKE_AUTH_RESULT

setup
rm -f "$AGY_HOME/accounts/state.json" "$AGY_HOME/antigravity-oauth-token"
runit; rc=$?
eq "no active account -> exit 4" "4" "$rc"
eq "agy is not run when there is no active account" "0" "$(lines)"

setup
echo 'error: Individual quota reached. Resets in 1h.' >"$T/run.jsonl"
runit; rc=$?
eq "an old 429 line in the log is not counted again" "0" "$rc"
eq "old log: runs only once" "1" "$(lines)"

# a resumed conversation echoes the OLD quota error in its final result event (no plain-text 429 lines, non-empty response): not a new 429 and treated as done
setup
export FAKE_STALE_ERROR=1
runit; rc=$?
eq "stale quota error in the result event: no account switch (runs once)" "1" "$(lines)"
eq "stale quota error: acc1 gets no cooldown" "0" "$(cd_of acc1)"
eq "stale quota error: the active account is unchanged" "acc1" "$("$ACCT" active)"
eq "stale quota error: exit 0 (response is non-empty, stale quota echo)" "0" "$rc"
has "stale quota error: says why it did not switch" "no new 429 line" "$(cat "$T/run.err")"
has "stale quota error: shows the result error" "result error: Individual quota reached" "$(cat "$T/run.err")"
unset FAKE_STALE_ERROR

# result status ERROR with empty response and no plain-text 429 line still exits 1
setup
export FAKE_HI_ERROR_TOKENS="tok-acc1"
runit; rc=$?
eq "status ERROR with empty response and no plain-text 429 line: exit 1" "1" "$rc"
unset FAKE_HI_ERROR_TOKENS

setup
"$RUN" --prompt "$T/prompt.txt" --add-dir "$T/work" --log "$T/run.jsonl" --conversation "conv-custom-123" 2>"$T/run.err"; rc=$?
eq "agy-run --conversation: exit 0" "0" "$rc"
eq "agy-run --conversation: runs once" "1" "$(lines)"
first="$(sed -n 1p "$FAKE_ARGS_LOG")"
has "agy-run --conversation: first call carries --conversation X" "--conversation conv-custom-123" "$first"
has "agy-run --conversation: first call passes prompt" "-p do the thing" "$first"

setup
export FAKE_QUOTA_TOKENS="tok-acc1"
"$RUN" --prompt "$T/prompt.txt" --add-dir "$T/work" --log "$T/run.jsonl" --conversation "conv-custom-123" 2>"$T/run.err"; rc=$?
eq "agy-run --conversation with 429: exit 0" "0" "$rc"
eq "agy-run --conversation with 429: runs twice" "2" "$(lines)"
first="$(sed -n 1p "$FAKE_ARGS_LOG")"
second="$(sed -n 2p "$FAKE_ARGS_LOG")"
has "agy-run --conversation with 429: first call carries --conversation X" "--conversation conv-custom-123" "$first"
has "agy-run --conversation with 429: second call keeps resuming same conversation" "--conversation conv-custom-123" "$second"
unset FAKE_QUOTA_TOKENS

setup
"$RUN" --prompt "$T/prompt.txt" --add-dir "$T/work" --log "$T/run.jsonl" --conversation 2>/dev/null; rc=$?
eq "agy-run --conversation without ID -> exit 2" "2" "$rc"

setup
runit >/dev/null; "$RUN" --bogus 2>/dev/null; eq "unknown argument -> exit 2" "2" "$?"

exit 0
