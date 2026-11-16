#!/usr/bin/env bash
# Independent core test section.
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$TEST_DIR/lib.sh"

echo "== plain agyr starts agy"
setup
"$ACCT" >/dev/null 2>&1
eq "plain 'agyr' starts agy once" "1" "$(lines)"
has "plain 'agyr': agy uses the selected account's token file" "tok-acc1|" "$(cat "$FAKE_ARGS_LOG")"
has "plain 'agyr': passes --dangerously-skip-permissions by default" "--dangerously-skip-permissions" "$(cat "$FAKE_ARGS_LOG")"
"$ACCT" use acc3 >/dev/null
"$ACCT" -c >/dev/null 2>&1
has "'agyr -c' passes -c to agy, with the selected account" "tok-acc3|-c" "$(tail -1 "$FAKE_ARGS_LOG")"
"$ACCT" -p "do it" --model x >/dev/null 2>&1
has "'agyr -p ...' passes all flags through" "tok-acc3|-p do it --model x" "$(tail -1 "$FAKE_ARGS_LOG")"
"$ACCT" run models >/dev/null 2>&1
has "'agyr run <word>' passes a non-flag word to agy" "tok-acc3|models" "$(tail -1 "$FAKE_ARGS_LOG")"
n0="$(lines)"
"$ACCT" --help >/dev/null 2>&1; "$ACCT" -h >/dev/null 2>&1; "$ACCT" help >/dev/null 2>&1
eq "--help, -h and help do not start agy" "$n0" "$(lines)"
"$ACCT" bogus >/dev/null 2>&1; rc=$?
eq "'agyr <unknown word>' is still an error (exit 2), agy is not started" "2" "$rc"
eq "unknown word: agy not started" "$n0" "$(lines)"
"$ACCT" run --help >/dev/null 2>&1
eq "'agyr run --help' shows help, does not start agy" "$n0" "$(lines)"
out="$("$ACCT" help run)"
has "help run mentions the shorthand" "shorthand: agyr [agy arguments...]" "$out"
has "overview mentions plain agyr" "start agy with the selected account" "$("$ACCT" help)"
out="$(AGY_BIN=/nonexistent/agy "$ACCT" 2>&1)"; rc=$?
eq "plain agyr without agy -> error" "1" "$rc"
has "plain agyr without agy -> message" "agy not found" "$out"


exit 0
