#!/usr/bin/env bash
# Independent core test section.
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$TEST_DIR/lib.sh"

echo "== list: rows ordered by the weekly reset time"
order_of() { grep -oE '[│ ]*[ *] +acc[0-9]' <<<"$1" | tr -d '│ *' | tr '\n' ' '; }
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
eq "list: the table has one row per account plus the header" "4" "$("$ACCT" list -c | grep -cE '[│ ]*(ACCOUNT|acc[0-9])')"
has "list: header separator" "├" "$("$ACCT" list -c)"
unset FAKE_WEEK_ORDER
has "help list: says how the rows are ordered" "ordered by when the weekly limit resets" "$("$ACCT" help list)"

exit 0
