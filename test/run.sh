#!/usr/bin/env bash
# Tests for agyr and agy-run. Uses fake tokens and a fake agy; never touches the real token.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ACCT="$HERE/../bin/agyr"
RUN="$HERE/../bin/agy-run"
TASK="$HERE/../bin/agy-task"
FAKE_TASK_RUN="$HERE/fake-agy-run"
export AGY_BIN="$HERE/fake-agy"
export AGY_ACCT="$ACCT"
export AGY_RUN_POLL=0.1
export FAKE_KEYRING=1 # emulate agy >= 1.2.14: it ignores the token file unless the keyring is unreachable
# Safety: this suite never touches a real login. The file backend is forced (agyr would pick wincred on Windows) and the
# credential helper is the fake one. FAKE_CRED_FILE stays unset except inside a test's own temp dir, so a stray call to
# the helper fails loudly instead of doing anything.
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) ON_WINDOWS=1 ;; *) ON_WINDOWS=0 ;; esac
export AGYR_BACKEND=file AGYR_CRED_HELPER="$HERE/fake-cred" AGY_CRED_TARGET="agyr-test:never-real"
unset FAKE_CRED_FILE
# a native Windows jq.exe prints CRLF; -b keeps the assertions below honest
if jq -b -n . >/dev/null 2>&1; then jq() { command jq -b "$@"; }; fi

export TZ=UTC-7 # same timezone as agyr, so the fake log lines line up
REAL_TOKEN="$HOME/.gemini/antigravity-cli/antigravity-oauth-token"
REAL_MTIME_BEFORE="$(stat -c %Y "$REAL_TOKEN" 2>/dev/null || echo none)"
# real agy / agy-run processes (not fake-agy) rewrite the real token file themselves (account switches, token refresh)
real_agy_busy() { pgrep -x agy >/dev/null 2>&1 || pgrep -x agy-run >/dev/null 2>&1; }
REAL_BUSY=0; real_agy_busy && REAL_BUSY=1

