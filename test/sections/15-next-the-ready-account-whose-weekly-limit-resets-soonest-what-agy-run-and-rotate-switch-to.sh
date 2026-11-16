#!/usr/bin/env bash
# Independent core test section.
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$TEST_DIR/lib.sh"

echo "== next: the ready account whose weekly limit resets soonest (what agy-run and rotate switch to)"
setup
export FAKE_WEEK_ORDER=1 # weekly resets: acc3 first, then acc2, then acc1
"$ACCT" list >/dev/null 2>&1
eq "next from acc1: acc3 (soonest weekly reset), not acc2 (name order)" "acc3" "$("$ACCT" next)"
"$ACCT" cooldown acc3 2h >/dev/null
eq "next skips an account on cooldown even if its week resets first" "acc2" "$("$ACCT" next)"
"$ACCT" clear acc3 >/dev/null
"$ACCT" use acc3 >/dev/null
eq "next while acc3 is in use: the soonest OTHER account (acc2)" "acc2" "$("$ACCT" next)"
"$ACCT" use acc2 >/dev/null
eq "next while acc2 is in use: acc3" "acc3" "$("$ACCT" next)"
"$ACCT" use acc1 >/dev/null
"$ACCT" cooldown acc2 2h >/dev/null; "$ACCT" cooldown acc3 3h >/dev/null
eq "next: the account in use is returned when nothing else is ready" "acc1" "$("$ACCT" next)"
"$ACCT" cooldown acc1 5h >/dev/null
out="$("$ACCT" next 2>&1)"; rc=$?
eq "next: everything on cooldown -> exit 3" "3" "$rc"
has "next: names the account that resets first" "earliest: 'acc2'" "$out"

# explanation on stderr, name alone on stdout
setup
export FAKE_WEEK_ORDER=1
"$ACCT" list >/dev/null 2>&1
out="$("$ACCT" next -v 2>"$T/why.err")"
eq "next -v: stdout is only the name" "acc3" "$out"
has "next -v: says which account and why" "next account 'acc3': weekly limit resets" "$(cat "$T/why.err")"
has "next -v: says it is the soonest of the other ready accounts" "the soonest of the 2 other ready account(s)" "$(cat "$T/why.err")"
"$ACCT" cooldown acc2 2h >/dev/null; "$ACCT" cooldown acc3 2h >/dev/null
"$ACCT" next -v 2>&1 >/dev/null | grep -q "no other account is ready" && pass "next -v: says the one in use stays when nothing else is ready" || fail "next -v: says the one in use stays when nothing else is ready"
out="$("$ACCT" next --why 2>/dev/null)"; eq "next --why is the same as -v" "acc1" "$out"

# accounts never measured come last
setup
export FAKE_WEEK_ORDER=1
"$ACCT" test acc3 >/dev/null 2>&1   # only acc3 has numbers now; acc2 sorts before it by name
eq "next: a measured account goes before never-measured ones (acc3, not acc2)" "acc3" "$("$ACCT" next)"
setup
eq "next: with no numbers at all it falls back to name order (acc2 after acc1)" "acc2" "$("$ACCT" next)"
"$ACCT" next -v 2>&1 >/dev/null | grep -q "no quota data yet" && pass "next -v: says there is no quota data yet" || fail "next -v: says there is no quota data yet"

# an account with its weekly limit used up is on cooldown, so it is skipped although its reset comes first
setup
export FAKE_WEEK_ORDER=1 FAKE_WEEKLY_HIT_TOKENS="tok-acc3"
"$ACCT" list >/dev/null 2>&1
eq "next: the weekly-limit account (acc3, earliest reset) is skipped: acc2" "acc2" "$("$ACCT" next)"
unset FAKE_WEEKLY_HIT_TOKENS

# rotate uses it
setup
export FAKE_WEEK_ORDER=1
"$ACCT" list >/dev/null 2>&1
out="$("$ACCT" rotate 1h 2>&1)"; rc=$?
eq "rotate: exit 0" "0" "$rc"
has "rotate: switched to the soonest weekly reset (acc3)" "switched to account 'acc3'" "$out"
has "rotate: explains the choice" "weekly limit resets" "$out"
eq "rotate: acc1 is on cooldown" "$((1000000 + 3600))" "$(cd_of acc1)"

# agy-run uses it
setup
export FAKE_WEEK_ORDER=1
"$ACCT" list >/dev/null 2>&1
: >"$FAKE_ARGS_LOG"
export FAKE_QUOTA_TOKENS="tok-acc1"
runit; rc=$?
eq "agy-run: acc1 out of quota -> exit 0" "0" "$rc"
has "agy-run: the second run uses acc3 (soonest weekly reset), not acc2" "tok-acc3|" "$(sed -n 2p "$FAKE_ARGS_LOG")"
has "agy-run: its log says why" "next account 'acc3': weekly limit resets" "$(cat "$T/run.err")"
unset FAKE_QUOTA_TOKENS FAKE_WEEK_ORDER
has "help next: describes the rule" "whose weekly limit resets soonest" "$("$ACCT" help next)"
has "help next: mentions -v" "-v, --why" "$("$ACCT" help next)"

exit 0
