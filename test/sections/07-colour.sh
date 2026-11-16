#!/usr/bin/env bash
# Independent core test section.
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$TEST_DIR/lib.sh"

echo "== colour"
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

exit 0