PASS=0 FAIL=0
pass() { PASS=$((PASS + 1)); echo "  ok   $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL $1"; [ $# -gt 1 ] && echo "       $2"; }
eq() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "expected '$2', got '$3'"; fi; }
has() { if grep -qF -- "$2" <<<"$3"; then pass "$1"; else fail "$1" "'$2' not found in: $3"; fi; }
hasnt() { if grep -qF -- "$2" <<<"$3"; then fail "$1" "must not contain '$2' in: $3"; else pass "$1"; fi; }

TMPS=()
cleanup() { for d in "${TMPS[@]}"; do rm -rf "$d"; done; }
trap cleanup EXIT

# 3-account pool; acc1 is active, token = tok-acc1
setup() {
  T="$(mktemp -d)"; TMPS+=("$T")
  export AGY_HOME="$T/home"; mkdir -p "$AGY_HOME"
  export AGY_NOW=1000000
  export FAKE_ARGS_LOG="$T/args.log"; : >"$FAKE_ARGS_LOG"
  unset FAKE_QUOTA_TOKENS FAKE_AUTH FAKE_RESET AGY_RUN_MAX_SWITCH
  local a
  for a in acc1 acc2 acc3; do
    echo "tok-$a" >"$AGY_HOME/antigravity-oauth-token"
    "$ACCT" save "$a" >/dev/null
  done
  "$ACCT" use acc1 >/dev/null
  echo "do the thing" >"$T/prompt.txt"
  mkdir -p "$T/work"
}
# JSON token shaped like the real one (compared by refresh_token): jtok <name> <access_token>
jtok() { printf '{"token":{"access_token":"%s","refresh_token":"rt-%s"}}\n' "$2" "$1"; }
cd_of() { jq -r --arg n "$1" '.cooldown[$n] // 0' "$AGY_HOME/accounts/state.json"; }
runit() { "$RUN" --prompt "$T/prompt.txt" --add-dir "$T/work" --log "$T/run.jsonl" 2>"$T/run.err"; }
lines() { wc -l <"$FAKE_ARGS_LOG" | tr -d ' '; }

echo "== agyr"

setup
out="$("$ACCT" list -c)"
has "list -c: acc1 is active" "* acc1" "$out"
has "list -c: acc2 is listed" "  acc2" "$out"
eq "active = acc1" "acc1" "$("$ACCT" active)"
if [ "$ON_WINDOWS" = 1 ]; then
  echo "  skip file modes 600/700: NTFS has no POSIX permission bits (the profile folder's ACL protects the files)"
else
  eq "slot mode is 600" "600" "$(stat -c %a "$AGY_HOME/accounts/acc1.token")"
  eq "accounts dir mode is 700" "700" "$(stat -c %a "$AGY_HOME/accounts")"
fi
eq "token is correct after use" "tok-acc1" "$(cat "$AGY_HOME/antigravity-oauth-token")"

out="$("$ACCT" save acc9 2>&1)"; hasnt "save does not print the token" "tok-" "$out"
"$ACCT" use acc1 >/dev/null

setup
for a in acc1 acc2 acc3; do jtok "$a" "at-$a" >"$AGY_HOME/antigravity-oauth-token"; "$ACCT" save "$a" >/dev/null; done
"$ACCT" use acc1 >/dev/null
jtok acc1 "at-acc1-refreshed" >"$AGY_HOME/antigravity-oauth-token" # agy refreshed the access token itself (refresh_token unchanged)
out="$("$ACCT" use acc2 2>&1)"
hasnt "use does not print the token" "at-acc" "$out"
eq "use: token = slot acc2" "at-acc2" "$(jq -r .token.access_token "$AGY_HOME/antigravity-oauth-token")"
eq "use: refreshed token synced back to acc1" "at-acc1-refreshed" "$(jq -r .token.access_token "$AGY_HOME/accounts/acc1.token")"
eq "use: token backed up before overwrite" "at-acc1-refreshed" "$(jq -r .token.access_token "$AGY_HOME/accounts/.last-token.bak")"
eq "use: active = acc2" "acc2" "$("$ACCT" active)"

"$ACCT" use nope >/dev/null 2>&1; eq "use of a missing slot -> error" "1" "$?"
"$ACCT" use '../x' >/dev/null 2>&1; eq "invalid account name -> error" "1" "$?"
"$ACCT" bogus >/dev/null 2>&1; eq "unknown command -> exit 2" "2" "$?"

echo "== cooldown / next"
setup
"$ACCT" cooldown acc1 "Resets in 4h13m27s" >/dev/null
eq "parse 4h13m27s" "$((1000000 + 15207))" "$(cd_of acc1)"
"$ACCT" cooldown acc1 "43m29s" >/dev/null;  eq "parse 43m29s" "$((1000000 + 2609))" "$(cd_of acc1)"
"$ACCT" cooldown acc1 90 >/dev/null;        eq "parse plain seconds" "$((1000000 + 90))" "$(cd_of acc1)"
"$ACCT" cooldown acc1 "1d2h" >/dev/null;    eq "parse 1d2h" "$((1000000 + 93600))" "$(cd_of acc1)"
"$ACCT" cooldown acc1 "error: Individual quota reached. Resets in 2h. (x)" >/dev/null
eq "parse a whole error sentence" "$((1000000 + 7200))" "$(cd_of acc1)"
out="$("$ACCT" cooldown acc1 "gibberish" 2>&1)"
eq "unparsable -> default 5h" "$((1000000 + 18000))" "$(cd_of acc1)"
has "warns when the duration cannot be parsed" "default 5h" "$out"
"$ACCT" clear acc1 >/dev/null; eq "clear removes the cooldown" "0" "$(cd_of acc1)"

setup
eq "next from acc1 (no cooldown) = acc2" "acc2" "$("$ACCT" next)"
"$ACCT" use acc3 >/dev/null; eq "next from acc3 wraps to acc1" "acc1" "$("$ACCT" next)"
"$ACCT" use acc1 >/dev/null
"$ACCT" cooldown acc2 2h >/dev/null
eq "next skips acc2 on cooldown" "acc3" "$("$ACCT" next)"
"$ACCT" cooldown acc3 1h >/dev/null
eq "next comes back to acc1 (active, still ready)" "acc1" "$("$ACCT" next)"
"$ACCT" cooldown acc1 3h >/dev/null
out="$("$ACCT" next 2>&1)"; rc=$?
eq "whole pool on cooldown -> exit 3" "3" "$rc"
has "reports the earliest-resetting account" "'acc3'" "$out"
out="$("$ACCT" list -c)"
has "list -c shows cooldown" "cooldown" "$out"
AGY_NOW=$((1000000 + 3601)) ; export AGY_NOW
eq "acc3's cooldown is over after 1h" "acc3" "$("$ACCT" next)"
AGY_NOW=1000000; export AGY_NOW

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
  eq "no fake-agy process left behind" "0" "$(pgrep -fc "$HERE/fake-agy" || true)"
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

# a resumed conversation echoes the OLD quota error in its final result event (no plain-text 429 lines): not a new 429
setup
export FAKE_STALE_ERROR=1
runit; rc=$?
eq "stale quota error in the result event: no account switch (runs once)" "1" "$(lines)"
eq "stale quota error: acc1 gets no cooldown" "0" "$(cd_of acc1)"
eq "stale quota error: the active account is unchanged" "acc1" "$("$ACCT" active)"
eq "stale quota error: exit 1 (status ERROR, not a quota stop)" "1" "$rc"
has "stale quota error: says why it did not switch" "no new 429 line" "$(cat "$T/run.err")"
has "stale quota error: shows the result error" "result error: Individual quota reached" "$(cat "$T/run.err")"
unset FAKE_STALE_ERROR

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

echo "== rotate (using agy by hand)"
# make a log line shaped like agy's: E<MMDD> <HH:MM:SS.uuuuuu> ... Resets in X.   ($1 = seconds before "now", $2 = Resets in)
logline() {
  printf 'E%s.123456  1 errorreport.go:224] generating and executing: RESOURCE_EXHAUSTED (code 429): Individual quota reached. Please upgrade your subscription to increase your limits. Resets in %s.\n' \
    "$(date -d "@$((AGY_NOW - $1))" '+%m%d %H:%M:%S')" "$2"
}

setup
mkdir -p "$AGY_HOME/log"; logline 120 "3h13m51s" >"$AGY_HOME/log/cli-20261001_100000.log"
out="$("$ACCT" rotate 2>&1)"; rc=$?
eq "rotate: exit 0" "0" "$rc"
has "rotate: says it read the agy log" "read from the agy log" "$out"
eq "rotate: acc1 cooldown = log time + Resets in" "$((1000000 - 120 + 11631))" "$(cd_of acc1)"
eq "rotate: switches to acc2" "acc2" "$("$ACCT" active)"
eq "rotate: token = acc2" "tok-acc2" "$(cat "$AGY_HOME/antigravity-oauth-token")"
has "rotate: tells you to reopen with agyr -c" "agyr -c" "$out"
hasnt "rotate: does not print the token" "tok-" "$out"

setup
mkdir -p "$AGY_HOME/log"; logline 120 "3h13m51s" >"$AGY_HOME/log/cli-20261001_100000.log"
"$ACCT" rotate 1h >/dev/null 2>&1
eq "rotate: a manually given duration overrides the log" "$((1000000 + 3600))" "$(cd_of acc1)"

setup
mkdir -p "$AGY_HOME/log"; logline 7200 "3h13m51s" >"$AGY_HOME/log/cli-20261001_100000.log"
out="$("$ACCT" rotate 2>&1)"
eq "rotate: a log line older than 1h is ignored, uses 5h" "$((1000000 + 18000))" "$(cd_of acc1)"
has "rotate: says it uses the default 5h" "default 5h" "$out"

setup
mkdir -p "$AGY_HOME/log"
logline 600 "4h13m19s" >"$AGY_HOME/log/cli-20261001_100000.log"
logline 60 "43m29s" >"$AGY_HOME/log/cli-20261001_110000.log"
touch -d '2 minutes ago' "$AGY_HOME/log/cli-20261001_100000.log"
"$ACCT" rotate >/dev/null 2>&1
eq "rotate: takes the newest line across logs" "$((1000000 - 60 + 2609))" "$(cd_of acc1)"

setup
"$ACCT" rotate >/dev/null 2>&1
eq "rotate: no log directory -> default 5h" "$((1000000 + 18000))" "$(cd_of acc1)"

setup
mkdir -p "$AGY_HOME/log"; : >"$AGY_HOME/log/cli-20261001_100000.log"
"$ACCT" cooldown acc2 3h >/dev/null; "$ACCT" cooldown acc3 2h >/dev/null
out="$("$ACCT" rotate 1h 2>&1)"; rc=$?
eq "rotate: whole pool on cooldown -> exit 3" "3" "$rc"
eq "rotate: whole pool on cooldown still records the current account's cooldown" "$((1000000 + 3600))" "$(cd_of acc1)"
eq "rotate: whole pool on cooldown does not switch the token" "tok-acc1" "$(cat "$AGY_HOME/antigravity-oauth-token")"
"$ACCT" rotate xyz >/dev/null 2>&1; eq "rotate: invalid duration -> error" "1" "$?"

setup
rm -f "$AGY_HOME/accounts/state.json" "$AGY_HOME/antigravity-oauth-token"
"$ACCT" rotate >/dev/null 2>&1; eq "rotate: no active account -> error" "1" "$?"

echo "== list (measures real quota)"
setup
out="$("$ACCT" list 2>&1)"; rc=$?
eq "list: exit 0" "0" "$rc"
has "list: has the table header" "ACCOUNT" "$out"
has "list: * marks the selected account" "* acc1" "$out"
has "list: other accounts have no *" "  acc2" "$out"
has "list: acc1 5h = 60%" " 60%" "$out"
has "list: acc2 5h = 70%" " 70%" "$out"
has "list: acc3 5h = 80%" " 80%" "$out"
has "list: has the reset-time column" "12/01/1970 09:46 PM" "$out"
has "list: has the 'Measured at' line" "Measured at 12/01/1970 08:46 PM" "$out"
hasnt "list: no Claude/GPT lines" "Claude" "$out"
hasnt "list: does not print the token" "tok-" "$out"
eq "list: stores the acc1 snapshot g5=60" "60" "$(jq -r '.quota.acc1.g5' "$AGY_HOME/accounts/state.json")"
eq "list: stores the acc3 snapshot gw=70" "70" "$(jq -r '.quota.acc3.gw' "$AGY_HOME/accounts/state.json")"
eq "list: does not change the active account" "acc1" "$("$ACCT" active)"
eq "list: the real token file is not changed (still acc1)" "tok-acc1" "$(cat "$AGY_HOME/antigravity-oauth-token")"
seen="$(cut -d'|' -f1 "$FAKE_ARGS_LOG" | sort | tr '\n' ' ')"
eq "list: agy ran with each slot's own token" "tok-acc1 tok-acc2 tok-acc3 " "$seen"
mkdir -p "$T/tmp"; TMPDIR="$T/tmp" "$ACCT" list >/dev/null 2>&1
eq "list: no temp HOME (holding a token copy) left behind" "0" "$(ls -A "$T/tmp" | wc -l | tr -d ' ')"

# the active account is measured with the real token file (it may be newer than the slot)
setup
for a in acc1 acc2 acc3; do jtok "$a" "at-$a" >"$AGY_HOME/antigravity-oauth-token"; "$ACCT" save "$a" >/dev/null; done
"$ACCT" use acc1 >/dev/null
jtok acc1 "at-acc1-live" >"$AGY_HOME/antigravity-oauth-token" # access token newer than the slot's, same refresh_token
"$ACCT" list >/dev/null 2>&1
has "list: the active account is measured with the real token file (newer than the slot)" "at-acc1-live" "$(cat "$FAKE_ARGS_LOG")"
eq "list: the real token file is left intact" "at-acc1-live" "$(jq -r .token.access_token "$AGY_HOME/antigravity-oauth-token")"

# list -c does not call agy
setup
"$ACCT" list >/dev/null 2>&1
before="$(wc -l <"$FAKE_ARGS_LOG" | tr -d ' ')"
out="$("$ACCT" list -c 2>&1)"; rc=$?
eq "list -c: exit 0" "0" "$rc"
eq "list -c: does not call agy" "$before" "$(wc -l <"$FAKE_ARGS_LOG" | tr -d ' ')"
has "list -c: still shows the saved data" " 70%" "$out"
has "list -c: suggests measuring again" "Oldest data measured at 12/01/1970 08:46 PM" "$out"
AGY_NOW=$((1000000 + 4000)); export AGY_NOW
out="$("$ACCT" list -c 2>&1)"
has "list -c: past the 5h reset time it says the data is stale" "stale, past reset time" "$out"
AGY_NOW=1000000; export AGY_NOW
setup
out="$("$ACCT" list -c 2>&1)"
has "list -c when nothing was ever measured" "No quota data yet" "$out"
has "list -c: status 'not measured'" "not measured" "$out"
"$ACCT" list --bogus >/dev/null 2>&1; eq "list: unknown argument -> exit 2" "2" "$?"
"$ACCT" quota >/dev/null 2>&1; eq "the quota command is gone -> exit 2" "2" "$?"

# out of 5h quota -> automatic cooldown, and next skips it
setup
export FAKE_ZERO_TOKENS="tok-acc2"
out="$("$ACCT" list 2>&1)"
has "list: 0% -> cooldown status" "cooldown, 1h00m left" "$out"
eq "list: 0% -> acc2 cooldown = 5h reset time" "$((1000000 + 3600))" "$(cd_of acc2)"
eq "list: acc1 is not on cooldown" "0" "$(cd_of acc1)"
eq "next skips acc2 (0% quota)" "acc3" "$("$ACCT" next)"
unset FAKE_ZERO_TOKENS

# real quota left -> clear a default cooldown that was set earlier
setup
"$ACCT" cooldown acc2 5h >/dev/null
out="$("$ACCT" list 2>&1)"
eq "list: measured quota left -> old cooldown cleared" "0" "$(cd_of acc2)"
hasnt "list: no cooldown status left" "cooldown" "$out"

# low
setup
export FAKE_LOW_TOKENS="tok-acc3"
out="$("$ACCT" list 2>&1)"
has "list: under 10% -> 'low'" "low" "$out"
unset FAKE_LOW_TOKENS

# dead account
setup
export FAKE_DEAD_TOKENS="tok-acc2"
out="$("$ACCT" list 2>&1)"; rc=$?
eq "list: one dead account -> exit 1" "1" "$rc"
has "list: reports measure failed" "measure failed" "$out"
eq "list: the other accounts are still measured (acc3 g5=80)" "80" "$(jq -r '.quota.acc3.g5' "$AGY_HOME/accounts/state.json")"
eq "list: the dead account has no snapshot" "null" "$(jq -r '.quota.acc2.g5' "$AGY_HOME/accounts/state.json")"
eq "list: the real token is still acc1" "tok-acc1" "$(cat "$AGY_HOME/antigravity-oauth-token")"
unset FAKE_DEAD_TOKENS

# agy refreshes the token in the temp HOME (a real login is JSON: the account is its refresh_token, which a refresh keeps)
setup
for a in acc1 acc2 acc3; do jtok "$a" "at-$a" >"$AGY_HOME/antigravity-oauth-token"; "$ACCT" save "$a" >/dev/null; done
"$ACCT" use acc1 >/dev/null
export FAKE_REFRESH=1
"$ACCT" list >/dev/null 2>&1
eq "refresh: a non-active slot gets the new access token written back" "at-acc2-refreshed" "$(jq -r .token.access_token "$AGY_HOME/accounts/acc2.token")"
eq "refresh: ... and keeps its own refresh token" "rt-acc2" "$(jq -r .token.refresh_token "$AGY_HOME/accounts/acc2.token")"
eq "refresh: same for slot acc3" "at-acc3-refreshed" "$(jq -r .token.access_token "$AGY_HOME/accounts/acc3.token")"
eq "refresh: the active account's slot is not overwritten" "at-acc1" "$(jq -r .token.access_token "$AGY_HOME/accounts/acc1.token")"
eq "refresh: the real token file is not overwritten" "at-acc1" "$(jq -r .token.access_token "$AGY_HOME/antigravity-oauth-token")"
unset FAKE_REFRESH

# agy leaves ANOTHER account's login in the temp HOME (the 2026-10-09 symptom: acc7's slot ended up with acc6's login):
# the slot must keep its own login
setup
for a in acc1 acc2 acc3; do jtok "$a" "at-$a" >"$AGY_HOME/antigravity-oauth-token"; "$ACCT" save "$a" >/dev/null; done
"$ACCT" use acc1 >/dev/null
export FAKE_CROSSTALK_TOKENS='{"token":{"access_token":"at-acc2","refresh_token":"rt-acc2"}}'
"$ACCT" list >/dev/null 2>&1
eq "crosstalk: a measurement that leaves a foreign login does not replace the slot (acc2)" "rt-acc2" "$(jq -r .token.refresh_token "$AGY_HOME/accounts/acc2.token")"
eq "crosstalk: no slot holds the intruder's login" "0" "$(grep -l 'rt-intruder' "$AGY_HOME"/accounts/*.token 2>/dev/null | wc -l | tr -d ' ')"
unset FAKE_CROSSTALK_TOKENS

# no agy -> print the saved data
setup
"$ACCT" list >/dev/null 2>&1
out="$(AGY_BIN=/nonexistent/agy "$ACCT" list 2>&1)"; rc=$?
eq "list: no agy -> still exit 0" "0" "$rc"
has "list: no agy -> warning" "agy not found" "$out"
has "list: no agy -> still shows the saved data" " 70%" "$out"

# no accounts yet
setup
rm -rf "$AGY_HOME/accounts"
out="$("$ACCT" list 2>&1)"; rc=$?
eq "list: no accounts -> exit 0" "0" "$rc"
has "list: no accounts -> instructions" "no accounts yet" "$out"

echo "== terminal"
if command -v script >/dev/null; then
  setup
  export FAKE_TTY=1
  cat >"$T/tty.sh" <<EOS
snap() { stty -a | grep -oE -- '(^|[ ])-?(onlcr|icanon|echo)([ ;]|\$)' | tr -d ' ;' | tr '\n' ' '; }
a="\$(snap)"
"$ACCT" list >/dev/null 2>&1
b="\$(snap)"
[ -n "\$a" ] && [ "\$a" = "\$b" ] && echo SAME || echo "DIFF: [\$a] -> [\$b]"
EOS
  out="$(script -qec "bash $T/tty.sh" /dev/null 2>&1 | tr -d '\r' | tail -n 1)"
  eq "list: leaves the terminal settings unchanged (parallel agy does not touch the tty)" "SAME" "$out"
  unset FAKE_TTY
else
  echo "  (skipped: no 'script' command)"
fi

echo "== colour"
ESC=$'\033'
GREEN="${ESC}[32m"; YELLOW="${ESC}[33m"; RED="${ESC}[31m"
strip() { sed "s/${ESC}\[[0-9;]*m//g"; }
setup
"$ACCT" list >/dev/null 2>&1
out="$("$ACCT" list -c)"
hasnt "not on a terminal -> no colour codes" "$ESC" "$out"
plain="$out"
out="$(AGYR_COLOR=always "$ACCT" list -c)"
has "always: >40% -> green" "${GREEN} 60%" "$out"
has "always: the ready status is green" "${GREEN}ready" "$out"
eq "always: with the colour codes stripped it equals the plain output (alignment intact)" "$plain" "$(strip <<<"$out")"
out="$(AGYR_COLOR=never NO_COLOR= "$ACCT" list -c)"
hasnt "never: no colour codes" "$ESC" "$out"

setup
FAKE_P5=30 "$ACCT" list >/dev/null 2>&1
out="$(AGYR_COLOR=always "$ACCT" list -c)"
has "always: 11-40% -> yellow" "${YELLOW} 30%" "$out"
setup
FAKE_P5=5 "$ACCT" list >/dev/null 2>&1
out="$(AGYR_COLOR=always "$ACCT" list -c)"
has "always: <=10% -> red" "${RED}  5%" "$out"
has "always: 'low' is red" "${RED}low" "$out"
setup
FAKE_P5=0 "$ACCT" list >/dev/null 2>&1
out="$(AGYR_COLOR=always "$ACCT" list -c)"
has "always: 0% -> red" "${RED}  0%" "$out"
has "always: cooldown is red" "${RED}cooldown" "$out"
setup
out="$(AGYR_COLOR=always "$ACCT" list -c)"
has "always: 'not measured' is yellow" "${YELLOW}not measured" "$out"
setup
export FAKE_DEAD_TOKENS="tok-acc2"
out="$(AGYR_COLOR=always "$ACCT" list 2>&1)"
has "always: 'measure failed' is red" "${RED}measure failed" "$out"
unset FAKE_DEAD_TOKENS

if command -v script >/dev/null; then
  setup
  "$ACCT" list >/dev/null 2>&1
  out="$(script -qec "$ACCT list -c" /dev/null 2>&1)"
  has "on a terminal (auto) -> coloured" "${GREEN}" "$out"
  out="$(NO_COLOR=1 script -qec "$ACCT list -c" /dev/null 2>&1)"
  hasnt "NO_COLOR -> colour off even on a terminal" "$ESC[3" "$out"
  out="$(AGYR_COLOR=never script -qec "$ACCT list -c" /dev/null 2>&1)"
  hasnt "AGYR_COLOR=never -> colour off even on a terminal" "$ESC[3" "$out"
fi

echo "== real token file out of sync with state (manual login without save)"
mk3() { # 3 JSON-token slots, active = acc1
  setup
  for a in acc1 acc2 acc3; do jtok "$a" "at-$a" >"$AGY_HOME/antigravity-oauth-token"; "$ACCT" save "$a" >/dev/null; done
  "$ACCT" use acc1 >/dev/null
}
# you log in by hand as acc2 (saved earlier, refresh_token matches slot acc2) but state still says acc1
mk3
jtok acc2 "at-acc2-newer" >"$AGY_HOME/antigravity-oauth-token"
eq "active is derived from the real token file (acc2), not from state (acc1)" "acc2" "$("$ACCT" active)"
eq "state still says acc1 (kept only as a fallback)" "acc1" "$(jq -r .active "$AGY_HOME/accounts/state.json")"
out="$("$ACCT" list 2>&1)"
has "list: * is on acc2 (the real owner of the token file)" "* acc2" "$out"
hasnt "list: acc1 no longer has *" "* acc1" "$out"
has "list: acc2 is measured with the real token (newer than its slot)" "at-acc2-newer" "$(cat "$FAKE_ARGS_LOG")"
has "list: acc1 is measured with its own slot" '"access_token":"at-acc1"' "$(cat "$FAKE_ARGS_LOG")"
eq "list: acc1 measures 60% (not mixed up with acc2's numbers)" "60" "$(jq -r .quota.acc1.g5 "$AGY_HOME/accounts/state.json")"
eq "list: acc2 measures 70%" "70" "$(jq -r .quota.acc2.g5 "$AGY_HOME/accounts/state.json")"
"$ACCT" use acc3 >/dev/null
eq "use: acc2's fresh token is written back to slot acc2" "at-acc2-newer" "$(jq -r .token.access_token "$AGY_HOME/accounts/acc2.token")"
eq "use: slot acc1 is NOT overwritten with acc2's token" "at-acc1" "$(jq -r .token.access_token "$AGY_HOME/accounts/acc1.token")"
eq "use: slot acc1 still has acc1's refresh_token" "rt-acc1" "$(jq -r .token.refresh_token "$AGY_HOME/accounts/acc1.token")"

# log in to an account that was never saved: matches no slot
mk3
jtok brandnew "at-new" >"$AGY_HOME/antigravity-oauth-token"
out="$("$ACCT" list 2>&1)"
hasnt "list: no * when the token matches no slot" "* acc" "$out"
has "list: warns that the token matches no slot" "matches no slot" "$out"
"$ACCT" use acc2 >/dev/null
eq "use: an unknown token does not overwrite slot acc1" "at-acc1" "$(jq -r .token.access_token "$AGY_HOME/accounts/acc1.token")"
eq "use: an unknown token does not overwrite slot acc2 (it keeps its own)" "rt-acc2" "$(jq -r .token.refresh_token "$AGY_HOME/accounts/acc2.token")"
eq "use: the unknown token is kept in .last-token.bak" "at-new" "$(jq -r .token.access_token "$AGY_HOME/accounts/.last-token.bak")"

echo "== UTC+7 timezone"
setup
# AGY_NOW=1000000 = 1970-01-12 13:46:40 UTC; +1h = 14:46 UTC = 21:46 in UTC+7 = 09:46 PM
out="$(TZ=UTC "$ACCT" cooldown acc1 1h)"
has "times are always UTC+7 even when TZ in the environment is UTC" "12/01/1970 09:46 PM" "$out"
out="$(TZ=America/New_York "$ACCT" list)"
has "list is also UTC+7 when TZ in the environment differs" "12/01/1970 09:46 PM" "$out"
has "list: the measured-at time is UTC+7 (jq/date)" "Measured at 12/01/1970 08:46 PM" "$out"
out="$(TZ=UTC AGY_TZ=UTC "$ACCT" cooldown acc1 1h)"
has "AGY_TZ changes the displayed timezone" "12/01/1970 02:46 PM" "$out"
out="$("$ACCT" cooldown acc1 10h)"
has "dd/mm/yyyy hh:mm AM format (morning, next day)" "13/01/1970 06:46 AM" "$out"
out="$(LC_ALL=C LC_TIME=de_DE.UTF-8 "$ACCT" cooldown acc1 1h)"
has "AM/PM does not depend on the machine's locale" "09:46 PM" "$out"

echo "== rename"
setup
"$ACCT" list >/dev/null 2>&1   # saves quota snapshots (and, measuring real quota, clears cooldowns)
"$ACCT" cooldown acc2 2h >/dev/null
n0="$(lines)"
tok2="$(cat "$AGY_HOME/accounts/acc2.token")"
out="$("$ACCT" rename acc2 renamed 2>&1)"; rc=$?
eq "rename: exit 0" "0" "$rc"
has "rename: confirms" "renamed slot 'acc2' to 'renamed'" "$out"
eq "rename: the old slot file is gone" "no" "$([ -e "$AGY_HOME/accounts/acc2.token" ] && echo yes || echo no)"
eq "rename: the login moved to the new slot unchanged" "$tok2" "$(cat "$AGY_HOME/accounts/renamed.token")"
eq "rename: the new slot is mode 600" "600" "$(stat -c %a "$AGY_HOME/accounts/renamed.token")"
eq "rename: the cooldown moved" "$((1000000 + 7200))" "$(cd_of renamed)"
eq "rename: the old name has no cooldown left" "0" "$(cd_of acc2)"
eq "rename: the quota snapshot moved" "70" "$(jq -r '.quota.renamed.g5' "$AGY_HOME/accounts/state.json")"
eq "rename: the old name has no quota snapshot left" "null" "$(jq -r '.quota.acc2.g5' "$AGY_HOME/accounts/state.json")"
eq "rename: other slots are untouched (acc1 still has its login)" "tok-acc1" "$(cat "$AGY_HOME/accounts/acc1.token")"
eq "rename: other slots keep their quota snapshot" "60" "$(jq -r '.quota.acc1.g5' "$AGY_HOME/accounts/state.json")"
eq "rename: the real token file is untouched" "tok-acc1" "$(cat "$AGY_HOME/antigravity-oauth-token")"
eq "rename: agy is not started" "$n0" "$(lines)"
out="$("$ACCT" list -c)"
has "rename: list shows the new name" "renamed" "$out"
hasnt "rename: list no longer shows the old name" "acc2 " "$out"
eq "rename: 'use' works with the new name" "switched to account 'renamed'" "$("$ACCT" use renamed)"
eq "rename: active follows the login" "renamed" "$("$ACCT" active)"

# renaming the active account moves the "active" mark
setup
"$ACCT" rename acc1 main >/dev/null
eq "rename: the active account keeps being active under its new name" "main" "$("$ACCT" active)"
eq "rename: state.active follows" "main" "$(jq -r .active "$AGY_HOME/accounts/state.json")"

# refusals change nothing
setup
before="$(ls "$AGY_HOME/accounts" | tr '\n' ' ')"; state_before="$(cat "$AGY_HOME/accounts/state.json")"
out="$("$ACCT" rename acc2 acc3 2>&1)"; rc=$?
eq "rename onto an existing slot -> exit 1" "1" "$rc"
has "rename onto an existing slot: says so" "already exists" "$out"
eq "rename onto an existing slot: acc3 keeps its own login" "tok-acc3" "$(cat "$AGY_HOME/accounts/acc3.token")"
eq "rename onto an existing slot: acc2 keeps its login" "tok-acc2" "$(cat "$AGY_HOME/accounts/acc2.token")"
"$ACCT" rename nope other >/dev/null 2>&1; eq "rename of a missing slot -> exit 1" "1" "$?"
out="$("$ACCT" rename acc1 acc1 2>&1)"; rc=$?
eq "rename to the same name -> exit 1" "1" "$rc"
has "rename to the same name: says so" "same" "$out"
"$ACCT" rename acc1 '../x' >/dev/null 2>&1; eq "rename to an invalid name -> exit 1" "1" "$?"
"$ACCT" rename '../x' acc9 >/dev/null 2>&1; eq "rename from an invalid name -> exit 1" "1" "$?"
"$ACCT" rename acc1 >/dev/null 2>&1; eq "rename with one argument -> exit 1" "1" "$?"
out="$("$ACCT" rename 2>&1)"; rc=$?
eq "rename without arguments -> exit 1" "1" "$rc"
has "rename without arguments: usage" "usage: agyr rename <old> <new>" "$out"
eq "refusals leave every slot file as it was" "$before" "$(ls "$AGY_HOME/accounts" | tr '\n' ' ')"
eq "refusals leave state.json as it was" "$state_before" "$(cat "$AGY_HOME/accounts/state.json")"
# --help has no side effects
"$ACCT" rename --help >/dev/null 2>&1
eq "rename --help does not rename anything" "$before" "$(ls "$AGY_HOME/accounts" | tr '\n' ' ')"
out="$("$ACCT" help rename)"
has "help rename: usage line" "Usage: agyr rename <old> <new>" "$out"
has "help rename: mentions that it refuses an existing name" "already exists" "$out"

echo "== forget (what the file/wincred sections above do not cover)"
setup
n0="$(lines)"
out="$("$ACCT" forget 2>&1)"
has "forget: tells to log in with agyr (a bare agy would use the keyring)" "run 'agyr' to log in" "$out"
eq "forget: the active mark is cleared" "" "$(jq -r .active "$AGY_HOME/accounts/state.json")"
eq "forget: 'agyr active' prints nothing" "" "$("$ACCT" active)"
for a in acc1 acc2 acc3; do eq "forget: slot $a is kept" "tok-$a" "$(cat "$AGY_HOME/accounts/$a.token")"; done
eq "forget: agy is not started" "$n0" "$(lines)"
out="$("$ACCT" list -c 2>&1)"; rc=$?
eq "forget: list -c still works" "0" "$rc"
hasnt "forget: nothing is marked * (no login)" "* acc" "$out"
runit; rc=$?
eq "forget: agy-run refuses to start without a login (exit 4)" "4" "$rc"
eq "forget: agy-run did not start agy" "$n0" "$(lines)"
"$ACCT" use acc2 >/dev/null
eq "forget: 'use' logs in again from a slot" "tok-acc2" "$(cat "$AGY_HOME/antigravity-oauth-token")"
eq "forget: and active is acc2 again" "acc2" "$("$ACCT" active)"

# -f is accepted like --force
setup
for a in acc1 acc2 acc3; do jtok "$a" "at-$a" >"$AGY_HOME/antigravity-oauth-token"; "$ACCT" save "$a" >/dev/null; done
jtok brandnew "at-new" >"$AGY_HOME/antigravity-oauth-token"
"$ACCT" forget >/dev/null 2>&1; eq "forget: an unsaved login is refused (exit 1)" "1" "$?"
eq "forget: the unsaved login is still there after the refusal" "at-new" "$(jq -r .token.access_token "$AGY_HOME/antigravity-oauth-token")"
"$ACCT" forget -f >/dev/null 2>&1; eq "forget -f: accepted like --force (exit 0)" "0" "$?"
eq "forget -f: the token file is gone" "no" "$([ -e "$AGY_HOME/antigravity-oauth-token" ] && echo yes || echo no)"
eq "forget -f: a copy of the dropped login is in .last-token.bak" "at-new" "$(jq -r .token.access_token "$AGY_HOME/accounts/.last-token.bak")"
eq "forget -f: no slot was overwritten" "rt-acc1" "$(jq -r .token.refresh_token "$AGY_HOME/accounts/acc1.token")"

# no login at all still clears the active mark
setup
rm -f "$AGY_HOME/antigravity-oauth-token"
"$ACCT" forget >/dev/null 2>&1; eq "forget without a login: exit 0" "0" "$?"

# usage, help and side effects
setup
out="$("$ACCT" forget extra 2>&1)"; rc=$?
eq "forget with an extra argument -> exit 2" "2" "$rc"
has "forget with an extra argument: usage" "usage: agyr forget [-f|--force]" "$out"
eq "forget with an extra argument: token file untouched" "tok-acc1" "$(cat "$AGY_HOME/antigravity-oauth-token")"
"$ACCT" forget --help >/dev/null 2>&1
eq "forget --help does not forget anything" "tok-acc1" "$(cat "$AGY_HOME/antigravity-oauth-token")"
out="$("$ACCT" help forget)"
has "help forget: mentions -f" "-f / --force" "$out"
has "help forget: says to log in with agyr, not a bare agy" "not a bare 'agy'" "$out"
has "help forget: mentions the active mark" "\"active\" mark" "$out"

echo "== agy-run: up to 10 account switches by default"
mk12() { # 12 accounts a01..a12, a01 in use
  T="$(mktemp -d)"; TMPS+=("$T")
  export AGY_HOME="$T/home"; mkdir -p "$AGY_HOME"
  export AGY_NOW=1000000
  export FAKE_ARGS_LOG="$T/args.log"; : >"$FAKE_ARGS_LOG"
  unset FAKE_QUOTA_TOKENS FAKE_AUTH FAKE_RESET AGY_RUN_MAX_SWITCH FAKE_REFRESH FAKE_WEEK_ORDER
  local i a
  for i in 01 02 03 04 05 06 07 08 09 10 11 12; do
    a="a$i"; echo "tok-$a" >"$AGY_HOME/antigravity-oauth-token"; "$ACCT" save "$a" >/dev/null
  done
  "$ACCT" use a01 >/dev/null
  echo "do the thing" >"$T/prompt.txt"; mkdir -p "$T/work"
}
mk12
export FAKE_QUOTA_TOKENS="tok-a01 tok-a02 tok-a03 tok-a04 tok-a05 tok-a06 tok-a07 tok-a08 tok-a09 tok-a10"
runit; rc=$?
eq "10 exhausted accounts -> 10 switches are allowed by default, the 11th account answers (exit 0)" "0" "$rc"
eq "that took 11 runs" "11" "$(lines)"
has "the last run used a11" "tok-a11|" "$(tail -1 "$FAKE_ARGS_LOG")"
mk12
export FAKE_QUOTA_TOKENS="tok-a01 tok-a02 tok-a03 tok-a04 tok-a05 tok-a06 tok-a07 tok-a08 tok-a09 tok-a10 tok-a11"
runit; rc=$?
eq "11 exhausted accounts -> the 11th switch is refused (exit 6)" "6" "$rc"
has "the message names the limit" "switched accounts 10 times" "$(cat "$T/run.err")"
unset FAKE_QUOTA_TOKENS
has "agy-run --help: documents the default of 10" "AGY_RUN_MAX_SWITCH (default 10)" "$("$RUN" --help 2>&1)"
mk12; export FAKE_QUOTA_TOKENS="tok-a01 tok-a02 tok-a03" AGY_RUN_MAX_SWITCH=2
runit; rc=$?
eq "AGY_RUN_MAX_SWITCH still overrides the default (2 -> exit 6)" "6" "$rc"
unset FAKE_QUOTA_TOKENS AGY_RUN_MAX_SWITCH

echo "== concurrency: many agyr / agy-run at the same time must never mix up logins (file backend)"
# the lock must be exclusive even where mkdir is not (uutils mkdir let several parallel callers all succeed)
bad=0
for r in $(seq 1 60); do
  D="$(mktemp -d)"; TMPS+=("$D")
  for i in $(seq 1 12); do ( set -o noclobber; { echo "$i" >"$D/lock"; } 2>/dev/null && echo ok >>"$D/oks" ) & done; wait
  [ "$(wc -l <"$D/oks" 2>/dev/null || echo 0)" = 1 ] || bad=$((bad + 1))
done
eq "the exclusive-create primitive used for the lock is atomic (60 rounds x 12 parallel)" "0" "$bad"
grep -q 'until mkdir' "$ACCT" && fail "agyr must not build its lock on mkdir" || pass "agyr does not build its lock on mkdir"
refresh_of() { jq -r .token.refresh_token "$AGY_HOME/accounts/$1.token"; }
mkjson() { # N slots s1..sN with JSON logins, s1 in use
  setup
  rm -f "$AGY_HOME"/accounts/*.token "$AGY_HOME/accounts/state.json"
  local i
  for i in $(seq 1 "$1"); do jtok "s$i" "at-s$i" >"$AGY_HOME/antigravity-oauth-token"; "$ACCT" save "s$i" >/dev/null; done
  "$ACCT" use s1 >/dev/null
}
bad_slots() { local i out=""; for i in $(seq 1 "$1"); do [ "$(refresh_of "s$i")" = "rt-s$i" ] || out="$out s$i"; done; echo "$out"; }
for round in 1 2 3; do
  mkjson 4
  for i in $(seq 1 40); do "$ACCT" use "s$(( (i % 4) + 1 ))" >/dev/null 2>&1 & done; wait
  eq "40 parallel 'use' (round $round): every slot still has its own login" "" "$(bad_slots 4)"
done
eq "after the parallel 'use': no temp file or lock left in the accounts dir" "0" "$(ls -A "$AGY_HOME/accounts" | grep -cE '^\.snap|^\.swap\.lock|\.tmp|^\.state\.[A-Za-z0-9]+$|^[a-z0-9]+\.token\.[A-Za-z0-9]{6}$' || true)"
eq "after the parallel 'use': the live login is one of the slots'" "1" "$(for i in 1 2 3 4; do [ "$(jq -r .token.refresh_token "$AGY_HOME/antigravity-oauth-token")" = "rt-s$i" ] && echo y; done | wc -l | tr -d ' ')"
eq "after the parallel 'use': state.json is valid JSON" "ok" "$(jq -e . "$AGY_HOME/accounts/state.json" >/dev/null 2>&1 && echo ok || echo broken)"

# 'use' while measurements run
mkjson 4
"$ACCT" list >/dev/null 2>&1
for i in $(seq 1 12); do "$ACCT" use "s$(( (i % 4) + 1 ))" >/dev/null 2>&1 & "$ACCT" list >/dev/null 2>&1 & done; wait
eq "parallel 'use' and 'list': every slot still has its own login" "" "$(bad_slots 4)"
eq "parallel 'use' and 'list': every slot measured as itself (4 snapshots, none lost)" "4" "$(jq -r '.quota | keys | length' "$AGY_HOME/accounts/state.json")"

# state.json is a read-modify-write: parallel updates must not lose each other
mk12
for i in 01 02 03 04 05 06 07 08 09 10 11 12; do "$ACCT" cooldown "a$i" 1h >/dev/null 2>&1 & done; wait
eq "12 parallel 'cooldown': none is lost" "12" "$(jq -r '.cooldown | keys | length' "$AGY_HOME/accounts/state.json")"

# the lock itself (it used to cover only the Windows backend)
setup
eq "'use' leaves no lock behind" "no" "$("$ACCT" use acc2 >/dev/null; [ -e "$AGY_HOME/accounts/.swap.lock" ] && echo yes || echo no)"
echo 999999 >"$AGY_HOME/accounts/.swap.lock" # its owner is gone
"$ACCT" use acc3 >/dev/null 2>&1; eq "a stale lock (dead owner) is cleared and 'use' works" "acc3" "$("$ACCT" active)"
echo $$ >"$AGY_HOME/accounts/.swap.lock" # its owner (this shell) is alive
start=$SECONDS
out="$(AGYR_LOCK_WAIT=1 "$ACCT" use acc1 2>&1)"; rc=$?
eq "a lock held by a live process: 'use' gives up (exit 1)" "1" "$rc"
has "... and says another agyr is switching" "another agyr is switching accounts" "$out"
[ $((SECONDS - start)) -le 5 ] && pass "... after about AGYR_LOCK_WAIT seconds" || fail "... after about AGYR_LOCK_WAIT seconds" "took $((SECONDS - start))s"
eq "... and the account in use did not change" "acc3" "$("$ACCT" active)"
rm -f "$AGY_HOME/accounts/.swap.lock"
mkdir -p "$AGY_HOME/accounts/.swap.lock"; echo 999999 >"$AGY_HOME/accounts/.swap.lock/pid" # an older agyr's lock directory, owner gone
"$ACCT" use acc2 >/dev/null 2>&1; eq "a stale lock directory left by an older agyr is cleared" "acc2" "$("$ACCT" active)"
eq "... and replaced by nothing (the lock is released)" "no" "$([ -e "$AGY_HOME/accounts/.swap.lock" ] && echo yes || echo no)"
echo $$ >"$AGY_HOME/accounts/.swap.lock" # live again for the checks below
for cmd in "save zz" "forget -f" "rename acc1 acc9" "cooldown acc1 1h"; do
  AGYR_LOCK_WAIT=1 "$ACCT" $cmd >/dev/null 2>&1; eq "a held lock also stops 'agyr $cmd' (exit 1)" "1" "$?"
done
rm -rf "$AGY_HOME/accounts/.swap.lock"

# the login is written atomically and from one copy
setup
"$ACCT" use acc2 >/dev/null
eq "after 'use': the live login is exactly the slot's" "$(cat "$AGY_HOME/accounts/acc2.token")" "$(cat "$AGY_HOME/antigravity-oauth-token")"
eq "'use' leaves no snapshot of a login in the accounts dir" "0" "$(ls -A "$AGY_HOME/accounts" | grep -c '^\.snap' || true)"
eq "the login files stay private (mode 600)" "600" "$(stat -c %a "$AGY_HOME/antigravity-oauth-token")"
eq "slot files stay private (mode 600)" "600" "$(stat -c %a "$AGY_HOME/accounts/acc1.token")"
eq "the backup stays private (mode 600)" "600" "$(stat -c %a "$AGY_HOME/accounts/.last-token.bak")"

echo "== next: the ready account whose weekly limit resets soonest (what agy-run and rotate switch to)"
setup
export FAKE_WEEK_ORDER=1 # weekly resets: acc3 first, then acc2, then acc1
"$ACCT" list >/dev/null 2>&1
eq "next from acc1: acc3 (soonest weekly reset), not acc2 (name order)" "acc3" "$("$ACCT" next)"
"$ACCT" cooldown acc3 2h >/dev/null
eq "next skips an account on cooldown even if its week resets first" "acc2" "$("$ACCT" next)"
"$ACCT" clear acc3 >/dev/null
"$ACCT" use acc3 >/dev/null
eq "next while acc3 is in use: the soonest OTHER account (acc2)" "acc2" "$("$ACCT" next)"
"$ACCT" use acc2 >/dev/null
eq "next while acc2 is in use: acc3" "acc3" "$("$ACCT" next)"
"$ACCT" use acc1 >/dev/null
"$ACCT" cooldown acc2 2h >/dev/null; "$ACCT" cooldown acc3 3h >/dev/null
eq "next: the account in use is returned when nothing else is ready" "acc1" "$("$ACCT" next)"
"$ACCT" cooldown acc1 5h >/dev/null
out="$("$ACCT" next 2>&1)"; rc=$?
eq "next: everything on cooldown -> exit 3" "3" "$rc"
has "next: names the account that resets first" "earliest: 'acc2'" "$out"

# explanation on stderr, name alone on stdout
setup
export FAKE_WEEK_ORDER=1
"$ACCT" list >/dev/null 2>&1
out="$("$ACCT" next -v 2>"$T/why.err")"
eq "next -v: stdout is only the name" "acc3" "$out"
has "next -v: says which account and why" "next account 'acc3': weekly limit resets" "$(cat "$T/why.err")"
has "next -v: says it is the soonest of the other ready accounts" "the soonest of the 2 other ready account(s)" "$(cat "$T/why.err")"
"$ACCT" cooldown acc2 2h >/dev/null; "$ACCT" cooldown acc3 2h >/dev/null
"$ACCT" next -v 2>&1 >/dev/null | grep -q "no other account is ready" && pass "next -v: says the one in use stays when nothing else is ready" || fail "next -v: says the one in use stays when nothing else is ready"
out="$("$ACCT" next --why 2>/dev/null)"; eq "next --why is the same as -v" "acc1" "$out"

# accounts never measured come last
setup
export FAKE_WEEK_ORDER=1
"$ACCT" test acc3 >/dev/null 2>&1   # only acc3 has numbers now; acc2 sorts before it by name
eq "next: a measured account goes before never-measured ones (acc3, not acc2)" "acc3" "$("$ACCT" next)"
setup
eq "next: with no numbers at all it falls back to name order (acc2 after acc1)" "acc2" "$("$ACCT" next)"
"$ACCT" next -v 2>&1 >/dev/null | grep -q "no quota data yet" && pass "next -v: says there is no quota data yet" || fail "next -v: says there is no quota data yet"

# an account with its weekly limit used up is on cooldown, so it is skipped although its reset comes first
setup
export FAKE_WEEK_ORDER=1 FAKE_WEEKLY_HIT_TOKENS="tok-acc3"
"$ACCT" list >/dev/null 2>&1
eq "next: the weekly-limit account (acc3, earliest reset) is skipped: acc2" "acc2" "$("$ACCT" next)"
unset FAKE_WEEKLY_HIT_TOKENS

# rotate uses it
setup
export FAKE_WEEK_ORDER=1
"$ACCT" list >/dev/null 2>&1
out="$("$ACCT" rotate 1h 2>&1)"; rc=$?
eq "rotate: exit 0" "0" "$rc"
has "rotate: switched to the soonest weekly reset (acc3)" "switched to account 'acc3'" "$out"
has "rotate: explains the choice" "weekly limit resets" "$out"
eq "rotate: acc1 is on cooldown" "$((1000000 + 3600))" "$(cd_of acc1)"

# agy-run uses it
setup
export FAKE_WEEK_ORDER=1
"$ACCT" list >/dev/null 2>&1
: >"$FAKE_ARGS_LOG"
export FAKE_QUOTA_TOKENS="tok-acc1"
runit; rc=$?
eq "agy-run: acc1 out of quota -> exit 0" "0" "$rc"
has "agy-run: the second run uses acc3 (soonest weekly reset), not acc2" "tok-acc3|" "$(sed -n 2p "$FAKE_ARGS_LOG")"
has "agy-run: its log says why" "next account 'acc3': weekly limit resets" "$(cat "$T/run.err")"
unset FAKE_QUOTA_TOKENS FAKE_WEEK_ORDER
has "help next: describes the rule" "whose weekly limit resets soonest" "$("$ACCT" help next)"
has "help next: mentions -v" "-v, --why" "$("$ACCT" help next)"

echo "== list: weekly limit used up (the 5-hour line is 'disabled', not a failure)"
setup
export FAKE_WEEKLY_HIT_TOKENS="tok-acc2"
out="$("$ACCT" list 2>&1)"; rc=$?
row2="$(grep '^  acc2' <<<"$out")"
eq "weekly limit used up: exit 0, not a measuring failure" "0" "$rc"
hasnt "weekly limit used up: not reported as 'measure failed'" "measure failed" "$out"
has "weekly limit used up: status says so, with the time left" "weekly limit reached, 72h00m left" "$row2"
has "weekly limit used up: the 5-hour column says off" " off " "$row2"
has "weekly limit used up: the weekly column shows 0%" "0%" "$row2"
eq "weekly limit used up: cooldown until the weekly reset (1000000 + 3 days)" "$((1000000 + 259200))" "$(cd_of acc2)"
eq "weekly limit used up: the snapshot marks the 5-hour limit as disabled (-1)" "-1" "$(jq -r .quota.acc2.g5 "$AGY_HOME/accounts/state.json")"
eq "weekly limit used up: next skips the account" "acc3" "$("$ACCT" next)"
has "the other accounts are measured as usual" "60%" "$(grep '^\* acc1' <<<"$out")"
out="$("$ACCT" list -c)"
has "list -c: same status from the saved data" "weekly limit reached" "$(grep '^  acc2' <<<"$out")"
hasnt "list -c: not stale" "stale" "$(grep '^  acc2' <<<"$out")"
out="$(AGYR_COLOR=always "$ACCT" list -c)"
has "the weekly-limit status is red" "${ESC:-$'\033'}[31mweekly limit reached" "$out"
# the rest of the line keeps its alignment: same width as an ordinary row
eq "weekly limit used up: the row is as wide as the others up to the status" "$(grep '^  acc3' <<<"$("$ACCT" list -c)" | cut -c1-70 | wc -c | tr -d ' ')" "$(grep '^  acc2' <<<"$("$ACCT" list -c)" | cut -c1-70 | wc -c | tr -d ' ')"
# agyr test on such an account never prints the marker
export FAKE_HI_ERROR_TOKENS="tok-acc2"
out="$("$ACCT" test acc2 2>/dev/null)"
hasnt "test: the -1 marker never reaches the screen" "-1%" "$out"
has "test: the 5-hour limit of that account is shown as off" "off" "$(grep '^  acc2' <<<"$out")"
unset FAKE_HI_ERROR_TOKENS
# the limit comes back: the next measurement replaces the snapshot and clears the cooldown
unset FAKE_WEEKLY_HIT_TOKENS
out="$("$ACCT" list 2>&1)"
hasnt "after the weekly reset: no weekly-limit status" "weekly limit reached" "$out"
eq "after the weekly reset: the cooldown is cleared" "0" "$(cd_of acc2)"
eq "after the weekly reset: the 5-hour number is back (70 minus the 1% the Hi call used)" "69" "$(jq -r .quota.acc2.g5 "$AGY_HOME/accounts/state.json")"
# a line that really is broken is still a failure
setup
export FAKE_DEAD_TOKENS="tok-acc3"
"$ACCT" list >/dev/null 2>&1; eq "a dead account is still a measuring failure (exit 1)" "1" "$?"
unset FAKE_DEAD_TOKENS

echo "== list: rows ordered by the weekly reset time"
order_of() { grep -oE '^[ *] +acc[0-9]' <<<"$1" | tr -d ' *' | tr '\n' ' '; }
setup
export FAKE_WEEK_ORDER=1
out="$("$ACCT" list 2>/dev/null)"
eq "list: soonest weekly reset first (acc3, acc2, acc1; not by name)" "acc3 acc2 acc1 " "$(order_of "$out")"
eq "list -c: same order from the saved data" "acc3 acc2 acc1 " "$(order_of "$("$ACCT" list -c)")"
has "list: the selected account keeps its * wherever it lands" "* acc1" "$out"
# an account that was never measured goes last
setup
export FAKE_WEEK_ORDER=1
"$ACCT" test acc2 >/dev/null 2>&1
eq "list -c: the measured account first, never-measured ones after it by name" "acc2 acc1 acc3 " "$(order_of "$("$ACCT" list -c)")"
# an account that fails to measure goes last, even if its week would reset first
setup
export FAKE_WEEK_ORDER=1 FAKE_DEAD_TOKENS="tok-acc3"
eq "list: an account that failed to measure is listed last" "acc2 acc1 acc3 " "$(order_of "$("$ACCT" list 2>/dev/null)")"
unset FAKE_DEAD_TOKENS
# ... also when it has an older snapshot whose week would reset first (stale numbers must not decide the position)
setup
export FAKE_WEEK_ORDER=1
"$ACCT" list >/dev/null 2>&1
eq "list: with a snapshot, acc3 (earliest week) is first" "acc3 acc2 acc1 " "$(order_of "$("$ACCT" list -c)")"
export FAKE_DEAD_TOKENS="tok-acc3"
eq "list: a failed account with an old, earliest snapshot is still listed last" "acc2 acc1 acc3 " "$(order_of "$("$ACCT" list 2>/dev/null)")"
unset FAKE_DEAD_TOKENS
# without differences the order is by name
setup
unset FAKE_WEEK_ORDER
eq "list: equal weekly resets are ordered by name" "acc1 acc2 acc3 " "$(order_of "$("$ACCT" list 2>/dev/null)")"
# colours and the list header still line up with the rows
setup
export FAKE_WEEK_ORDER=1
"$ACCT" list >/dev/null 2>&1
eq "list: the table has one row per account plus the header" "4" "$("$ACCT" list -c | grep -cE '^[ *] +(ACCOUNT|acc[0-9])')"
unset FAKE_WEEK_ORDER
has "help list: says how the rows are ordered" "ordered by when the weekly limit resets" "$("$ACCT" help list)"

echo "== test (Hi to every account)"
hi_lines() { grep -F -- '|-p Hi ' "$FAKE_ARGS_LOG"; }
hi_count() { hi_lines | wc -l | tr -d ' '; }
setup
mkdir -p "$T/tmp"
out="$(TMPDIR="$T/tmp" "$ACCT" test 2>"$T/test.err")"; rc=$?
err="$(cat "$T/test.err")"
eq "test: exit 0" "0" "$rc"
has "test: heads-up on stderr that it uses real quota" "one real request each" "$err"
has "test: table header" "ACCOUNT" "$out"
eq "test: all three accounts answered" "3" "$(grep -c 'ok in' <<<"$out")"
has "test: acc1 5h before>after" "60%>59%" "$out"
has "test: acc2 5h before>after" "70%>69%" "$out"
has "test: acc3 5h before>after" "80%>79%" "$out"
has "test: shows the reset time" "12/01/1970 09:46 PM" "$out"
eq "test: exactly one Hi per account" "3" "$(hi_count)"
eq "test: each Hi uses its own account's login, not the keyring's" "tok-acc1 tok-acc2 tok-acc3 " "$(hi_lines | cut -d'|' -f1 | sort | tr '\n' ' ')"
eq "test: every Hi uses gemini-3.8-flash-high" "3" "$(hi_lines | grep -c -- '--model gemini-3.8-flash-high')"
hasnt "test: Hi never gets --dangerously-skip-permissions (no tools needed)" "--dangerously-skip-permissions" "$(hi_lines)"
eq "test: quota is measured before and after each Hi (2 per account)" "6" "$(grep -cF -- '|-p /quota ' "$FAKE_ARGS_LOG")"
eq "test: the new 5h % is saved (acc1 -> 59)" "59" "$(jq -r .quota.acc1.g5 "$AGY_HOME/accounts/state.json")"
eq "test: the account in use does not change" "acc1" "$("$ACCT" active)"
eq "test: the real token file is untouched" "tok-acc1" "$(cat "$AGY_HOME/antigravity-oauth-token")"
eq "test: no temp directory (holding a token copy) left behind" "0" "$(ls -A "$T/tmp" | wc -l | tr -d ' ')"
hasnt "test: does not print any login" "tok-" "$out"

# accounts on cooldown are skipped when no names are given
setup
"$ACCT" cooldown acc2 2h >/dev/null
out="$("$ACCT" test 2>/dev/null)"; rc=$?
eq "test: exit 0 with a skipped account" "0" "$rc"
has "test: says acc2 is skipped because of its cooldown" "skipped (cooldown, 2h00m left)" "$out"
eq "test: only the other two got a Hi" "2" "$(hi_count)"
hasnt "test: acc2 got no Hi" "tok-acc2" "$(hi_lines)"
eq "test: acc2's cooldown is kept" "$((1000000 + 7200))" "$(cd_of acc2)"

# a named account is always tried; the fresh measurement clears a cooldown that was wrong
setup
"$ACCT" cooldown acc2 2h >/dev/null
out="$("$ACCT" test acc2 2>/dev/null)"; rc=$?
eq "test <name>: exit 0" "0" "$rc"
eq "test <name>: only that account got a Hi" "1" "$(hi_count)"
has "test <name>: it was sent to acc2" "tok-acc2|" "$(hi_lines)"
hasnt "test <name>: the other accounts are not listed" "acc1" "$out"
eq "test <name>: it still had quota, so the cooldown is cleared" "0" "$(cd_of acc2)"
"$ACCT" test acc1 acc3 acc1 >/dev/null 2>&1
eq "test <names>: two more Hi, a repeated name counts once" "3" "$(hi_count)"
n0="$(lines)"
out="$("$ACCT" test nope 2>&1)"; rc=$?
eq "test <unknown slot> -> exit 1" "1" "$rc"
has "test <unknown slot>: says so" "no slot 'nope'" "$out"
"$ACCT" test acc1 '../x' >/dev/null 2>&1; eq "test with an invalid name -> exit 1" "1" "$?"
eq "test: refused names start no agy" "$n0" "$(lines)"

# the reset time before the Hi is shown when the Hi moved it
setup
out="$("$ACCT" test acc1 2>/dev/null)"
hasnt "test: no '(was ...)' on the account's row when the reset time did not move" "(was" "$(grep '^  acc1' <<<"$out")"
setup
export FAKE_HI_SHIFT=1
out="$("$ACCT" test acc1 2>/dev/null)"
has "test: the new reset time is shown (09:46 PM + 10 min)" "09:56 PM" "$(grep '^  acc1' <<<"$out")"
has "test: and the time before it, because the Hi moved it" "(was 09:46 PM)" "$(grep '^  acc1' <<<"$out")"
unset FAKE_HI_SHIFT

# an account whose Hi fails
setup
export FAKE_HI_ERROR_TOKENS="tok-acc2"
out="$("$ACCT" test 2>/dev/null)"; rc=$?
eq "test: an account that cannot answer -> exit 1" "1" "$rc"
has "test: shows the error of that account" "failed: Individual quota reached" "$out"
eq "test: the other two still answered" "2" "$(grep -c 'ok in' <<<"$out")"
unset FAKE_HI_ERROR_TOKENS

# an agy that hangs is cut off by the timeout (and does not stall the others)
setup
export FAKE_QUOTA_TOKENS="tok-acc1" AGYR_TEST_TIMEOUT=2
start=$SECONDS
out="$("$ACCT" test acc1 acc2 2>/dev/null)"; rc=$?
elapsed=$((SECONDS - start))
eq "test: a hanging agy -> exit 1" "1" "$rc"
has "test: says agy gave no answer" "agy gave no answer" "$out"
eq "test: the other account still answered" "1" "$(grep -c 'ok in' <<<"$out")"
[ "$elapsed" -lt 20 ] && pass "test: the hang was cut off by AGYR_TEST_TIMEOUT (${elapsed}s)" || fail "test: the hang was cut off by AGYR_TEST_TIMEOUT" "took ${elapsed}s"
sleep 0.5
eq "test: no fake-agy process left behind" "0" "$(pgrep -fc "$HERE/fake-agy" || true)"
unset FAKE_QUOTA_TOKENS AGYR_TEST_TIMEOUT

# every account on cooldown: nothing is sent
setup
for a in acc1 acc2 acc3; do "$ACCT" cooldown "$a" 2h >/dev/null; done
n0="$(lines)"
out="$("$ACCT" test 2>&1)"; rc=$?
eq "test: all on cooldown -> exit 0" "0" "$rc"
has "test: says there is nothing to do" "nothing to do" "$out"
eq "test: nothing was sent" "$n0" "$(lines)"

# no agy / no accounts
setup
out="$(AGY_BIN=/nonexistent/agy "$ACCT" test 2>&1)"; rc=$?
eq "test: no agy -> exit 1" "1" "$rc"
has "test: no agy -> message" "agy not found" "$out"
rm -rf "$AGY_HOME/accounts"
out="$("$ACCT" test 2>&1)"; rc=$?
eq "test: no accounts -> exit 0" "0" "$rc"
has "test: no accounts -> hint" "no accounts yet" "$out"

# help
setup
n0="$(lines)"
"$ACCT" test --help >/dev/null 2>&1
eq "test --help sends nothing" "$n0" "$(lines)"
out="$("$ACCT" help test)"
has "help test: warns that it is a real request" "ONE REAL REQUEST" "$out"
has "help test: names the model" "gemini-3.8-flash-high" "$out"
has "help test: says the window idea is an assumption to check" "THAT IS AN ASSUMPTION" "$out"
hasnt "help test: no unsupported claim that was observed" "Observed:" "$out"
has "help test: documents the timeout variable" "AGYR_TEST_TIMEOUT" "$out"
has "overview describes test" "Send \"Hi\" to every account" "$("$ACCT" help)"

echo "== help"
setup
for form in "help" "--help" "-h"; do
  out="$("$ACCT" $form 2>&1)"; rc=$?
  eq "agyr ${form:-<no args>}: exit 0" "0" "$rc"
  has "agyr ${form:-<no args>}: has the command list" "Commands:" "$out"
  has "agyr ${form:-<no args>}: has examples" "Typical use:" "$out"
  has "agyr ${form:-<no args>}: has exit codes" "Exit codes:" "$out"
  has "agyr ${form:-<no args>}: has environment variables" "Environment:" "$out"
done
overview="$("$ACCT" help)"
for c in list save use rename forget test active run rotate next cooldown clear help; do
  has "overview lists '$c'" "  $c" "$overview"
done
has "overview warns about the keyring" "OS keyring" "$overview"
for c in list save use rename forget test active run cooldown clear next rotate help; do
  h="$("$ACCT" help "$c" 2>&1)"; rc=$?
  eq "agyr help $c: exit 0" "0" "$rc"
  has "agyr help $c: has its usage line" "Usage: agyr $c" "$h"
  eq "agyr $c --help == agyr help $c" "$h" "$("$ACCT" "$c" --help 2>&1)"
done
eq "agyr ls --help == agyr help list" "$("$ACCT" help list)" "$("$ACCT" ls --help)"
out="$("$ACCT" help bogus 2>&1)"; rc=$?
eq "agyr help <unknown> -> exit 2" "2" "$rc"
has "agyr help <unknown> names the bad command" "no such command 'bogus'" "$out"
"$ACCT" bogus --help >/dev/null 2>&1; eq "agyr <unknown> --help -> exit 2" "2" "$?"

# --help must only print help, never run the command
setup
"$ACCT" list --help >/dev/null 2>&1
eq "list --help does not call agy" "0" "$(lines)"
slots_before="$(ls "$AGY_HOME/accounts"/*.token | wc -l | tr -d ' ')"
"$ACCT" save --help >/dev/null 2>&1
eq "save --help does not save a slot" "$slots_before" "$(ls "$AGY_HOME/accounts"/*.token | wc -l | tr -d ' ')"
"$ACCT" use --help >/dev/null 2>&1
eq "use --help does not switch" "acc1" "$("$ACCT" active)"
"$ACCT" rotate --help >/dev/null 2>&1
eq "rotate --help does not set a cooldown" "0" "$(cd_of acc1)"
eq "rotate --help does not switch" "acc1" "$("$ACCT" active)"
"$ACCT" cooldown --help >/dev/null 2>&1; eq "cooldown --help without other args -> exit 0" "0" "$?"
mkdir -p "$T/empty"
AGY_HOME="$T/empty" "$ACCT" help >/dev/null 2>&1
eq "help does not create the accounts directory" "no" "$([ -e "$T/empty/accounts" ] && echo yes || echo no)"

out="$("$RUN" --help 2>&1)"; rc=$?
eq "agy-run --help: exit 0" "0" "$rc"
has "agy-run --help: has the usage line" "Usage: agy-run --prompt FILE" "$out"
has "agy-run --help: has exit codes" "Exit codes:" "$out"
has "agy-run --help: documents --conversation" "--conversation ID" "$out"
eq "agy-run --help does not run agy" "0" "$(lines)"
"$RUN" -h >/dev/null 2>&1; eq "agy-run -h: exit 0" "0" "$?"
out="$("$RUN" --bogus 2>&1)"
has "agy-run: an unknown argument points to --help" "see --help" "$out"

echo "== plain agyr starts agy"
setup
"$ACCT" >/dev/null 2>&1
eq "plain 'agyr' starts agy once" "1" "$(lines)"
has "plain 'agyr': agy uses the selected account's token file" "tok-acc1|" "$(cat "$FAKE_ARGS_LOG")"
"$ACCT" use acc3 >/dev/null
"$ACCT" -c >/dev/null 2>&1
has "'agyr -c' passes -c to agy, with the selected account" "tok-acc3|-c" "$(tail -1 "$FAKE_ARGS_LOG")"
"$ACCT" -p "do it" --model x >/dev/null 2>&1
has "'agyr -p ...' passes all flags through" "tok-acc3|-p do it --model x" "$(tail -1 "$FAKE_ARGS_LOG")"
"$ACCT" run models >/dev/null 2>&1
has "'agyr run <word>' passes a non-flag word to agy" "tok-acc3|models" "$(tail -1 "$FAKE_ARGS_LOG")"
n0="$(lines)"
"$ACCT" --help >/dev/null 2>&1; "$ACCT" -h >/dev/null 2>&1; "$ACCT" help >/dev/null 2>&1
eq "--help, -h and help do not start agy" "$n0" "$(lines)"
"$ACCT" bogus >/dev/null 2>&1; rc=$?
eq "'agyr <unknown word>' is still an error (exit 2), agy is not started" "2" "$rc"
eq "unknown word: agy not started" "$n0" "$(lines)"
"$ACCT" run --help >/dev/null 2>&1
eq "'agyr run --help' shows help, does not start agy" "$n0" "$(lines)"
out="$("$ACCT" help run)"
has "help run mentions the shorthand" "shorthand: agyr [agy arguments...]" "$out"
has "overview mentions plain agyr" "start agy with the selected account" "$("$ACCT" help)"
out="$(AGY_BIN=/nonexistent/agy "$ACCT" 2>&1)"; rc=$?
eq "plain agyr without agy -> error" "1" "$rc"
has "plain agyr without agy -> message" "agy not found" "$out"

echo "== run / keyring (agy >= 1.2.14)"
setup
"$ACCT" run -p hello >/dev/null 2>&1
has "agyr run: agy uses the token file (keyring made unreachable)" "tok-acc1|-p hello" "$(cat "$FAKE_ARGS_LOG")"
"$ACCT" use acc2 >/dev/null
"$ACCT" run -c >/dev/null 2>&1
has "agyr run: follows 'agyr use' (acc2)" "tok-acc2|-c" "$(sed -n 2p "$FAKE_ARGS_LOG")"
out="$(FAKE_QUOTA_TOKENS="tok-acc2" "$ACCT" run -p x 2>&1 | head -1)"
has "agyr run: passes agy's output through" "init" "$out"
"$ACCT" run --version >/dev/null 2>&1; rc=$?
eq "agyr run: the exit code of agy is propagated (fake agy ignores unknown flags)" "0" "$rc"
out="$(AGY_BIN=/nonexistent/agy "$ACCT" run 2>&1)"; rc=$?
eq "agyr run: no agy -> error" "1" "$rc"
has "agyr run: no agy -> message" "agy not found" "$out"
mkdir -p "$T/empty2"
AGY_HOME="$T/empty2" "$ACCT" run -p hi >/dev/null 2>&1
eq "agyr run does not create the accounts directory" "no" "$([ -e "$T/empty2/accounts" ] && echo yes || echo no)"
# the fake really does ignore the token file when the keyring is reachable (so the checks above are meaningful)
setup
DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/x/bus "$AGY_BIN" -p hi >/dev/null 2>&1
has "sanity: with a reachable keyring the fake agy uses the keyring account" "keyring-account|-p hi" "$(tail -1 "$FAKE_ARGS_LOG")"
# agyr list and agy-run measure / run every account with its own token even though the keyring says otherwise
setup
"$ACCT" list >/dev/null 2>&1
eq "list: every account measured with its own token, not the keyring's" "tok-acc1 tok-acc2 tok-acc3 " "$(cut -d'|' -f1 "$FAKE_ARGS_LOG" | sort | tr '\n' ' ')"
setup
runit >/dev/null 2>&1
has "agy-run: agy ran with the selected account's token, not the keyring's" "tok-acc1|" "$(cat "$FAKE_ARGS_LOG")"
hasnt "agy-run: the keyring account was not used" "keyring-account" "$(cat "$FAKE_ARGS_LOG")"
out="$("$ACCT" rotate 1h 2>&1)"
has "rotate: tells you to reopen with agyr -c" "agyr -c" "$out"

echo "== forget (file backend)"
setup
out="$("$ACCT" forget 2>&1)"; rc=$?
eq "forget: exit 0" "0" "$rc"
eq "forget: the token file is gone" "no" "$([ -e "$AGY_HOME/antigravity-oauth-token" ] && echo yes || echo no)"
eq "forget: backed up first" "tok-acc1" "$(cat "$AGY_HOME/accounts/.last-token.bak")"
eq "forget: the slot keeps the login" "tok-acc1" "$(cat "$AGY_HOME/accounts/acc1.token")"
has "forget: says nothing was revoked" "nothing was revoked" "$out"
hasnt "forget: does not print the token" "tok-" "$out"
out="$("$ACCT" forget 2>&1)"; has "forget: with no login -> nothing to forget" "nothing to forget" "$out"
setup
echo "tok-unsaved" >"$AGY_HOME/antigravity-oauth-token"
out="$("$ACCT" forget 2>&1)"; rc=$?
eq "forget: refuses a login that matches no slot" "1" "$rc"
has "forget: ... and says why" "would lose it" "$out"
eq "forget: ... and leaves the login alone" "tok-unsaved" "$(cat "$AGY_HOME/antigravity-oauth-token")"
"$ACCT" forget --force >/dev/null 2>&1
eq "forget --force: removes it" "no" "$([ -e "$AGY_HOME/antigravity-oauth-token" ] && echo yes || echo no)"
eq "forget --force: after backing it up" "tok-unsaved" "$(cat "$AGY_HOME/accounts/.last-token.bak")"
"$ACCT" forget --bogus >/dev/null 2>&1; eq "forget: unknown option -> exit 2" "2" "$?"

echo "== wincred backend (Windows Credential Manager; here a fake one: nothing in this section touches a real login)"
export AGYR_BACKEND=wincred
eq "wincred: tests only ever use the fake credential helper" "$HERE/fake-cred" "$AGYR_CRED_HELPER"
# regression (seen on a real Windows machine: every account 'measure failed'): Git Bash rewrote the argument /quota into
# C:/Program Files/Git/quota. The fake agy is a bash script, so it cannot show this; check that the protection is there.
has "wincred: agyr hands the /quota exclusion to quota_fetch" 'PLATFORM_ENV_NOCONV_QUOTA' "$(grep -n 'PLATFORM_ENV_NOCONV_QUOTA' "$ACCT")"
has "wincred: windows platform shields /quota from msys path conversion" 'MSYS2_ARG_CONV_EXCL=/quota' "$(grep -n 'MSYS2_ARG_CONV_EXCL' "$HERE/../windows/platform.sh")"
has "wincred: agy-run hands the prompt over unchanged (PLATFORM_ENV_NOCONV_ALL)" 'PLATFORM_ENV_NOCONV_ALL' "$(grep -n 'PLATFORM_ENV_NOCONV_ALL' "$RUN")"
has "wincred: windows platform shields the prompt from msys path conversion" "MSYS2_ARG_CONV_EXCL='*'" "$(grep -n 'MSYS2_ARG_CONV_EXCL' "$HERE/../windows/platform.sh")"

# like setup, but the login lives in the fake credential entry $T/cred (there is no token file at all)
setupw() {
  T="$(mktemp -d)"; TMPS+=("$T")
  export AGY_HOME="$T/home"; mkdir -p "$AGY_HOME"
  export AGY_NOW=1000000
  export FAKE_ARGS_LOG="$T/args.log"; : >"$FAKE_ARGS_LOG"
  export FAKE_CRED_FILE="$T/cred"
  unset FAKE_QUOTA_TOKENS FAKE_AUTH FAKE_RESET AGY_RUN_MAX_SWITCH FAKE_REFRESH FAKE_CRED_FAIL_AT AGYR_LOCK_WAIT
  local a
  for a in acc1 acc2 acc3; do
    if [ "${1:-}" = json ]; then jtok "$a" "at-$a" >"$FAKE_CRED_FILE"; else echo "tok-$a" >"$FAKE_CRED_FILE"; fi
    "$ACCT" save "$a" >/dev/null
  done
  "$ACCT" use acc1 >/dev/null
  rm -f "$FAKE_CRED_FILE.writes"
  echo "do the thing" >"$T/prompt.txt"
  mkdir -p "$T/work"
}
cred_exists() { [ -f "$FAKE_CRED_FILE" ] && echo yes || echo no; }

setupw
eq "wincred: backend" "wincred" "$("$ACCT" backend)"
eq "wincred: save took the login from the credential entry" "tok-acc2" "$(cat "$AGY_HOME/accounts/acc2.token")"
eq "wincred: active = acc1" "acc1" "$("$ACCT" active)"
eq "wincred: no token file is ever created in the agy directory" "no" "$([ -e "$AGY_HOME/antigravity-oauth-token" ] && echo yes || echo no)"
out="$("$ACCT" list -c)"; has "wincred: list -c marks the selected account" "* acc1" "$out"
(AGYR_BACKEND=bogus "$ACCT" backend >/dev/null 2>&1); eq "wincred: an unknown backend name -> exit 2" "2" "$?"

# use
setupw
out="$("$ACCT" use acc2 2>&1)"
eq "wincred: use writes the slot's login into the entry" "tok-acc2" "$(cat "$FAKE_CRED_FILE")"
eq "wincred: use backs up the previous login first" "tok-acc1" "$(cat "$AGY_HOME/accounts/.last-token.bak")"
eq "wincred: active follows use" "acc2" "$("$ACCT" active)"
hasnt "wincred: use does not print the login" "tok-" "$out"
eq "wincred: use leaves no lock behind" "no" "$([ -e "$AGY_HOME/accounts/.swap.lock" ] && echo yes || echo no)"
"$ACCT" use nope >/dev/null 2>&1; eq "wincred: use of a missing slot -> error" "1" "$?"
eq "wincred: a failed use leaves the login alone" "tok-acc2" "$(cat "$FAKE_CRED_FILE")"

setupw json
jtok acc1 "at-acc1-refreshed" >"$FAKE_CRED_FILE" # agy refreshed the access token itself (same refresh_token)
"$ACCT" use acc2 >/dev/null
eq "wincred: use syncs the refreshed login back into its own slot" "at-acc1-refreshed" "$(jq -r .token.access_token "$AGY_HOME/accounts/acc1.token")"
eq "wincred: use writes acc2's login" "at-acc2" "$(jq -r .token.access_token "$FAKE_CRED_FILE")"

setupw
echo "tok-unsaved" >"$FAKE_CRED_FILE" # logged in to an account that was never saved
out="$("$ACCT" list -c)"; has "wincred: warns when the login in use matches no slot" "matches no slot" "$out"
"$ACCT" use acc2 >/dev/null
eq "wincred: an unsaved login is kept in .last-token.bak" "tok-unsaved" "$(cat "$AGY_HOME/accounts/.last-token.bak")"
eq "wincred: an unsaved login overwrites no slot (acc1)" "tok-acc1" "$(cat "$AGY_HOME/accounts/acc1.token")"
eq "wincred: an unsaved login overwrites no slot (acc2)" "tok-acc2" "$(cat "$AGY_HOME/accounts/acc2.token")"

# lock
setupw
echo 999999 >"$AGY_HOME/accounts/.swap.lock" # its owner is gone
"$ACCT" use acc2 >/dev/null 2>&1; eq "wincred: a stale lock (owner gone) is taken over" "0" "$?"
eq "wincred: ... and the switch happened" "tok-acc2" "$(cat "$FAKE_CRED_FILE")"
setupw
echo $$ >"$AGY_HOME/accounts/.swap.lock" # its owner (this shell) is alive
out="$(AGYR_LOCK_WAIT=1 "$ACCT" use acc2 2>&1)"; rc=$?
eq "wincred: a lock held by a live process -> error" "1" "$rc"
has "wincred: ... with a clear message" "another agyr is switching accounts" "$out"
eq "wincred: ... and the login is untouched" "tok-acc1" "$(cat "$FAKE_CRED_FILE")"
rm -rf "$AGY_HOME/accounts/.swap.lock"

# list: accounts are measured one after another by swapping the shared login, then the original is put back
setupw
out="$("$ACCT" list 2>&1)"; rc=$?
eq "wincred list: exit 0" "0" "$rc"
has "wincred list: * marks the selected account" "* acc1" "$out"
has "wincred list: acc1 5h = 60%" " 60%" "$out"
has "wincred list: acc2 5h = 70%" " 70%" "$out"
has "wincred list: acc3 5h = 80%" " 80%" "$out"
hasnt "wincred list: does not print any login" "tok-" "$out"
eq "wincred list: every account was measured with its own login" "tok-acc1 tok-acc2 tok-acc3 " "$(cut -d'|' -f1 "$FAKE_ARGS_LOG" | sort | tr '\n' ' ')"
eq "wincred list: the login in use is put back" "tok-acc1" "$(cat "$FAKE_CRED_FILE")"
eq "wincred list: the active account is unchanged" "acc1" "$("$ACCT" active)"
eq "wincred list: no lock left behind" "no" "$([ -e "$AGY_HOME/accounts/.swap.lock" ] && echo yes || echo no)"
eq "wincred list: stores the acc3 snapshot gw=70" "70" "$(jq -r '.quota.acc3.gw' "$AGY_HOME/accounts/state.json")"
eq "wincred list: backs the login up before swapping" "tok-acc1" "$(cat "$AGY_HOME/accounts/.last-token.bak")"
mkdir -p "$T/tmp"; TMPDIR="$T/tmp" "$ACCT" list >/dev/null 2>&1
eq "wincred list: no temp copy of a login left behind" "0" "$(ls -A "$T/tmp" | wc -l | tr -d ' ')"

setupw
"$ACCT" use acc2 >/dev/null; "$ACCT" list >/dev/null 2>&1
eq "wincred list: restores the login that was in use (acc2, not the first/last measured)" "tok-acc2" "$(cat "$FAKE_CRED_FILE")"

setupw
echo "tok-unsaved" >"$FAKE_CRED_FILE"
"$ACCT" list >/dev/null 2>&1
eq "wincred list: a login that matches no slot is restored too" "tok-unsaved" "$(cat "$FAKE_CRED_FILE")"

setupw
rm -f "$FAKE_CRED_FILE"
"$ACCT" list >/dev/null 2>&1
eq "wincred list: started with no login -> ends with no login" "no" "$(cred_exists)"

setupw json
FAKE_REFRESH=1 "$ACCT" list >/dev/null 2>&1
eq "wincred list: a login agy refreshed is taken back into its slot (acc2)" "at-acc2-refreshed" "$(jq -r .token.access_token "$AGY_HOME/accounts/acc2.token")"
eq "wincred list: the active account's login is restored (refresh_token intact)" "rt-acc1" "$(jq -r .token.refresh_token "$FAKE_CRED_FILE")"
eq "wincred list: ... and it is the refreshed one" "at-acc1-refreshed" "$(jq -r .token.access_token "$FAKE_CRED_FILE")"
eq "wincred list: active is still acc1" "acc1" "$("$ACCT" active)"

# forget: drop the login so agy asks for a new one (the Linux 'rm <token file>')
setupw json
jtok acc1 "at-acc1-refreshed" >"$FAKE_CRED_FILE"
out="$("$ACCT" forget 2>&1)"; rc=$?
eq "wincred forget: exit 0" "0" "$rc"
eq "wincred forget: the entry is gone" "no" "$(cred_exists)"
eq "wincred forget: the slot gets the freshest copy" "at-acc1-refreshed" "$(jq -r .token.access_token "$AGY_HOME/accounts/acc1.token")"
eq "wincred forget: backed up first" "at-acc1-refreshed" "$(jq -r .token.access_token "$AGY_HOME/accounts/.last-token.bak")"
hasnt "wincred forget: does not print the login" "at-acc" "$out"
eq "wincred forget: no lock left" "no" "$([ -e "$AGY_HOME/accounts/.swap.lock" ] && echo yes || echo no)"
out="$("$ACCT" forget 2>&1)"; has "wincred forget: with no login -> nothing to forget" "nothing to forget" "$out"
echo "tok-new-login" >"$FAKE_CRED_FILE"; "$ACCT" save acc4 >/dev/null # the next account: log in, save
eq "wincred forget: a new login is saved as its own slot" "tok-new-login" "$(cat "$AGY_HOME/accounts/acc4.token")"
setupw
echo "tok-unsaved" >"$FAKE_CRED_FILE"
"$ACCT" forget >/dev/null 2>&1; eq "wincred forget: refuses a login that matches no slot" "1" "$?"
eq "wincred forget: ... and leaves the entry alone" "tok-unsaved" "$(cat "$FAKE_CRED_FILE")"
"$ACCT" forget --force >/dev/null 2>&1
eq "wincred forget --force: removes the entry" "no" "$(cred_exists)"
eq "wincred forget --force: after backing it up" "tok-unsaved" "$(cat "$AGY_HOME/accounts/.last-token.bak")"

# a write fails half way through the measurement: the original login must still come back, and the lock must go
setupw
FAKE_CRED_FAIL_AT=2 "$ACCT" list >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] && pass "wincred list: a failing write makes list fail" || fail "wincred list: a failing write makes list fail" "exit code was 0"
eq "wincred list: after a failed write the original login is restored" "tok-acc1" "$(cat "$FAKE_CRED_FILE")"
eq "wincred list: after a failed write no lock is left" "no" "$([ -e "$AGY_HOME/accounts/.swap.lock" ] && echo yes || echo no)"
unset FAKE_CRED_FAIL_AT

# agyr run / agy-run: agy needs no keyring trick here, it just reads the entry that 'use' wrote
setupw
"$ACCT" use acc2 >/dev/null
"$ACCT" run -p hello >/dev/null 2>&1
has "wincred: agyr run starts agy with the selected account" "tok-acc2|-p hello" "$(cat "$FAKE_ARGS_LOG")"

setupw
runit; rc=$?
eq "wincred agy-run: immediate success: exit 0" "0" "$rc"
has "wincred agy-run: uses the selected account" "tok-acc1|" "$(cat "$FAKE_ARGS_LOG")"

setupw
export FAKE_QUOTA_TOKENS="tok-acc1"
start=$SECONDS
runit; rc=$?
elapsed=$((SECONDS - start))
eq "wincred agy-run: acc1 out of quota -> switch to acc2, exit 0" "0" "$rc"
eq "wincred agy-run: runs twice" "2" "$(lines)"
second="$(sed -n 2p "$FAKE_ARGS_LOG")"
has "wincred agy-run: second run uses acc2's login" "tok-acc2|" "$second"
has "wincred agy-run: second run resumes the same conversation" "--conversation conv-fake-1" "$second"
eq "wincred agy-run: the entry now holds acc2's login" "tok-acc2" "$(cat "$FAKE_CRED_FILE")"
eq "wincred agy-run: active = acc2" "acc2" "$("$ACCT" active)"
[ "$elapsed" -lt 20 ] && pass "wincred agy-run: stopped agy immediately (${elapsed}s)" || fail "wincred agy-run: stopped agy immediately" "took ${elapsed}s"
unset FAKE_QUOTA_TOKENS

# agyr test: one account after the other through the credential entry, which ends up as it was
setupw
out="$("$ACCT" test 2>/dev/null)"; rc=$?
eq "wincred test: exit 0" "0" "$rc"
eq "wincred test: all three answered" "3" "$(grep -c 'ok in' <<<"$out")"
eq "wincred test: one Hi per account, each with its own login" "tok-acc1 tok-acc2 tok-acc3 " "$(grep -F -- '|-p Hi ' "$FAKE_ARGS_LOG" | cut -d'|' -f1 | sort | tr '\n' ' ')"
has "wincred test: before>after of acc2" "70%>69%" "$out"
eq "wincred test: the entry holds the login that was in use again (acc1)" "tok-acc1" "$(cat "$FAKE_CRED_FILE")"
eq "wincred test: no lock left behind" "no" "$([ -e "$AGY_HOME/accounts/.swap.lock" ] && echo yes || echo no)"
eq "wincred test: no token file was created" "no" "$([ -e "$AGY_HOME/antigravity-oauth-token" ] && echo yes || echo no)"
eq "wincred test: the account in use did not change" "acc1" "$("$ACCT" active)"

# back to the default for the rest of the suite
export AGYR_BACKEND=file
unset FAKE_CRED_FILE

echo "== agy-task"

# Help and usage
out="$("$TASK" --help 2>&1)"; rc=$?
eq "agy-task --help: exit 0" "0" "$rc"
has "agy-task --help: usage line" "agy-task run --name NAME --task FILE" "$out"
has "agy-task --help: mentions rm" "agy-task rm NAME [-f] [--repo DIR]" "$out"
has "agy-task --help: exit codes" "Exit codes:" "$out"
has "agy-task --help: mentions --resume" "--resume" "$out"

out="$("$TASK" 2>&1)"; rc=$?
eq "agy-task no args: exit 0" "0" "$rc"
has "agy-task no args: usage line" "agy-task run --name NAME --task FILE" "$out"

out="$("$TASK" -h 2>&1)"; rc=$?
eq "agy-task -h: exit 0" "0" "$rc"

out="$("$TASK" run --help 2>&1)"; rc=$?
eq "agy-task run --help: exit 0" "0" "$rc"

out="$("$TASK" rm --help 2>&1)"; rc=$?
eq "agy-task rm --help: exit 0" "0" "$rc"
has "agy-task rm --help: mentions rm" "agy-task rm NAME [-f] [--repo DIR]" "$out"

task_repo() {
  local d
  d="$(mktemp -d)"
  TMPS+=("$d")
  git -C "$d" -c user.name=t -c user.email=t@t init -b main >/dev/null
  cat <<'EOF' > "$d/.gitignore"
.agy-sessions/
.worktrees/
generated.txt
setup_marker.txt
EOF
  echo "hello world" > "$d/file.txt"
  echo "gen content" > "$d/generated.txt"
  git -C "$d" add .gitignore file.txt
  git -C "$d" -c user.name=t -c user.email=t@t commit -m "init" >/dev/null
  echo "$d"
}

# Argument validation
R="$(task_repo)"
echo "goal" > "$R/task.txt"
"$TASK" run --task "$R/task.txt" --repo "$R" >/dev/null 2>&1
eq "missing --name -> exit 2" "2" "$?"

"$TASK" run --name "BAD_NAME" --task "$R/task.txt" --repo "$R" >/dev/null 2>&1
eq "bad name characters (uppercase) -> exit 2" "2" "$?"

"$TASK" run --name "bad_name" --task "$R/task.txt" --repo "$R" >/dev/null 2>&1
eq "bad name characters (underscore) -> exit 2" "2" "$?"

"$TASK" run --name hp --repo "$R" >/dev/null 2>&1
eq "missing --task -> exit 2" "2" "$?"

"$TASK" run --name hp --task "$R/missing.txt" --repo "$R" >/dev/null 2>&1
eq "missing task file -> exit 2" "2" "$?"

"$TASK" run --name hp --task "$R/task.txt" --repo "$R" --unknown-flag >/dev/null 2>&1
eq "unknown flag -> exit 2" "2" "$?"

"$TASK" bogus >/dev/null 2>&1
eq "unknown command -> exit 2" "2" "$?"

# Missing config file
out="$("$TASK" run --name noconf --task "$R/task.txt" --repo "$R" 2>"$R/noconf.err")"
rc=$?
eq "missing config file: exit 0" "0" "$rc"
has "missing config file: warning printed to stderr" "warning: no config file found" "$(cat "$R/noconf.err")"
has "missing config file: summary OK" "RESULT=OK" "$out"

# Rejected --verify flag
"$TASK" run --name rejverify --task "$R/task.txt" --repo "$R" --verify x >/dev/null 2>&1
eq "rejected --verify flag -> exit 2" "2" "$?"

# Happy path
R="$(task_repo)"
mkdir -p "$R/.agy-sessions"
cat <<'EOF' > "$R/.agy-sessions/agy-task.conf"
SETUP_CMDS=( 'echo setup_done > setup_marker.txt' )
COPY_FILES=( generated.txt )
EOF
SCRATCH="$(mktemp -d)"
TMPS+=("$SCRATCH")
echo "implement feature X" > "$SCRATCH/task.txt"
export AGY_RUN="$FAKE_TASK_RUN"
export FAKE_TASK_EDIT="file.txt:modified by agy"
export FAKE_PROMPT_COPY="$SCRATCH/copied_prompt.txt"
unset FAKE_TASK_EXIT FAKE_TASK_RM

base_sha="$(git -C "$R" rev-parse --short HEAD)"
out="$("$TASK" run --name hp --task "$SCRATCH/task.txt" --repo "$R" --scope "file.txt" 2>"$SCRATCH/hp.err")"
rc=$?
eq "happy path: exit 0" "0" "$rc"
eq "happy path: worktree exists" "yes" "$([ -d "$R/.worktrees/agy-hp" ] && echo yes || echo no)"
eq "happy path: branch agy/hp exists" "yes" "$([ -n "$(git -C "$R" rev-parse --verify --quiet refs/heads/agy/hp)" ] && echo yes || echo no)"
branch_sha="$(git -C "$R" rev-parse --short refs/heads/agy/hp)"
eq "happy path: branch sits on base sha" "$base_sha" "$branch_sha"
upstream="$(git -C "$R" rev-parse --symbolic-full-name agy/hp@{upstream} 2>/dev/null || true)"
eq "happy path: branch has no upstream" "" "$upstream"
eq "happy path: setup marker exists" "setup_done" "$(cat "$R/.worktrees/agy-hp/setup_marker.txt" 2>/dev/null || echo missing)"
eq "happy path: COPY_FILES copied gitignored file" "gen content" "$(cat "$R/.worktrees/agy-hp/generated.txt" 2>/dev/null || echo missing)"

p_content="$(cat "$SCRATCH/copied_prompt.txt" 2>/dev/null || echo missing)"
has "happy path: prompt contains worktree path" "$R/.worktrees/agy-hp" "$p_content"
has "happy path: prompt contains task text" "implement feature X" "$p_content"
has "happy path: prompt contains scope" "file.txt" "$p_content"
has "happy path: prompt contains HARD RULES" "HARD RULES (violating any = task failure):" "$p_content"
hasnt "happy path: prompt has no literal <ABS_PATH>" "<ABS_PATH>" "$p_content"
hasnt "happy path: prompt no longer contains Verification commands" "Verification commands" "$p_content"
has "happy path: prompt contains reviewer runs verification instruction" "The reviewer runs all verification after you finish." "$p_content"

summary_content="$(cat "$R/.agy-sessions/hp.summary.txt" 2>/dev/null || echo missing)"
has "happy path: summary has RESULT=OK" "RESULT=OK" "$summary_content"
has "happy path: summary has changed file" "file.txt" "$summary_content"
eq "happy path: stdout equals summary file" "$summary_content" "$out"

# Sessions isolation and clean checkout
eq "prompt in .agy-sessions" "yes" "$([ -f "$R/.agy-sessions/hp.prompt.txt" ] && echo yes || echo no)"
eq "jsonl in .agy-sessions" "yes" "$([ -f "$R/.agy-sessions/hp.jsonl" ] && echo yes || echo no)"
eq "setup log in .agy-sessions" "yes" "$([ -f "$R/.agy-sessions/hp.setup.log" ] && echo yes || echo no)"
eq "summary in .agy-sessions" "yes" "$([ -f "$R/.agy-sessions/hp.summary.txt" ] && echo yes || echo no)"
eq "nothing agy-task wrote in worktree tracked tree" "" "$(git -C "$R/.worktrees/agy-hp" ls-files -o --exclude-standard)"
eq "main checkout git status porcelain is empty" "" "$(git -C "$R" status --porcelain)"

# Scope and forbidden files
R="$(task_repo)"
echo "task" > "$R/task.txt"
export FAKE_TASK_EDIT="other.txt:out_of_scope"
out="$("$TASK" run --name scfail --task "$R/task.txt" --repo "$R" --scope "file.txt" 2>"$R/scfail.err")"
rc=$?
eq "edit outside --scope -> exit 8" "8" "$rc"
has "edit outside scope: lists path" "other.txt" "$out"
has "edit outside scope: summary RESULT=SCOPE_VIOLATION" "RESULT=SCOPE_VIOLATION" "$out"

export FAKE_TASK_EDIT="pnpm-lock.yaml:lock"
out="$("$TASK" run --name forb --task "$R/task.txt" --repo "$R" 2>"$R/forb.err")"
rc=$?
eq "edit of pnpm-lock.yaml -> exit 8" "8" "$rc"
has "pnpm-lock.yaml violation listed" "pnpm-lock.yaml" "$out"

out="$("$TASK" run --name allow --task "$R/task.txt" --repo "$R" --allow-path "pnpm-lock.yaml" 2>"$R/allow.err")"
rc=$?
eq "edit of pnpm-lock.yaml with --allow-path -> exit 0" "0" "$rc"
has "allow-path: RESULT=OK" "RESULT=OK" "$out"

export FAKE_TASK_EDIT="file.txt:mod"
out="$("$TASK" run --name noscope --task "$R/task.txt" --repo "$R" 2>"$R/noscope.err")"
rc=$?
eq "no --scope -> exit 0" "0" "$rc"
has "no --scope: summary says not checked" "scope: not checked (no --scope)" "$out"

# Setup failure and missing COPY_FILES source
R="$(task_repo)"
mkdir -p "$R/.agy-sessions"
cat <<'EOF' > "$R/.agy-sessions/agy-task.conf"
SETUP_CMDS=( 'echo setup_failure_message >&2; exit 1' )
COPY_FILES=()
EOF
echo "task" > "$R/task.txt"
export FAKE_TASK_EDIT="file.txt:should_not_run"
out="$("$TASK" run --name sfail --task "$R/task.txt" --repo "$R" 2>"$R/sfail.err")"
rc=$?
eq "setup failure -> exit 7" "7" "$rc"
has "setup failure: output tail shown on stderr" "setup_failure_message" "$(cat "$R/sfail.err")"
has "setup failure: summary RESULT=SETUP_FAILED" "RESULT=SETUP_FAILED" "$out"
eq "setup failure: stub agy-run never called" "no" "$([ -f "$R/.agy-sessions/sfail.jsonl" ] && echo yes || echo no)"

cat <<'EOF' > "$R/.agy-sessions/agy-task.conf"
SETUP_CMDS=()
COPY_FILES=( nonexistent.txt )
EOF
unset FAKE_TASK_EDIT
out="$("$TASK" run --name copymiss --task "$R/task.txt" --repo "$R" 2>"$R/copymiss.err")"
rc=$?
eq "missing COPY_FILES source -> exit 0" "0" "$rc"
has "missing COPY_FILES source: warning in stderr" "warning: copy source missing" "$(cat "$R/copymiss.err")"

# Stub agy-run exit codes (5, 4, 1)
R="$(task_repo)"
echo "task" > "$R/task.txt"
for code in 5 4 1; do
  export FAKE_TASK_EXIT="$code"
  out="$("$TASK" run --name "agyfail-$code" --task "$R/task.txt" --repo "$R" 2>"$R/agyfail-$code.err")"
  rc=$?
  eq "stub agy-run exit $code propagated" "$code" "$rc"
  has "stub agy-run exit $code: summary RESULT=AGY_FAILED" "RESULT=AGY_FAILED" "$out"
done
unset FAKE_TASK_EXIT

# Existing worktree and --reuse-worktree
R="$(task_repo)"
echo "task" > "$R/task.txt"
"$TASK" run --name reuse --task "$R/task.txt" --repo "$R" >/dev/null 2>&1
out="$("$TASK" run --name reuse --task "$R/task.txt" --repo "$R" 2>&1)"; rc=$?
eq "existing worktree without --reuse-worktree -> exit 2" "2" "$rc"
has "existing worktree: clear message" "worktree already exists" "$out"

out="$("$TASK" run --name reuse --task "$R/task.txt" --repo "$R" --reuse-worktree --no-setup 2>"$R/reuse.err")"; rc=$?
eq "existing worktree with --reuse-worktree --no-setup -> exit 0" "0" "$rc"

git -C "$R" worktree remove "$R/.worktrees/agy-reuse" >/dev/null 2>&1
out="$("$TASK" run --name reuse --task "$R/task.txt" --repo "$R" 2>&1)"; rc=$?
eq "branch exists while worktree does not -> exit 2" "2" "$rc"
has "branch exists while worktree does not: clear message" "branch agy/reuse exists" "$out"

# agy-task --resume
R="$(task_repo)"
mkdir -p "$R/.agy-sessions"
cat <<'EOF' > "$R/.agy-sessions/agy-task.conf"
SETUP_CMDS=( 'echo setup_done >> setup_marker.txt' )
COPY_FILES=()
EOF
SCRATCH="$(mktemp -d)"
TMPS+=("$SCRATCH")
echo "first task" > "$SCRATCH/task1.txt"
echo "correction task" > "$SCRATCH/task2.txt"

# Recording wrapper for agy-run
cat <<'EOF' > "$SCRATCH/record_run.sh"
#!/usr/bin/env bash
echo "$*" >> "$RECORD_LOG"
exec "$RECORD_TARGET" "$@"
EOF
chmod +x "$SCRATCH/record_run.sh"
export RECORD_LOG="$SCRATCH/agy_run_args.log"
export RECORD_TARGET="$FAKE_TASK_RUN"
export AGY_RUN="$SCRATCH/record_run.sh"

# (d) Normal first run: unchanged (no --conversation passed to agy-run)
export FAKE_TASK_EDIT="file.txt:first version"
out="$("$TASK" run --name res --task "$SCRATCH/task1.txt" --repo "$R" --scope "file.txt" 2>"$SCRATCH/res1.err")"
rc=$?
eq "normal run: exit 0" "0" "$rc"
eq "normal run: worktree created" "yes" "$([ -d "$R/.worktrees/agy-res" ] && echo yes || echo no)"
eq "normal run: setup executed" "setup_done" "$(cat "$R/.worktrees/agy-res/setup_marker.txt" 2>/dev/null || echo missing)"
run1_args="$(sed -n 1p "$RECORD_LOG")"
hasnt "normal run: agy-run called without --conversation" "--conversation" "$run1_args"
has "normal run: summary OK" "RESULT=OK" "$out"

# (b) Follow-up run with --resume:
# - reads conversation id of first run's init event in .agy-sessions/res.jsonl ("fake-conv-1")
# - passes --conversation fake-conv-1 to agy-run
# - implies --reuse-worktree and --no-setup
# - works on existing worktree
export FAKE_TASK_EDIT="file.txt:corrected version"
out="$("$TASK" run --name res --resume --task "$SCRATCH/task2.txt" --repo "$R" --scope "file.txt" 2>"$SCRATCH/res2.err")"
rc=$?
eq "resume run: exit 0" "0" "$rc"
run2_args="$(sed -n 2p "$RECORD_LOG")"
has "resume run: passes conversation id to agy-run" "--conversation fake-conv-1" "$run2_args"
eq "resume run: works on existing worktree" "corrected version" "$(cat "$R/.worktrees/agy-res/file.txt")"
eq "resume run: setup skipped (implied --no-setup)" "1" "$(wc -l < "$R/.worktrees/agy-res/setup_marker.txt" | tr -d ' ')"
res_prompt="$(cat "$R/.agy-sessions/res.prompt.txt")"
has "resume run: prompt contains new task" "correction task" "$res_prompt"
has "resume run: prompt contains HARD RULES" "HARD RULES" "$res_prompt"
has "resume run: prompt contains closing test reminder" "Do NOT run any test" "$res_prompt"

# (c) --resume with no previous log exits 2
out="$("$TASK" run --name nolog --resume --task "$SCRATCH/task1.txt" --repo "$R" 2>&1)"
rc=$?
eq "--resume with no previous log exits 2" "2" "$rc"
has "--resume with no previous log: clear message" "cannot resume: session log not found" "$out"

# --resume with log lacking conversation_id exits 2
echo '{"event":"other"}' > "$R/.agy-sessions/badlog.jsonl"
out="$("$TASK" run --name badlog --resume --task "$SCRATCH/task1.txt" --repo "$R" 2>&1)"
rc=$?
eq "--resume with no conversation id in log exits 2" "2" "$rc"
has "--resume with no conversation id: clear message" "cannot resume: no conversation id found" "$out"

unset AGY_RUN RECORD_LOG RECORD_TARGET FAKE_TASK_EDIT

# Invoked from inside a linked worktree
R="$(task_repo)"
echo "task" > "$R/task.txt"
mkdir -p "$R/.worktrees"
git -C "$R" worktree add "$R/.worktrees/wt-sub" -b wt-sub >/dev/null 2>&1
(
  cd "$R/.worktrees/wt-sub"
  "$TASK" run --name linked-wt --task "$R/task.txt" >/dev/null 2>"$R/linked-wt.err"
)
rc=$?
eq "invoked from inside linked worktree -> exit 0" "0" "$rc"
eq "invoked from inside linked worktree: worktree in main repo" "yes" "$([ -d "$R/.worktrees/agy-linked-wt" ] && echo yes || echo no)"
eq "invoked from inside linked worktree: sessions in main repo" "yes" "$([ -d "$R/.agy-sessions" ] && echo yes || echo no)"

# Baseline: setup modification not blamed on agy
R="$(task_repo)"
mkdir -p "$R/.agy-sessions"
cat <<'EOF' > "$R/.agy-sessions/agy-task.conf"
SETUP_CMDS=( 'echo setup_change >> file.txt' )
COPY_FILES=()
EOF
echo "task" > "$R/task.txt"
export FAKE_TASK_EDIT="other.txt:created_by_agy"
out="$("$TASK" run --name base-check --task "$R/task.txt" --repo "$R" --scope "other.txt" 2>"$R/base-check.err")"
rc=$?
eq "baseline: setup modification not blamed on agy -> exit 0" "0" "$rc"
has "baseline: summary RESULT=OK" "RESULT=OK" "$out"
hasnt "baseline: file.txt not in violations" "violation: file.txt" "$out"

# Regression tests for defects

# Defect 2: agy commit bypasses scope check
# 2a: agy commits an in-scope edit
R="$(task_repo)"
echo "task" > "$R/task.txt"
export AGY_RUN="$FAKE_TASK_RUN"
export FAKE_TASK_EDIT="file.txt:commit_edit"
export FAKE_TASK_COMMIT=1
out="$("$TASK" run --name cminscope --task "$R/task.txt" --repo "$R" --scope "file.txt" 2>"$R/cminscope.err")"
rc=$?
eq "committed in-scope edit -> exit 8" "8" "$rc"
has "committed in-scope edit: HEAD-moved violation" "violation: agy moved HEAD (committed):" "$out"
has "committed in-scope edit: file listed under changed files" "file.txt" "$out"
has "committed in-scope edit: RESULT=SCOPE_VIOLATION" "RESULT=SCOPE_VIOLATION" "$out"
hasnt "committed in-scope edit: file.txt not flagged as outside scope" "outside scope" "$out"

# 2b: agy commits an out-of-scope file and a pnpm-lock.yaml
R="$(task_repo)"
echo "task" > "$R/task.txt"
export AGY_RUN="$FAKE_TASK_RUN"
export FAKE_TASK_EDIT=$'other.txt:out_scope\npnpm-lock.yaml:lock'
export FAKE_TASK_COMMIT=1
out="$("$TASK" run --name cmoutscope --task "$R/task.txt" --repo "$R" --scope "file.txt" 2>"$R/cmoutscope.err")"
rc=$?
eq "committed out-of-scope and forbidden -> exit 8" "8" "$rc"
has "committed out-of-scope: HEAD-moved violation" "violation: agy moved HEAD (committed):" "$out"
has "committed out-of-scope: other.txt flagged" "violation: other.txt (outside scope)" "$out"
has "committed forbidden: pnpm-lock.yaml flagged" "violation: pnpm-lock.yaml" "$out"
unset FAKE_TASK_COMMIT FAKE_TASK_EDIT

# Defect 4: agy-run stdout noise does not leak into agy-task stdout
R="$(task_repo)"
echo "task" > "$R/task.txt"
export AGY_RUN="$FAKE_TASK_RUN"
export FAKE_STDOUT_NOISE="noisy stdout from agy-run"
out="$("$TASK" run --name noise --task "$R/task.txt" --repo "$R" 2>"$R/noise.err")"
rc=$?
eq "stdout noise: exit 0" "0" "$rc"
summary_file="$(cat "$R/.agy-sessions/noise.summary.txt")"
eq "stdout noise: agy-task stdout byte-identical to summary file" "$summary_file" "$out"
has "stdout noise: noise redirected to stderr" "noisy stdout from agy-run" "$(cat "$R/noise.err")"
unset FAKE_STDOUT_NOISE

# Defect 5: Worktree handling
# 5a: git worktree add failure captures and logs stderr
R="$(task_repo)"
echo "task" > "$R/task.txt"
touch "$R/.git/worktrees"
out="$("$TASK" run --name wtfail --task "$R/task.txt" --repo "$R" 2>&1)"; rc=$?
eq "git worktree add failure -> exit 2" "2" "$rc"
has "git worktree add failure: error logged" "failed to create worktree" "$out"
has "git worktree add failure: git stderr captured" "fatal: could not create leading directories" "$out"
rm -f "$R/.git/worktrees"

# 5b: Reusing invalid worktree paths with --reuse-worktree
R="$(task_repo)"
echo "task" > "$R/task.txt"
mkdir -p "$R/.worktrees"
touch "$R/.worktrees/agy-reuse-file"
out="$("$TASK" run --name reuse-file --task "$R/task.txt" --repo "$R" --reuse-worktree 2>&1)"; rc=$?
eq "reuse file as worktree -> exit 2" "2" "$rc"
has "reuse file: clear error message" "existing path is not a git worktree" "$out"

mkdir -p "$R/.worktrees/agy-reuse-dir"
out="$("$TASK" run --name reuse-dir --task "$R/task.txt" --repo "$R" --reuse-worktree 2>&1)"; rc=$?
eq "reuse plain dir as worktree -> exit 2" "2" "$rc"
has "reuse plain dir: clear error message" "existing path is not a git worktree" "$out"

R_OTHER="$(task_repo)"
git -C "$R_OTHER" worktree add -b foreign "$R/.worktrees/agy-reuse-foreign" HEAD >/dev/null 2>&1
out="$("$TASK" run --name reuse-foreign --task "$R/task.txt" --repo "$R" --reuse-worktree 2>&1)"; rc=$?
eq "reuse worktree of foreign repo -> exit 2" "2" "$rc"
has "reuse foreign worktree: clear error message" "does not belong to main repository" "$out"

# Defect 6: errexit and untracked files on AGY_FAILED
# 6a: AGY_FAILED lists untracked files under changed files
R="$(task_repo)"
echo "task" > "$R/task.txt"
export AGY_RUN="$FAKE_TASK_RUN"
export FAKE_TASK_EXIT=1
export FAKE_TASK_EDIT="untracked_fail.txt:created"
out="$("$TASK" run --name agyfail-untracked --task "$R/task.txt" --repo "$R" 2>"$R/agyfail-untracked.err")"
rc=$?
eq "stub agy-run exit 1 with untracked file: exit 1" "1" "$rc"
has "stub agy-run exit 1: summary shows untracked file" "?? untracked_fail.txt" "$out"
unset FAKE_TASK_EXIT FAKE_TASK_EDIT

# 6b: no set -e / set +e re-enables in agy-task
eq "no set -e re-enables in agy-task" "0" "$(grep -c 'set -e' "$TASK" || true)"
eq "no set +e in agy-task" "0" "$(grep -c 'set +e' "$TASK" || true)"

# agy-task rm tests
# 1. clean worktree whose branch has no unique commits -> removed without -f, logs/summary kept, prompt file gone
R="$(task_repo)"
echo "task" > "$R/task.txt"
export AGY_RUN="$FAKE_TASK_RUN"
"$TASK" run --name rmclean --task "$R/task.txt" --repo "$R" >/dev/null 2>&1
eq "rm clean: run exit 0" "0" "$?"
eq "rm clean: worktree exists before rm" "yes" "$([ -d "$R/.worktrees/agy-rmclean" ] && echo yes || echo no)"
eq "rm clean: prompt file exists before rm" "yes" "$([ -f "$R/.agy-sessions/rmclean.prompt.txt" ] && echo yes || echo no)"
out="$("$TASK" rm rmclean --repo "$R" 2>"$R/rmclean.err")"; rc=$?
eq "rm clean: exit 0" "0" "$rc"
eq "rm clean: stdout line" "removed: worktree $R/.worktrees/agy-rmclean, branch agy/rmclean" "$out"
has "rm clean: stderr has progress" "[agy-task] removing worktree" "$(cat "$R/rmclean.err")"
eq "rm clean: worktree gone" "no" "$([ -e "$R/.worktrees/agy-rmclean" ] && echo yes || echo no)"
eq "rm clean: branch gone" "no" "$(git -C "$R" show-ref --verify --quiet "refs/heads/agy/rmclean" && echo yes || echo no)"
eq "rm clean: prompt file gone" "no" "$([ -f "$R/.agy-sessions/rmclean.prompt.txt" ] && echo yes || echo no)"
eq "rm clean: summary kept" "yes" "$([ -f "$R/.agy-sessions/rmclean.summary.txt" ] && echo yes || echo no)"
eq "rm clean: jsonl kept" "yes" "$([ -f "$R/.agy-sessions/rmclean.jsonl" ] && echo yes || echo no)"
eq "rm clean: setup log kept" "yes" "$([ -f "$R/.agy-sessions/rmclean.setup.log" ] && echo yes || echo no)"

# 2. dirty worktree -> refused (exit 2, worktree still there), with -f removed
R="$(task_repo)"
echo "task" > "$R/task.txt"
"$TASK" run --name rmdirty --task "$R/task.txt" --repo "$R" >/dev/null 2>&1
echo "dirty edit" >> "$R/.worktrees/agy-rmdirty/file.txt"
out="$("$TASK" rm rmdirty --repo "$R" 2>"$R/rmdirty.err")"; rc=$?
eq "rm dirty without -f -> exit 2" "2" "$rc"
has "rm dirty: stderr mentions uncommitted" "uncommitted changes" "$(cat "$R/rmdirty.err")"
has "rm dirty: stderr mentions -f" "-f" "$(cat "$R/rmdirty.err")"
eq "rm dirty: worktree still there" "yes" "$([ -d "$R/.worktrees/agy-rmdirty" ] && echo yes || echo no)"
out="$("$TASK" rm rmdirty -f --repo "$R" 2>"$R/rmdirty_force.err")"; rc=$?
eq "rm dirty with -f -> exit 0" "0" "$rc"
eq "rm dirty: worktree gone with -f" "no" "$([ -e "$R/.worktrees/agy-rmdirty" ] && echo yes || echo no)"
eq "rm dirty: branch gone with -f" "no" "$(git -C "$R" show-ref --verify --quiet "refs/heads/agy/rmdirty" && echo yes || echo no)"

# 3. untracked non-ignored file -> refused
R="$(task_repo)"
echo "task" > "$R/task.txt"
"$TASK" run --name rmuntracked --task "$R/task.txt" --repo "$R" >/dev/null 2>&1
echo "untracked" > "$R/.worktrees/agy-rmuntracked/untracked.txt"
out="$("$TASK" rm rmuntracked --repo "$R" 2>"$R/rmuntracked.err")"; rc=$?
eq "rm untracked file without -f -> exit 2" "2" "$rc"
has "rm untracked: stderr mentions untracked" "untracked files" "$(cat "$R/rmuntracked.err")"
has "rm untracked: stderr mentions -f" "-f" "$(cat "$R/rmuntracked.err")"
eq "rm untracked: worktree still there" "yes" "$([ -d "$R/.worktrees/agy-rmuntracked" ] && echo yes || echo no)"
"$TASK" rm rmuntracked -f --repo "$R" >/dev/null 2>&1
eq "rm untracked with -f: worktree gone" "no" "$([ -e "$R/.worktrees/agy-rmuntracked" ] && echo yes || echo no)"

# 4. branch with an unmerged commit -> refused, with -f removed
R="$(task_repo)"
echo "task" > "$R/task.txt"
"$TASK" run --name rmunmerged --task "$R/task.txt" --repo "$R" >/dev/null 2>&1
echo "commit edit" >> "$R/.worktrees/agy-rmunmerged/file.txt"
git -C "$R/.worktrees/agy-rmunmerged" -c user.name=t -c user.email=t@t commit -am "unique commit" >/dev/null
out="$("$TASK" rm rmunmerged --repo "$R" 2>"$R/rmunmerged.err")"; rc=$?
eq "rm unmerged branch without -f -> exit 2" "2" "$rc"
has "rm unmerged: stderr mentions not reachable" "not reachable" "$(cat "$R/rmunmerged.err")"
has "rm unmerged: stderr mentions -f" "-f" "$(cat "$R/rmunmerged.err")"
eq "rm unmerged: worktree still there" "yes" "$([ -d "$R/.worktrees/agy-rmunmerged" ] && echo yes || echo no)"
eq "rm unmerged: branch still there" "yes" "$(git -C "$R" show-ref --verify --quiet "refs/heads/agy/rmunmerged" && echo yes || echo no)"
out="$("$TASK" rm rmunmerged -f --repo "$R" 2>/dev/null)"; rc=$?
eq "rm unmerged with -f -> exit 0" "0" "$rc"
eq "rm unmerged: worktree gone with -f" "no" "$([ -e "$R/.worktrees/agy-rmunmerged" ] && echo yes || echo no)"
eq "rm unmerged: branch gone with -f" "no" "$(git -C "$R" show-ref --verify --quiet "refs/heads/agy/rmunmerged" && echo yes || echo no)"

# 5. worktree gone but branch left -> branch removed
R="$(task_repo)"
git -C "$R" branch agy/wtgone
out="$("$TASK" rm wtgone --repo "$R" 2>"$R/wtgone.err")"; rc=$?
eq "rm worktree gone branch left: exit 0" "0" "$rc"
eq "rm worktree gone branch left: stdout" "removed: branch agy/wtgone" "$out"
eq "rm worktree gone branch left: branch gone" "no" "$(git -C "$R" show-ref --verify --quiet "refs/heads/agy/wtgone" && echo yes || echo no)"

# 6. nothing exists -> exit 2
R="$(task_repo)"
out="$("$TASK" rm nothing --repo "$R" 2>"$R/nothing.err")"; rc=$?
eq "rm nothing exists -> exit 2" "2" "$rc"
has "rm nothing exists: stderr mentions nothing to remove" "nothing to remove" "$(cat "$R/nothing.err")"

# 7. invalid NAME -> exit 2
R="$(task_repo)"
"$TASK" rm BAD_NAME --repo "$R" >/dev/null 2>&1
eq "rm bad name (uppercase) -> exit 2" "2" "$?"
"$TASK" rm bad_name --repo "$R" >/dev/null 2>&1
eq "rm bad name (underscore) -> exit 2" "2" "$?"
"$TASK" rm --repo "$R" >/dev/null 2>&1
eq "rm missing name -> exit 2" "2" "$?"

# 8. called from inside a linked worktree -> resolves to the main checkout
R="$(task_repo)"
echo "task" > "$R/task.txt"
"$TASK" run --name rmtarget --task "$R/task.txt" --repo "$R" >/dev/null 2>&1
mkdir -p "$R/.worktrees"
git -C "$R" worktree add -b agy/caller "$R/.worktrees/agy-caller" HEAD >/dev/null 2>&1
out="$( (cd "$R/.worktrees/agy-caller" && "$TASK" rm rmtarget 2>"$R/rmtarget.err") )"; rc=$?
eq "rm inside linked worktree: exit 0" "0" "$rc"
eq "rm inside linked worktree: stdout" "removed: worktree $R/.worktrees/agy-rmtarget, branch agy/rmtarget" "$out"
eq "rm inside linked worktree: worktree gone" "no" "$([ -e "$R/.worktrees/agy-rmtarget" ] && echo yes || echo no)"
eq "rm inside linked worktree: branch gone" "no" "$(git -C "$R" show-ref --verify --quiet "refs/heads/agy/rmtarget" && echo yes || echo no)"
git -C "$R" worktree remove --force "$R/.worktrees/agy-caller" >/dev/null 2>&1
git -C "$R" branch -D agy/caller >/dev/null 2>&1

# agy-task usage log tests
R="$(task_repo)"
echo "task" > "$R/task.txt"

# First run: header + 1 line with tokens 12345
"$TASK" run --name ulog1 --task "$R/task.txt" --repo "$R" >/dev/null 2>&1
eq "usage log: file exists" "yes" "$([ -f "$R/.agy-sessions/usage.tsv" ] && echo yes || echo no)"
expected_hdr=$'timestamp\tname\tresult\tagy_status\tturns\ttokens\tagy_seconds\texit_code'
actual_hdr="$(head -n 1 "$R/.agy-sessions/usage.tsv")"
eq "usage log: header line matches" "$expected_hdr" "$actual_hdr"
eq "usage log: line count after run 1" "2" "$(wc -l < "$R/.agy-sessions/usage.tsv" | tr -d ' ')"
line1_data="$(sed -n '2p' "$R/.agy-sessions/usage.tsv")"
eq "usage log run 1: name" "ulog1" "$(echo "$line1_data" | cut -f2)"
eq "usage log run 1: result" "RESULT=OK" "$(echo "$line1_data" | cut -f3)"
eq "usage log run 1: tokens" "12345" "$(echo "$line1_data" | cut -f6)"
eq "usage log run 1: exit code" "0" "$(echo "$line1_data" | cut -f8)"

# Second run appends (header still once)
"$TASK" run --name ulog2 --task "$R/task.txt" --repo "$R" >/dev/null 2>&1
eq "usage log: line count after run 2" "3" "$(wc -l < "$R/.agy-sessions/usage.tsv" | tr -d ' ')"
actual_hdr2="$(head -n 1 "$R/.agy-sessions/usage.tsv")"
eq "usage log: header line still once" "$expected_hdr" "$actual_hdr2"
line2_data="$(sed -n '3p' "$R/.agy-sessions/usage.tsv")"
eq "usage log run 2: name" "ulog2" "$(echo "$line2_data" | cut -f2)"
eq "usage log run 2: result" "RESULT=OK" "$(echo "$line2_data" | cut -f3)"
eq "usage log run 2: exit code" "0" "$(echo "$line2_data" | cut -f8)"

# Setup failure appends line with exit code 7
cat <<'EOF' > "$R/.agy-sessions/agy-task.conf"
SETUP_CMDS=( 'exit 1' )
EOF
"$TASK" run --name ulog-sfail --task "$R/task.txt" --repo "$R" >/dev/null 2>&1
eq "usage log: line count after setup fail" "4" "$(wc -l < "$R/.agy-sessions/usage.tsv" | tr -d ' ')"
line3_data="$(sed -n '4p' "$R/.agy-sessions/usage.tsv")"
eq "usage log sfail: name" "ulog-sfail" "$(echo "$line3_data" | cut -f2)"
eq "usage log sfail: result" "RESULT=SETUP_FAILED" "$(echo "$line3_data" | cut -f3)"
eq "usage log sfail: agy_status" "not run" "$(echo "$line3_data" | cut -f4)"
eq "usage log sfail: turns" "-" "$(echo "$line3_data" | cut -f5)"
eq "usage log sfail: tokens" "-" "$(echo "$line3_data" | cut -f6)"
eq "usage log sfail: exit code" "7" "$(echo "$line3_data" | cut -f8)"
rm -f "$R/.agy-sessions/agy-task.conf"

# agy-run failure appends line with right exit code
export FAKE_TASK_EXIT=1
"$TASK" run --name ulog-afail --task "$R/task.txt" --repo "$R" >/dev/null 2>&1
eq "usage log: line count after agy fail" "5" "$(wc -l < "$R/.agy-sessions/usage.tsv" | tr -d ' ')"
line4_data="$(sed -n '5p' "$R/.agy-sessions/usage.tsv")"
eq "usage log afail: name" "ulog-afail" "$(echo "$line4_data" | cut -f2)"
eq "usage log afail: result" "RESULT=AGY_FAILED" "$(echo "$line4_data" | cut -f3)"
eq "usage log afail: exit code" "1" "$(echo "$line4_data" | cut -f8)"
unset FAKE_TASK_EXIT

unset AGY_RUN

echo "== install scripts (into temp bin dirs, never the real ~/.local/bin)"
INST="$(mktemp -d)"; TMPS+=("$INST")
REPO_ABS="$(cd "$HERE/.." && pwd)"
if bash "$HERE/../linux/install.sh" "$INST/lin" >/dev/null 2>&1; then pass "linux/install.sh runs"; else fail "linux/install.sh runs"; fi
eq "linux/install.sh links agyr to bin/agyr" "$REPO_ABS/bin/agyr" "$(readlink -f "$INST/lin/agyr")"
has "linked agyr answers help" "agyr" "$("$INST/lin/agyr" help 2>&1 | head -1)"
mkdir -p "$INST/guard" && echo mine >"$INST/guard/agyr"
if bash "$HERE/../linux/install.sh" "$INST/guard" >/dev/null 2>&1; then fail "linux/install.sh refuses to replace a regular file"; else pass "linux/install.sh refuses to replace a regular file"; fi
eq "the regular file is left as it was" "mine" "$(cat "$INST/guard/agyr")"
if bash "$HERE/../windows/install.sh" "$INST/win" >/dev/null 2>&1; then pass "windows/install.sh writes the wrappers"; else fail "windows/install.sh writes the wrappers"; fi
has "windows wrapper points at this clone's bin/agyr" "exec \"$REPO_ABS/bin/agyr\"" "$(cat "$INST/win/agyr")"
has "windows wrapper answers help" "agyr" "$("$INST/win/agyr" help 2>&1 | head -1)"

echo "== safety"
real_agy_busy && REAL_BUSY=1
if [ "$REAL_BUSY" = 1 ]; then
  echo "  skip the real token mtime check: real agy / agy-run processes are running and rewrite that file themselves"
else
  eq "the real token is untouched (mtime)" "$REAL_MTIME_BEFORE" "$(stat -c %Y "$REAL_TOKEN" 2>/dev/null || echo none)"
fi
# static guarantee, valid even when the check above is skipped: no test code points at the real agy directory
eq "no test code hard-codes the real agy directory (only the read-only REAL_TOKEN probe)" "0" "$(grep -n '\.gemini' "$HERE/run.sh" "$HERE/fake-agy" | grep -vc -e 'REAL_TOKEN=' -e 'hard-codes the real agy directory')"

echo
echo "result: $PASS pass, $FAIL fail"
[ "$FAIL" -eq 0 ]
