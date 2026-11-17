#!/usr/bin/env bash
# Independent core test section: fewer process spawns and odd slot names.
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$TEST_DIR/lib.sh"

echo "== fewer process spawns and odd slot names"

# Group 1: slots named like options (-n, -e)
# valid_name allows leading '-', so slots can be called -n, -e, etc.
# Slots must not be swallowed by echo in slots() or other helpers.
setup
jtok "-n" "tok--n" >"$AGY_HOME/accounts/-n.token"
chmod 600 "$AGY_HOME/accounts/-n.token"

jtok "-e" "tok--e" >"$AGY_HOME/accounts/-e.token"
chmod 600 "$AGY_HOME/accounts/-e.token"

out="$("$ACCT" list -c)"
has "list -c shows slot -n" "-n" "$out"
has "list -c shows slot -e" "-e" "$out"
has "list -c shows normal slot acc1" "acc1" "$out"

next_pick="$("$ACCT" next)"
rc=$?
eq "next with odd slot names: exit 0" "0" "$rc"
[ -n "$next_pick" ] && pass "next with odd slot names returns a ready slot" || fail "next with odd slot names returns a ready slot" "empty pick"

# Group 2: spawn count does not grow with the number of accounts
REAL_JQ="$(type -P jq)" # the file, not lib.sh's jq() wrapper function (command -v would print just "jq" and the shim would exec itself)
SHIM_DIR="$(mktemp -d)"; TMPS+=("$SHIM_DIR")
JQ_LOG="$SHIM_DIR/jq.log"
cat << SHIM_EOF > "$SHIM_DIR/jq"
#!/usr/bin/env bash
echo "jq" >> "$JQ_LOG"
exec "$REAL_JQ" "\$@"
SHIM_EOF
chmod +x "$SHIM_DIR/jq"
PATH="$SHIM_DIR:$PATH"
unset -f jq 2>/dev/null || true

# Measure jq calls for 3 slots with quota data
setup
"$ACCT" list >/dev/null 2>&1

: >"$JQ_LOG"
"$ACCT" list -c >/dev/null
list_calls_3="$(wc -l <"$JQ_LOG" | tr -d ' ')"

: >"$JQ_LOG"
"$ACCT" next >/dev/null
next_calls_3="$(wc -l <"$JQ_LOG" | tr -d ' ')"

# Measure jq calls for 9 slots with quota data
setup
for i in 1 2 3 4 5 6 7 8 9; do
  a="acc$i"
  jtok "$a" "tok-$a" >"$AGY_HOME/antigravity-oauth-token"
  "$ACCT" save "$a" >/dev/null
done
"$ACCT" use acc1 >/dev/null
"$ACCT" list >/dev/null 2>&1

: >"$JQ_LOG"
"$ACCT" list -c >/dev/null
list_calls_9="$(wc -l <"$JQ_LOG" | tr -d ' ')"

: >"$JQ_LOG"
"$ACCT" next >/dev/null
next_calls_9="$(wc -l <"$JQ_LOG" | tr -d ' ')"

if [ "$list_calls_3" = "$list_calls_9" ]; then
  pass "list -c jq call count does not grow with accounts ($list_calls_3 == $list_calls_9)"
else
  fail "list -c jq call count does not grow with accounts" "pool of 3 called jq $list_calls_3 times, pool of 9 called jq $list_calls_9 times"
fi

if [ "$next_calls_3" = "$next_calls_9" ]; then
  pass "next jq call count does not grow with accounts ($next_calls_3 == $next_calls_9)"
else
  fail "next jq call count does not grow with accounts" "pool of 3 called jq $next_calls_3 times, pool of 9 called jq $next_calls_9 times"
fi

exit 0
