#!/usr/bin/env bash
# Independent core test section.
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$TEST_DIR/lib.sh"

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

exit 0
