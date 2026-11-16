#!/usr/bin/env bash
# Independent core test section.
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$TEST_DIR/lib.sh"

echo "== rotate (using agy by hand)"
# make a log line shaped like agy's: E<MMDD> <HH:MM:SS.uuuuuu> ... Resets in X.   ($1 = seconds before "now", $2 = Resets in)
logline() {
  printf 'E%s.123456  1 errorreport.go:224] generating and executing: RESOURCE_EXHAUSTED (code 429): Individual quota reached. Please upgrade your subscription to increase your limits. Resets in %s.\n' \
    "$(date -d "@$((AGY_NOW - $1))" '+%m%d %H:%M:%S')" "$2"
}

setup
mkdir -p "$AGY_HOME/log"; logline 120 "3h13m51s" >"$AGY_HOME/log/cli-20261001_100000.log"
out="$("$ACCT" rotate 2>&1)"; rc=$?
eq "rotate: exit 0" "0" "$rc"
has "rotate: says it read the agy log" "read from the agy log" "$out"
eq "rotate: acc1 cooldown = log time + Resets in" "$((1000000 - 120 + 11631))" "$(cd_of acc1)"
eq "rotate: switches to acc2" "acc2" "$("$ACCT" active)"
eq "rotate: token = acc2" "tok-acc2" "$(cat "$AGY_HOME/antigravity-oauth-token")"
has "rotate: tells you to reopen with agyr -c" "agyr -c" "$out"
hasnt "rotate: does not print the token" "tok-" "$out"

setup
mkdir -p "$AGY_HOME/log"; logline 120 "3h13m51s" >"$AGY_HOME/log/cli-20261001_100000.log"
"$ACCT" rotate 1h >/dev/null 2>&1
eq "rotate: a manually given duration overrides the log" "$((1000000 + 3600))" "$(cd_of acc1)"

setup
mkdir -p "$AGY_HOME/log"; logline 7200 "3h13m51s" >"$AGY_HOME/log/cli-20261001_100000.log"
out="$("$ACCT" rotate 2>&1)"
eq "rotate: a log line older than 1h is ignored, uses 5h" "$((1000000 + 18000))" "$(cd_of acc1)"
has "rotate: says it uses the default 5h" "default 5h" "$out"

setup
mkdir -p "$AGY_HOME/log"
logline 600 "4h13m19s" >"$AGY_HOME/log/cli-20261001_100000.log"
logline 60 "43m29s" >"$AGY_HOME/log/cli-20261001_110000.log"
touch -d '2 minutes ago' "$AGY_HOME/log/cli-20261001_100000.log"
"$ACCT" rotate >/dev/null 2>&1
eq "rotate: takes the newest line across logs" "$((1000000 - 60 + 2609))" "$(cd_of acc1)"

setup
"$ACCT" rotate >/dev/null 2>&1
eq "rotate: no log directory -> default 5h" "$((1000000 + 18000))" "$(cd_of acc1)"

setup
mkdir -p "$AGY_HOME/log"; : >"$AGY_HOME/log/cli-20261001_100000.log"
"$ACCT" cooldown acc2 3h >/dev/null; "$ACCT" cooldown acc3 2h >/dev/null
out="$("$ACCT" rotate 1h 2>&1)"; rc=$?
eq "rotate: whole pool on cooldown -> exit 3" "3" "$rc"
eq "rotate: whole pool on cooldown still records the current account's cooldown" "$((1000000 + 3600))" "$(cd_of acc1)"
eq "rotate: whole pool on cooldown does not switch the token" "tok-acc1" "$(cat "$AGY_HOME/antigravity-oauth-token")"
"$ACCT" rotate xyz >/dev/null 2>&1; eq "rotate: invalid duration -> error" "1" "$?"

setup
rm -f "$AGY_HOME/accounts/state.json" "$AGY_HOME/antigravity-oauth-token"
"$ACCT" rotate >/dev/null 2>&1; eq "rotate: no active account -> error" "1" "$?"

exit 0
