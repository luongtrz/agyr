#!/usr/bin/env bash
# Independent core test section.
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$TEST_DIR/lib.sh"

echo "== list: Gemini 4 Argon limits (only some accounts have them)"
setup
"$ACCT" list >/dev/null 2>&1
out="$(AGYR_COLOR=never "$ACCT" list -c)"
hasnt "argon: no ARGON column when no account reports it" "ARGON" "$out"
setup
out="$(FAKE_ARGON_TOKENS="tok-acc2" AGYR_COLOR=never "$ACCT" list 2>&1)"
has "argon: ARGON WEEK column appears" "ARGON WEEK" "$out"
hasnt "argon: no ARGON 5H column without an Argon five-hour line" "ARGON 5H" "$out"
has "argon: acc2 weekly = 45% (60-15)" " 45%" "$out"
eq "argon: state keeps aw for acc2" "45" "$(jq -r '.quota.acc2.aw' "$AGY_HOME/accounts/state.json")"
eq "argon: state has no aw for acc1" "null" "$(jq -r '.quota.acc1.aw' "$AGY_HOME/accounts/state.json")"
eq "argon: gemini numbers unaffected (acc2 5h = 70)" "70" "$(jq -r '.quota.acc2.g5' "$AGY_HOME/accounts/state.json")"
cached="$(AGYR_COLOR=never "$ACCT" list -c)"
has "argon: list -c shows the saved ARGON WEEK column" "ARGON WEEK" "$cached"
setup
out="$(FAKE_ARGON_TOKENS="tok-acc2 tok-acc3" FAKE_ARGON_5H=1 AGYR_COLOR=never "$ACCT" list 2>&1)"
has "argon: ARGON 5H column appears with a five-hour line" "ARGON 5H" "$out"
eq "argon: state keeps a5 for acc3" "75" "$(jq -r '.quota.acc3.a5' "$AGY_HOME/accounts/state.json")"

exit 0
