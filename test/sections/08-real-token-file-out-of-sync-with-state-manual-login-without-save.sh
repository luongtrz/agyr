#!/usr/bin/env bash
# Independent core test section.
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$TEST_DIR/lib.sh"

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

exit 0
