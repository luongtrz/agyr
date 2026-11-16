#!/usr/bin/env bash
# Independent core test section.
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$TEST_DIR/lib.sh"

echo "== swapui"
setup
out="$("$ACCT" swapui acc1 acc2)"
has "swapui confirms swap" "swapped UI positions of 'acc1' and 'acc2' in 'agyr list'" "$out"
eq "swapui swaps row positions in list -c" "acc2 acc1 acc3" "$("$ACCT" list -c | grep -o -E 'acc[123]' | tr '\n' ' ' | xargs)"
eq "next rotation order unchanged by swapui" "acc2" "$("$ACCT" next)"

"$ACCT" swapui acc2 acc3 >/dev/null
eq "swapui acc2 acc3 updates list -c" "acc3 acc1 acc2" "$("$ACCT" list -c | grep -o -E 'acc[123]' | tr '\n' ' ' | xargs)"
eq "next rotation order still unaffected" "acc2" "$("$ACCT" next)"

out="$("$ACCT" swapui --reset)"
has "swapui --reset confirms reset" "reset UI display order to default (weekly limit reset order)" "$out"
eq "state .ui_order deleted after --reset" "null" "$(jq -r '.ui_order // "null"' "$AGY_HOME/accounts/state.json")"
eq "list -c restored to default after --reset" "acc1 acc2 acc3" "$("$ACCT" list -c | grep -o -E 'acc[123]' | tr '\n' ' ' | xargs)"

"$ACCT" swapui acc1 acc3 >/dev/null
out="$("$ACCT" swapui reset)"
has "swapui reset confirms reset" "reset UI display order to default (weekly limit reset order)" "$out"
eq "list -c restored to default after reset" "acc1 acc2 acc3" "$("$ACCT" list -c | grep -o -E 'acc[123]' | tr '\n' ' ' | xargs)"

"$ACCT" swapui >/dev/null 2>&1; eq "swapui no args -> error" "1" "$?"
"$ACCT" swapui acc1 >/dev/null 2>&1; eq "swapui 1 arg -> error" "1" "$?"
out="$("$ACCT" swapui acc1 nope 2>&1)"; rc=$?
eq "swapui nonexistent account -> error" "1" "$rc"
has "swapui error mentions nonexistent slot" "no slot 'nope'" "$out"
out="$("$ACCT" swapui nope acc1 2>&1)"; rc=$?
eq "swapui first nonexistent account -> error" "1" "$rc"
has "swapui error mentions first nonexistent slot" "no slot 'nope'" "$out"
"$ACCT" swapui acc1 '../x' >/dev/null 2>&1; eq "swapui invalid name -> error" "1" "$?"
out="$("$ACCT" swapui acc1 acc1 2>&1)"; rc=$?
eq "swapui same account -> error" "1" "$rc"
has "swapui same account error message" "cannot swap an account with itself" "$out"

# rename updates name in ui_order
"$ACCT" swapui acc1 acc3 >/dev/null
eq "ui_order before rename" "acc3 acc2 acc1" "$(jq -r '.ui_order | join(" ")' "$AGY_HOME/accounts/state.json")"
"$ACCT" rename acc3 acc9 >/dev/null
eq "rename updates name in ui_order" "acc9 acc2 acc1" "$(jq -r '.ui_order | join(" ")' "$AGY_HOME/accounts/state.json")"
eq "list -c reflects renamed slot in ui_order" "acc9 acc2 acc1" "$("$ACCT" list -c | grep -o -E 'acc[1-9]' | tr '\n' ' ' | xargs)"

# del removes account from ui_order
"$ACCT" del acc2 >/dev/null
eq "del removes account from ui_order" "acc9 acc1" "$(jq -r '.ui_order | join(" ")' "$AGY_HOME/accounts/state.json")"
eq "list -c reflects deleted slot removed from ui_order" "acc9 acc1" "$("$ACCT" list -c | grep -o -E 'acc[1-9]' | tr '\n' ' ' | xargs)"

has "help swapui: mentions agyr swapui" "Usage: agyr swapui" "$("$ACCT" help swapui)"
has "swapui --help works" "Usage: agyr swapui" "$("$ACCT" swapui --help)"

exit 0
