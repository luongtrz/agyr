#!/usr/bin/env bash
# Independent core test section.
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$TEST_DIR/lib.sh"

echo "== del (rm)"
setup
"$ACCT" list >/dev/null 2>&1
"$ACCT" cooldown acc2 2h >/dev/null
out="$("$ACCT" del acc2 2>&1)"; rc=$?
eq "del non-active: exit 0" "0" "$rc"
has "del non-active: confirms" "deleted account 'acc2'" "$out"
hasnt "del non-active: does not say cleared active" "cleared active" "$out"
eq "del non-active: acc2.token is removed" "no" "$([ -e "$AGY_HOME/accounts/acc2.token" ] && echo yes || echo no)"
eq "del non-active: cooldown for acc2 removed" "0" "$(cd_of acc2)"
eq "del non-active: quota for acc2 removed" "null" "$(jq -r '.quota.acc2 // null' "$AGY_HOME/accounts/state.json")"
eq "del non-active: active account acc1 untouched" "acc1" "$("$ACCT" active)"
eq "del non-active: state active is acc1" "acc1" "$(jq -r .active "$AGY_HOME/accounts/state.json")"
eq "del non-active: live token untouched" "tok-acc1" "$(cat "$AGY_HOME/antigravity-oauth-token")"
out_list="$("$ACCT" list -c)"
hasnt "del non-active: list -c no longer shows acc2" "acc2" "$out_list"
has "del non-active: list -c still shows acc1" "acc1" "$out_list"
has "del non-active: list -c still shows acc3" "acc3" "$out_list"

# Deleting the currently active slot
setup
cp "$AGY_HOME/accounts/acc1.token" "$AGY_HOME/accounts/.last-token.bak"
out="$("$ACCT" del acc1 2>&1)"; rc=$?
eq "del active: exit 0" "0" "$rc"
has "del active: confirms with cleared active login" "deleted account 'acc1' (and cleared active login)" "$out"
eq "del active: acc1.token is removed" "no" "$([ -e "$AGY_HOME/accounts/acc1.token" ] && echo yes || echo no)"
eq "del active: live token removed" "no" "$([ -e "$AGY_HOME/antigravity-oauth-token" ] && echo yes || echo no)"
eq "del active: state.json active is cleared" "" "$(jq -r .active "$AGY_HOME/accounts/state.json")"
eq "del active: 'agyr active' prints nothing" "" "$("$ACCT" active)"
eq "del active: .last-token.bak belonging to acc1 is removed" "no" "$([ -e "$AGY_HOME/accounts/.last-token.bak" ] && echo yes || echo no)"
eq "del active: acc2 slot is kept" "tok-acc2" "$(cat "$AGY_HOME/accounts/acc2.token")"

# Deleting slot does not remove .last-token.bak if it belongs to a different account
setup
cp "$AGY_HOME/accounts/acc2.token" "$AGY_HOME/accounts/.last-token.bak"
out="$("$ACCT" del acc1 2>&1)"; rc=$?
eq "del active (different bak): exit 0" "0" "$rc"
eq "del active (different bak): .last-token.bak for acc2 is preserved" "yes" "$([ -f "$AGY_HOME/accounts/.last-token.bak" ] && echo yes || echo no)"

# Alias agyr rm <name> works identically
setup
out="$("$ACCT" rm acc2 2>&1)"; rc=$?
eq "rm alias: exit 0" "0" "$rc"
has "rm alias: confirms" "deleted account 'acc2'" "$out"
eq "rm alias: acc2.token is removed" "no" "$([ -e "$AGY_HOME/accounts/acc2.token" ] && echo yes || echo no)"

# Error cases
setup
out="$("$ACCT" del 2>&1)"; rc=$?
eq "del missing arg -> exit 1" "1" "$rc"
has "del missing arg: usage message" "usage: agyr del <name>" "$out"

out="$("$ACCT" del nope 2>&1)"; rc=$?
eq "del nonexistent slot -> exit 1" "1" "$rc"
has "del nonexistent slot: error message" "no slot 'nope'" "$out"

out="$("$ACCT" del '../bad' 2>&1)"; rc=$?
eq "del invalid name -> exit 1" "1" "$rc"
has "del invalid name: error message" "account name may only contain letters" "$out"

# Help checks
out="$("$ACCT" help del)"
has "help del: usage line" "Usage: agyr del <name>        (alias: rm)" "$out"
has "help del: explains deletion" "Permanently delete slot <name>" "$out"

out="$("$ACCT" del --help)"
has "del --help: usage line" "Usage: agyr del <name>        (alias: rm)" "$out"

out="$("$ACCT" rm --help)"
has "rm --help: usage line" "Usage: agyr del <name>        (alias: rm)" "$out"

out="$("$ACCT" help)"
has "overview includes del" "del <name>" "$out"

exit 0
