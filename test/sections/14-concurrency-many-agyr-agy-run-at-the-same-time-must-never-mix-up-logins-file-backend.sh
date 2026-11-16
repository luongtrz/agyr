#!/usr/bin/env bash
# Independent core test section.
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$TEST_DIR/lib.sh"

echo "== concurrency: many agyr / agy-run at the same time must never mix up logins (file backend)"
# the lock must be exclusive even where mkdir is not (uutils mkdir let several parallel callers all succeed)
if [ "$ON_WINDOWS" = 1 ]; then LOCK_ROUNDS=10 PAR_USE=8 PAR_LIST=3; else LOCK_ROUNDS=60 PAR_USE=40 PAR_LIST=12; fi
bad=0
for r in $(seq 1 "$LOCK_ROUNDS"); do
  D="$(mktemp -d)"; TMPS+=("$D")
  for i in $(seq 1 12); do ( set -o noclobber; { echo "$i" >"$D/lock"; } 2>/dev/null && echo ok >>"$D/oks" ) & done; wait
  [ "$(wc -l <"$D/oks" 2>/dev/null || echo 0)" = 1 ] || bad=$((bad + 1))
done
eq "the exclusive-create primitive used for the lock is atomic (60 rounds x 12 parallel)" "0" "$bad"
grep -q 'until mkdir' "$ACCT" && fail "agyr must not build its lock on mkdir" || pass "agyr does not build its lock on mkdir"
refresh_of() { jq -r .token.refresh_token "$AGY_HOME/accounts/$1.token"; }
mkjson() { # N slots s1..sN with JSON logins, s1 in use
  setup
  rm -f "$AGY_HOME"/accounts/*.token "$AGY_HOME/accounts/state.json"
  local i
  for i in $(seq 1 "$1"); do jtok "s$i" "at-s$i" >"$AGY_HOME/antigravity-oauth-token"; "$ACCT" save "s$i" >/dev/null; done
  "$ACCT" use s1 >/dev/null
}
bad_slots() { local i out=""; for i in $(seq 1 "$1"); do [ "$(refresh_of "s$i")" = "rt-s$i" ] || out="$out s$i"; done; echo "$out"; }
for round in 1 2 3; do
  mkjson 4
  for i in $(seq 1 "$PAR_USE"); do "$ACCT" use "s$(( (i % 4) + 1 ))" >/dev/null 2>&1 & done; wait
  eq "40 parallel 'use' (round $round): every slot still has its own login" "" "$(bad_slots 4)"
done
eq "after the parallel 'use': no temp file or lock left in the accounts dir" "0" "$(ls -A "$AGY_HOME/accounts" | grep -cE '^\.snap|^\.swap\.lock|\.tmp|^\.state\.[A-Za-z0-9]+$|^[a-z0-9]+\.token\.[A-Za-z0-9]{6}$' || true)"
eq "after the parallel 'use': the live login is one of the slots'" "1" "$(for i in 1 2 3 4; do [ "$(jq -r .token.refresh_token "$AGY_HOME/antigravity-oauth-token")" = "rt-s$i" ] && echo y; done | wc -l | tr -d ' ')"
eq "after the parallel 'use': state.json is valid JSON" "ok" "$(jq -e . "$AGY_HOME/accounts/state.json" >/dev/null 2>&1 && echo ok || echo broken)"

# 'use' while measurements run
mkjson 4
"$ACCT" list >/dev/null 2>&1
for i in $(seq 1 "$PAR_LIST"); do "$ACCT" use "s$(( (i % 4) + 1 ))" >/dev/null 2>&1 & "$ACCT" list >/dev/null 2>&1 & done; wait
eq "parallel 'use' and 'list': every slot still has its own login" "" "$(bad_slots 4)"
eq "parallel 'use' and 'list': every slot measured as itself (4 snapshots, none lost)" "4" "$(jq -r '.quota | keys | length' "$AGY_HOME/accounts/state.json")"

# state.json is a read-modify-write: parallel updates must not lose each other
mk12
for i in 01 02 03 04 05 06 07 08 09 10 11 12; do "$ACCT" cooldown "a$i" 1h >/dev/null 2>&1 & done; wait
eq "12 parallel 'cooldown': none is lost" "12" "$(jq -r '.cooldown | keys | length' "$AGY_HOME/accounts/state.json")"

# the lock itself (it used to cover only the Windows backend)
setup
eq "'use' leaves no lock behind" "no" "$("$ACCT" use acc2 >/dev/null; [ -e "$AGY_HOME/accounts/.swap.lock" ] && echo yes || echo no)"
echo 999999 >"$AGY_HOME/accounts/.swap.lock" # its owner is gone
"$ACCT" use acc3 >/dev/null 2>&1; eq "a stale lock (dead owner) is cleared and 'use' works" "acc3" "$("$ACCT" active)"
echo $$ >"$AGY_HOME/accounts/.swap.lock" # its owner (this shell) is alive
start=$SECONDS
out="$(AGYR_LOCK_WAIT=1 "$ACCT" use acc1 2>&1)"; rc=$?
eq "a lock held by a live process: 'use' gives up (exit 1)" "1" "$rc"
has "... and says another agyr is switching" "another agyr is switching accounts" "$out"
[ $((SECONDS - start)) -le 5 ] && pass "... after about AGYR_LOCK_WAIT seconds" || fail "... after about AGYR_LOCK_WAIT seconds" "took $((SECONDS - start))s"
eq "... and the account in use did not change" "acc3" "$("$ACCT" active)"
rm -f "$AGY_HOME/accounts/.swap.lock"
mkdir -p "$AGY_HOME/accounts/.swap.lock"; echo 999999 >"$AGY_HOME/accounts/.swap.lock/pid" # an older agyr's lock directory, owner gone
"$ACCT" use acc2 >/dev/null 2>&1; eq "a stale lock directory left by an older agyr is cleared" "acc2" "$("$ACCT" active)"
eq "... and replaced by nothing (the lock is released)" "no" "$([ -e "$AGY_HOME/accounts/.swap.lock" ] && echo yes || echo no)"
echo $$ >"$AGY_HOME/accounts/.swap.lock" # live again for the checks below
for cmd in "save zz" "forget -f" "rename acc1 acc9" "cooldown acc1 1h"; do
  AGYR_LOCK_WAIT=1 "$ACCT" $cmd >/dev/null 2>&1; eq "a held lock also stops 'agyr $cmd' (exit 1)" "1" "$?"
done
rm -rf "$AGY_HOME/accounts/.swap.lock"

# the login is written atomically and from one copy
setup
"$ACCT" use acc2 >/dev/null
eq "after 'use': the live login is exactly the slot's" "$(cat "$AGY_HOME/accounts/acc2.token")" "$(cat "$AGY_HOME/antigravity-oauth-token")"
eq "'use' leaves no snapshot of a login in the accounts dir" "0" "$(ls -A "$AGY_HOME/accounts" | grep -c '^\.snap' || true)"
eq "the login files stay private (mode 600)" "600" "$(stat -c %a "$AGY_HOME/antigravity-oauth-token")"
eq "slot files stay private (mode 600)" "600" "$(stat -c %a "$AGY_HOME/accounts/acc1.token")"
eq "the backup stays private (mode 600)" "600" "$(stat -c %a "$AGY_HOME/accounts/.last-token.bak")"

exit 0
