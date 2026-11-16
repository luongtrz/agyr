#!/usr/bin/env bash
# Independent core test section.
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$TEST_DIR/lib.sh"

echo "== list: weekly limit used up (the 5-hour line is 'disabled', not a failure)"
setup
export FAKE_WEEKLY_HIT_TOKENS="tok-acc2"
out="$("$ACCT" list 2>&1)"; rc=$?
row2="$(grep '  acc2 ' <<<"$out")"
eq "weekly limit used up: exit 0, not a measuring failure" "0" "$rc"
hasnt "weekly limit used up: not reported as 'measure failed'" "measure failed" "$out"
has "weekly limit used up: status says so, with the time left" "weekly limit reached, 72h00m left" "$row2"
has "weekly limit used up: the 5-hour column says off" " off " "$row2"
has "weekly limit used up: the weekly column shows 0%" "0%" "$row2"
eq "weekly limit used up: cooldown until the weekly reset (1000000 + 3 days)" "$((1000000 + 259200))" "$(cd_of acc2)"
eq "weekly limit used up: the snapshot marks the 5-hour limit as disabled (-1)" "-1" "$(jq -r .quota.acc2.g5 "$AGY_HOME/accounts/state.json")"
eq "weekly limit used up: next skips the account" "acc3" "$("$ACCT" next)"
has "the other accounts are measured as usual" "60%" "$(grep '\* acc1' <<<"$out")"
out="$("$ACCT" list -c)"
has "list -c: same status from the saved data" "weekly limit reached" "$(grep '  acc2 ' <<<"$out")"
hasnt "list -c: not stale" "stale" "$(grep '  acc2 ' <<<"$out")"
out="$(AGYR_COLOR=always "$ACCT" list -c)"
has "the weekly-limit status is red" "${ESC:-$'\033'}[31mweekly limit reached" "$out"
# the rest of the line keeps its alignment: same width as an ordinary row
eq "weekly limit used up: the row is as wide as the others up to the status" "$(grep '  acc3 ' <<<"$("$ACCT" list -c)" | cut -c1-70 | wc -c | tr -d ' ')" "$(grep '  acc2 ' <<<"$("$ACCT" list -c)" | cut -c1-70 | wc -c | tr -d ' ')"
# agyr test on such an account never prints the marker
export FAKE_HI_ERROR_TOKENS="tok-acc2"
out="$("$ACCT" test acc2 2>/dev/null)"
hasnt "test: the -1 marker never reaches the screen" "-1%" "$out"
has "test: the 5-hour limit of that account is shown as off" "off" "$(grep '  acc2 ' <<<"$out")"
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

exit 0
