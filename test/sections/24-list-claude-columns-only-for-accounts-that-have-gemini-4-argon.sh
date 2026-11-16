#!/usr/bin/env bash
# Independent core test section.
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$TEST_DIR/lib.sh"

echo "== list: Claude columns only for accounts that have Gemini 4 Argon"
setup
out="$(AGYR_COLOR=never "$ACCT" list 2>&1)"
hasnt "claude: no CLAUDE column when no account has Argon" "CLAUDE" "$out"
eq "claude: not stored without Argon (acc1)" "null" "$(jq -r '.quota.acc1.cw' "$AGY_HOME/accounts/state.json")"
setup
out="$(FAKE_ARGON_TOKENS="tok-acc2" AGYR_COLOR=never "$ACCT" list 2>&1)"
hasnt "claude: no CLAUDE column by default in agyr list" "CLAUDE" "$out"
eq "claude: stored for the Argon account (acc2 cw=100)" "100" "$(jq -r '.quota.acc2.cw' "$AGY_HOME/accounts/state.json")"
eq "claude: not stored for the non-Argon account (acc1)" "null" "$(jq -r '.quota.acc1.cw' "$AGY_HOME/accounts/state.json")"
out="$(FAKE_ARGON_TOKENS="tok-acc2" AGYR_COLOR=never "$ACCT" list --claude 2>&1)"
has "claude: CLAUDE WEEK column appears with --claude" "CLAUDE WEEK" "$out"
has "claude: CLAUDE 5H column appears with --claude" "CLAUDE 5H" "$out"

exit 0
