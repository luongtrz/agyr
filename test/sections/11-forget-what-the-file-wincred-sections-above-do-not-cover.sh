#!/usr/bin/env bash
# Independent core test section.
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$TEST_DIR/lib.sh"

echo "== forget (what the file/wincred sections above do not cover)"
setup
n0="$(lines)"
out="$("$ACCT" forget 2>&1)"
has "forget: tells to log in with agyr (a bare agy would use the keyring)" "run 'agyr' to log in" "$out"
eq "forget: the active mark is cleared" "" "$(jq -r .active "$AGY_HOME/accounts/state.json")"
eq "forget: 'agyr active' prints nothing" "" "$("$ACCT" active)"
for a in acc1 acc2 acc3; do eq "forget: slot $a is kept" "tok-$a" "$(cat "$AGY_HOME/accounts/$a.token")"; done
eq "forget: agy is not started" "$n0" "$(lines)"
out="$("$ACCT" list -c 2>&1)"; rc=$?
eq "forget: list -c still works" "0" "$rc"
hasnt "forget: nothing is marked * (no login)" "* acc" "$out"
runit; rc=$?
eq "forget: agy-run refuses to start without a login (exit 4)" "4" "$rc"
eq "forget: agy-run did not start agy" "$n0" "$(lines)"
"$ACCT" use acc2 >/dev/null
eq "forget: 'use' logs in again from a slot" "tok-acc2" "$(cat "$AGY_HOME/antigravity-oauth-token")"
eq "forget: and active is acc2 again" "acc2" "$("$ACCT" active)"

# -f is accepted like --force
setup
for a in acc1 acc2 acc3; do jtok "$a" "at-$a" >"$AGY_HOME/antigravity-oauth-token"; "$ACCT" save "$a" >/dev/null; done
jtok brandnew "at-new" >"$AGY_HOME/antigravity-oauth-token"
"$ACCT" forget >/dev/null 2>&1; eq "forget: an unsaved login is refused (exit 1)" "1" "$?"
eq "forget: the unsaved login is still there after the refusal" "at-new" "$(jq -r .token.access_token "$AGY_HOME/antigravity-oauth-token")"
"$ACCT" forget -f >/dev/null 2>&1; eq "forget -f: accepted like --force (exit 0)" "0" "$?"
eq "forget -f: the token file is gone" "no" "$([ -e "$AGY_HOME/antigravity-oauth-token" ] && echo yes || echo no)"
eq "forget -f: a copy of the dropped login is in .last-token.bak" "at-new" "$(jq -r .token.access_token "$AGY_HOME/accounts/.last-token.bak")"
eq "forget -f: no slot was overwritten" "rt-acc1" "$(jq -r .token.refresh_token "$AGY_HOME/accounts/acc1.token")"

# no login at all still clears the active mark
setup
rm -f "$AGY_HOME/antigravity-oauth-token"
"$ACCT" forget >/dev/null 2>&1; eq "forget without a login: exit 0" "0" "$?"

# usage, help and side effects
setup
out="$("$ACCT" forget extra 2>&1)"; rc=$?
eq "forget with an extra argument -> exit 2" "2" "$rc"
has "forget with an extra argument: usage" "usage: agyr forget [-f|--force]" "$out"
eq "forget with an extra argument: token file untouched" "tok-acc1" "$(cat "$AGY_HOME/antigravity-oauth-token")"
"$ACCT" forget --help >/dev/null 2>&1
eq "forget --help does not forget anything" "tok-acc1" "$(cat "$AGY_HOME/antigravity-oauth-token")"
out="$("$ACCT" help forget)"
has "help forget: mentions -f" "-f / --force" "$out"
has "help forget: says to log in with agyr, not a bare agy" "not a bare 'agy'" "$out"
has "help forget: mentions the active mark" "\"active\" mark" "$out"

exit 0
