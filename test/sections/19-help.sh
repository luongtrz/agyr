#!/usr/bin/env bash
# Independent core test section.
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$TEST_DIR/lib.sh"

echo "== help"
setup
for form in "help" "--help" "-h"; do
  out="$("$ACCT" $form 2>&1)"; rc=$?
  eq "agyr ${form:-<no args>}: exit 0" "0" "$rc"
  has "agyr ${form:-<no args>}: has the command list" "Commands:" "$out"
  has "agyr ${form:-<no args>}: has examples" "Typical use:" "$out"
  has "agyr ${form:-<no args>}: has exit codes" "Exit codes:" "$out"
  has "agyr ${form:-<no args>}: has environment variables" "Environment:" "$out"
done
overview="$("$ACCT" help)"
for c in list save use rename forget test active run rotate next cooldown clear help; do
  has "overview lists '$c'" "  $c" "$overview"
done
has "overview warns about the keyring" "OS keyring" "$overview"
for c in list save use rename forget test active run cooldown clear next rotate help; do
  h="$("$ACCT" help "$c" 2>&1)"; rc=$?
  eq "agyr help $c: exit 0" "0" "$rc"
  has "agyr help $c: has its usage line" "Usage: agyr $c" "$h"
  eq "agyr $c --help == agyr help $c" "$h" "$("$ACCT" "$c" --help 2>&1)"
done
eq "agyr ls --help == agyr help list" "$("$ACCT" help list)" "$("$ACCT" ls --help)"
out="$("$ACCT" help bogus 2>&1)"; rc=$?
eq "agyr help <unknown> -> exit 2" "2" "$rc"
has "agyr help <unknown> names the bad command" "no such command 'bogus'" "$out"
"$ACCT" bogus --help >/dev/null 2>&1; eq "agyr <unknown> --help -> exit 2" "2" "$?"

# --help must only print help, never run the command
setup
"$ACCT" list --help >/dev/null 2>&1
eq "list --help does not call agy" "0" "$(lines)"
slots_before="$(ls "$AGY_HOME/accounts"/*.token | wc -l | tr -d ' ')"
"$ACCT" save --help >/dev/null 2>&1
eq "save --help does not save a slot" "$slots_before" "$(ls "$AGY_HOME/accounts"/*.token | wc -l | tr -d ' ')"
"$ACCT" use --help >/dev/null 2>&1
eq "use --help does not switch" "acc1" "$("$ACCT" active)"
"$ACCT" rotate --help >/dev/null 2>&1
eq "rotate --help does not set a cooldown" "0" "$(cd_of acc1)"
eq "rotate --help does not switch" "acc1" "$("$ACCT" active)"
"$ACCT" cooldown --help >/dev/null 2>&1; eq "cooldown --help without other args -> exit 0" "0" "$?"
mkdir -p "$T/empty"
AGY_HOME="$T/empty" "$ACCT" help >/dev/null 2>&1
eq "help does not create the accounts directory" "no" "$([ -e "$T/empty/accounts" ] && echo yes || echo no)"

out="$("$RUN" --help 2>&1)"; rc=$?
eq "agy-run --help: exit 0" "0" "$rc"
has "agy-run --help: has the usage line" "Usage: agy-run --prompt FILE" "$out"
has "agy-run --help: has exit codes" "Exit codes:" "$out"
has "agy-run --help: documents --conversation" "--conversation ID" "$out"
eq "agy-run --help does not run agy" "0" "$(lines)"
"$RUN" -h >/dev/null 2>&1; eq "agy-run -h: exit 0" "0" "$?"
out="$("$RUN" --bogus 2>&1)"
has "agy-run: an unknown argument points to --help" "see --help" "$out"

exit 0
