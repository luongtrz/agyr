#!/usr/bin/env bash
# Independent core test section.
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$TEST_DIR/lib.sh"

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

# agy leaves ANOTHER account's login in the temp HOME (the 2026-10-09 symptom: acc2's slot ended up with acc1's login):
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

exit 0
