#!/usr/bin/env bash
# Independent core test section.
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$TEST_DIR/lib.sh"

echo "== agyr"

setup
out="$("$ACCT" list -c)"
has "list -c: acc1 is active" "* acc1" "$out"
has "list -c: acc2 is listed" "  acc2" "$out"
eq "active = acc1" "acc1" "$("$ACCT" active)"
if [ "$ON_WINDOWS" = 1 ]; then
  echo "  skip file modes 600/700: NTFS has no POSIX permission bits (the profile folder's ACL protects the files)"
else
  eq "slot mode is 600" "600" "$(stat -c %a "$AGY_HOME/accounts/acc1.token")"
  eq "accounts dir mode is 700" "700" "$(stat -c %a "$AGY_HOME/accounts")"
fi
eq "token is correct after use" "tok-acc1" "$(cat "$AGY_HOME/antigravity-oauth-token")"

out="$("$ACCT" save acc9 2>&1)"; hasnt "save does not print the token" "tok-" "$out"
"$ACCT" use acc1 >/dev/null

setup
for a in acc1 acc2 acc3; do jtok "$a" "at-$a" >"$AGY_HOME/antigravity-oauth-token"; "$ACCT" save "$a" >/dev/null; done
"$ACCT" use acc1 >/dev/null
jtok acc1 "at-acc1-refreshed" >"$AGY_HOME/antigravity-oauth-token" # agy refreshed the access token itself (refresh_token unchanged)
out="$("$ACCT" use acc2 2>&1)"
hasnt "use does not print the token" "at-acc" "$out"
eq "use: token = slot acc2" "at-acc2" "$(jq -r .token.access_token "$AGY_HOME/antigravity-oauth-token")"
eq "use: refreshed token synced back to acc1" "at-acc1-refreshed" "$(jq -r .token.access_token "$AGY_HOME/accounts/acc1.token")"
eq "use: token backed up before overwrite" "at-acc1-refreshed" "$(jq -r .token.access_token "$AGY_HOME/accounts/.last-token.bak")"
eq "use: active = acc2" "acc2" "$("$ACCT" active)"

"$ACCT" use nope >/dev/null 2>&1; eq "use of a missing slot -> error" "1" "$?"
"$ACCT" use '../x' >/dev/null 2>&1; eq "invalid account name -> error" "1" "$?"
"$ACCT" bogus >/dev/null 2>&1; eq "unknown command -> exit 2" "2" "$?"

exit 0
