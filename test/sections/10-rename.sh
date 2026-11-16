#!/usr/bin/env bash
# Independent core test section.
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$TEST_DIR/lib.sh"

echo "== rename"
setup
"$ACCT" list >/dev/null 2>&1   # saves quota snapshots (and, measuring real quota, clears cooldowns)
"$ACCT" cooldown acc2 2h >/dev/null
n0="$(lines)"
tok2="$(cat "$AGY_HOME/accounts/acc2.token")"
out="$("$ACCT" rename acc2 renamed 2>&1)"; rc=$?
eq "rename: exit 0" "0" "$rc"
has "rename: confirms" "renamed slot 'acc2' to 'renamed'" "$out"
eq "rename: the old slot file is gone" "no" "$([ -e "$AGY_HOME/accounts/acc2.token" ] && echo yes || echo no)"
eq "rename: the login moved to the new slot unchanged" "$tok2" "$(cat "$AGY_HOME/accounts/renamed.token")"
eq "rename: the new slot is mode 600" "600" "$(stat -c %a "$AGY_HOME/accounts/renamed.token")"
eq "rename: the cooldown moved" "$((1000000 + 7200))" "$(cd_of renamed)"
eq "rename: the old name has no cooldown left" "0" "$(cd_of acc2)"
eq "rename: the quota snapshot moved" "70" "$(jq -r '.quota.renamed.g5' "$AGY_HOME/accounts/state.json")"
eq "rename: the old name has no quota snapshot left" "null" "$(jq -r '.quota.acc2.g5' "$AGY_HOME/accounts/state.json")"
eq "rename: other slots are untouched (acc1 still has its login)" "tok-acc1" "$(cat "$AGY_HOME/accounts/acc1.token")"
eq "rename: other slots keep their quota snapshot" "60" "$(jq -r '.quota.acc1.g5' "$AGY_HOME/accounts/state.json")"
eq "rename: the real token file is untouched" "tok-acc1" "$(cat "$AGY_HOME/antigravity-oauth-token")"
eq "rename: agy is not started" "$n0" "$(lines)"
out="$("$ACCT" list -c)"
has "rename: list shows the new name" "renamed" "$out"
hasnt "rename: list no longer shows the old name" "acc2 " "$out"
eq "rename: 'use' works with the new name" "switched to account 'renamed'" "$("$ACCT" use renamed)"
eq "rename: active follows the login" "renamed" "$("$ACCT" active)"

# renaming the active account moves the "active" mark
setup
"$ACCT" rename acc1 main >/dev/null
eq "rename: the active account keeps being active under its new name" "main" "$("$ACCT" active)"
eq "rename: state.active follows" "main" "$(jq -r .active "$AGY_HOME/accounts/state.json")"

# refusals change nothing
setup
before="$(ls "$AGY_HOME/accounts" | tr '\n' ' ')"; state_before="$(cat "$AGY_HOME/accounts/state.json")"
out="$("$ACCT" rename acc2 acc3 2>&1)"; rc=$?
eq "rename onto an existing slot -> exit 1" "1" "$rc"
has "rename onto an existing slot: says so" "already exists" "$out"
eq "rename onto an existing slot: acc3 keeps its own login" "tok-acc3" "$(cat "$AGY_HOME/accounts/acc3.token")"
eq "rename onto an existing slot: acc2 keeps its login" "tok-acc2" "$(cat "$AGY_HOME/accounts/acc2.token")"
"$ACCT" rename nope other >/dev/null 2>&1; eq "rename of a missing slot -> exit 1" "1" "$?"
out="$("$ACCT" rename acc1 acc1 2>&1)"; rc=$?
eq "rename to the same name -> exit 1" "1" "$rc"
has "rename to the same name: says so" "same" "$out"
"$ACCT" rename acc1 '../x' >/dev/null 2>&1; eq "rename to an invalid name -> exit 1" "1" "$?"
"$ACCT" rename '../x' acc9 >/dev/null 2>&1; eq "rename from an invalid name -> exit 1" "1" "$?"
"$ACCT" rename acc1 >/dev/null 2>&1; eq "rename with one argument -> exit 1" "1" "$?"
out="$("$ACCT" rename 2>&1)"; rc=$?
eq "rename without arguments -> exit 1" "1" "$rc"
has "rename without arguments: usage" "usage: agyr rename <old> <new>" "$out"
eq "refusals leave every slot file as it was" "$before" "$(ls "$AGY_HOME/accounts" | tr '\n' ' ')"
eq "refusals leave state.json as it was" "$state_before" "$(cat "$AGY_HOME/accounts/state.json")"
# --help has no side effects
"$ACCT" rename --help >/dev/null 2>&1
eq "rename --help does not rename anything" "$before" "$(ls "$AGY_HOME/accounts" | tr '\n' ' ')"
out="$("$ACCT" help rename)"
has "help rename: usage line" "Usage: agyr rename <old> <new>" "$out"
has "help rename: mentions that it refuses an existing name" "already exists" "$out"

exit 0
