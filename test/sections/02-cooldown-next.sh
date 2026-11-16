#!/usr/bin/env bash
# Independent core test section.
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$TEST_DIR/lib.sh"

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

exit 0
