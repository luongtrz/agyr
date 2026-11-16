#!/usr/bin/env bash
# Independent core test section.
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$TEST_DIR/lib.sh"

echo "== test (Hi to every account)"
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
has "test: header separator" "├" "$out"
eq "test: each Hi uses its own account's login, not the keyring's" "tok-acc1 tok-acc2 tok-acc3 " "$(hi_lines | cut -d'|' -f1 | sort | tr '\n' ' ')"
eq "test: every Hi uses gemini-3.8-flash-low (lowest effort)" "3" "$(hi_lines | grep -c -- '--model gemini-3.8-flash-low')"
eq "test: no Hi uses a higher-effort gemini model" "0" "$(hi_lines | grep -c -- '--model gemini-3.8-flash-\(high\|medium\)')"
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
hasnt "test: no '(was ...)' on the account's row when the reset time did not move" "(was" "$(grep '  acc1 ' <<<"$out")"
setup
export FAKE_HI_SHIFT=1
out="$("$ACCT" test acc1 2>/dev/null)"
has "test: the new reset time is shown (09:46 PM + 10 min)" "09:56 PM" "$(grep '  acc1 ' <<<"$out")"
has "test: and the time before it, because the Hi moved it" "(was 09:46 PM)" "$(grep '  acc1 ' <<<"$out")"
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
eq "test: no fake-agy process left behind" "0" "$(leaked_fake_agy)"
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
has "help test: names the model" "gemini-3.8-flash-low" "$out"
has "help test: says the window idea is an assumption to check" "THAT IS AN ASSUMPTION" "$out"
hasnt "help test: no unsupported claim that was observed" "Observed:" "$out"
has "help test: documents the timeout variable" "AGYR_TEST_TIMEOUT" "$out"
has "overview describes test" "Send \"Hi\" to every account" "$("$ACCT" help)"

exit 0
