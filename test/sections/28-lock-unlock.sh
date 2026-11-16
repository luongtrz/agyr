#!/usr/bin/env bash
# Independent core test section.
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$TEST_DIR/lib.sh"

echo "== lock / unlock"

# lock of an unknown slot fails, wrong args
setup
out="$("$ACCT" lock nope 2>&1)"; rc=$?
eq "lock unknown slot -> exit 1" "1" "$rc"
has "lock unknown slot error message" "no slot 'nope'" "$out"
out="$("$ACCT" unlock nope 2>&1)"; rc=$?
eq "unlock unknown slot -> exit 1" "1" "$rc"
has "unlock unknown slot error message" "no slot 'nope'" "$out"
out="$("$ACCT" lock 2>&1)"; rc=$?
eq "lock no args -> exit 1" "1" "$rc"
has "lock no args error message" "usage: agyr lock <name>" "$out"
out="$("$ACCT" unlock 2>&1)"; rc=$?
eq "unlock no args -> exit 1" "1" "$rc"
has "unlock no args error message" "usage: agyr unlock <name>" "$out"
"$ACCT" lock '../x' >/dev/null 2>&1; eq "lock invalid name -> exit 1" "1" "$?"

# lock / unlock round trip
setup
out="$("$ACCT" lock acc2 2>&1)"; rc=$?
eq "lock acc2: exit 0" "0" "$rc"
has "lock confirms" "locked account 'acc2'" "$out"
eq "state .locked.acc2 is true" "true" "$(jq -r '(.locked.acc2 // false)' "$AGY_HOME/accounts/state.json")"

# already locked: harmless no-op
out="$("$ACCT" lock acc2 2>&1)"; rc=$?
eq "lock already-locked -> exit 0" "0" "$rc"
has "already locked message" "already locked" "$out"

# locking active account prints note
out="$("$ACCT" lock acc1 2>&1)"; rc=$?
eq "lock active account: exit 0" "0" "$rc"
has "locking active account confirms" "locked account 'acc1'" "$out"
has "locking active account prints note" "currently in use" "$out"
has "locking active account mentions stays in use" "stays in use" "$out"

# unlock
out="$("$ACCT" unlock acc2 2>&1)"; rc=$?
eq "unlock acc2: exit 0" "0" "$rc"
has "unlock confirms" "unlocked account 'acc2'" "$out"
eq "state .locked.acc2 is removed" "null" "$(jq -r '.locked.acc2 // "null"' "$AGY_HOME/accounts/state.json")"

# unlock already-unlocked: harmless no-op
out="$("$ACCT" unlock acc2 2>&1)"; rc=$?
eq "unlock already-unlocked -> exit 0" "0" "$rc"
has "not locked message" "not locked" "$out"

# next skips locked account (including when it has soonest weekly reset)
setup
FAKE_WEEK_ORDER=1 "$ACCT" list >/dev/null 2>&1
eq "next normally picks acc3 (soonest weekly reset)" "acc3" "$("$ACCT" next)"
"$ACCT" lock acc3 >/dev/null
eq "next skips locked acc3 with soonest weekly reset" "acc2" "$("$ACCT" next)"
"$ACCT" lock acc2 >/dev/null
eq "next falls back to active acc1 when others are locked" "acc1" "$("$ACCT" next)"

# next exit 3 when everything else is on cooldown and the rest locked
setup
"$ACCT" lock acc3 >/dev/null
"$ACCT" cooldown acc1 1h >/dev/null
"$ACCT" cooldown acc2 2h >/dev/null
out="$("$ACCT" next 2>&1)"; rc=$?
eq "next exit 3 when cooldown + locked" "3" "$rc"
has "next exit 3 mentions cooldown or locked" "on cooldown or locked" "$out"
has "next exit 3 mentions earliest reset" "'acc1'" "$out"

# next exit 3 when all accounts are locked
setup
"$ACCT" lock acc1 >/dev/null
"$ACCT" lock acc2 >/dev/null
"$ACCT" lock acc3 >/dev/null
out="$("$ACCT" next 2>&1)"; rc=$?
eq "next exit 3 when all accounts locked" "3" "$rc"
has "next exit 3 mentions all accounts are locked" "all 3 accounts are locked" "$out"

# list: a locked account gets "!!" in the same marker column as "*"; its status stays what it really is; the note under the table explains it
setup
"$ACCT" list >/dev/null 2>&1
out="$("$ACCT" list -c)"
hasnt "no locked account: no !! marker" "!!" "$out"
has "no locked account: the note stays the short one" "(* = selected account)" "$out"
"$ACCT" lock acc2 >/dev/null
out="$("$ACCT" list -c)"
row_acc2="$(grep ' acc2 ' <<<"$out")"
row_acc3="$(grep '  acc3 ' <<<"$out")"
has "locked acc2: !! before the name" "!! acc2" "$row_acc2"
has "locked acc2: the status is unchanged" "ready" "$row_acc2"
hasnt "locked acc2: no 'locked' text in the row" "locked" "$row_acc2"
hasnt "unlocked acc3 has no marker" "!!" "$row_acc3"
has "the note under the table explains !!" "(* = selected account, !! = locked account, do not use this)" "$out"
eq "the !! marker keeps the table aligned (same row width)" "${#row_acc3}" "${#row_acc2}"
row_acc1="$(grep ' acc1 ' <<<"$out")"
eq "!! sits in the same column as the * marker" "${row_acc1%%\**}" "${row_acc2%%!!*}"
pfx1="${row_acc1%%acc1*}"; pfx2="${row_acc2%%acc2*}"; pfx3="${row_acc3%%acc3*}"
eq "the names start in the same column (selected row vs locked row)" "${#pfx1}" "${#pfx2}"
eq "an unmarked row keeps the name in that column too" "${#pfx1}" "${#pfx3}"
out="$(AGYR_COLOR=always "$ACCT" list -c)"
has "locked acc2 keeps the green ready status" "${GREEN}ready" "$(grep ' acc2 ' <<<"$out")"
eq "with colour codes stripped the locked table equals the plain one" "$("$ACCT" list -c)" "$(strip <<<"$out")"
# the active account can be locked too: both markers show
"$ACCT" lock acc1 >/dev/null
out="$("$ACCT" list -c)"
has "active + locked: * and !! both show" "*!! acc1" "$out"
# a locked account on cooldown keeps the cooldown status
"$ACCT" cooldown acc2 1h >/dev/null
out="$("$ACCT" list -c)"
row_acc2="$(grep ' acc2 ' <<<"$out")"
has "locked + cooldown: status is the cooldown" "cooldown, 1h00m left" "$row_acc2"
has "locked + cooldown: still marked !!" "!!" "$row_acc2"
has "locked + cooldown: the name is still there" "acc2" "$row_acc2"
# never measured: the note is the long one too
setup
"$ACCT" lock acc2 >/dev/null
out="$("$ACCT" list -c)"
has "never measured + locked: status says not measured" "not measured" "$(grep ' acc2 ' <<<"$out")"
has "never measured + locked: !! before the name" "!! acc2" "$out"
has "never measured + locked: the note explains !!" "!! = locked account, do not use this)" "$out"

# the ACCOUNT column follows the longest name (a long name never pushes the other columns), with or without a locked account
setup
echo "tok-long" >"$AGY_HOME/antigravity-oauth-token"
"$ACCT" save averylongaccountname01 >/dev/null
"$ACCT" use acc1 >/dev/null
out="$("$ACCT" list -c)"
has "long name: shown in full" "averylongaccountname01" "$out"
eq "long name: every data row is as wide as the header" "1" "$(grep '^│ ' <<<"$out" | while IFS= read -r l; do echo "${#l}"; done | sort -u | wc -l | tr -d ' ')"
"$ACCT" lock averylongaccountname01 >/dev/null
out="$("$ACCT" list -c)"
has "long locked name: !! before the full name" "!! averylongaccountname01" "$out"
eq "long locked name: every data row is as wide as the header" "1" "$(grep '^│ ' <<<"$out" | while IFS= read -r l; do echo "${#l}"; done | sort -u | wc -l | tr -d ' ')"
# the selected account locked too: all three markers' widths still line up
"$ACCT" lock acc1 >/dev/null
out="$("$ACCT" list -c)"
has "selected + locked next to a long locked name: *!! before the name" "*!! acc1" "$out"
eq "selected + locked: every data row is as wide as the header" "1" "$(grep '^│ ' <<<"$out" | while IFS= read -r l; do echo "${#l}"; done | sort -u | wc -l | tr -d ' ')"

# rename carries .locked flag, del clears it
setup
"$ACCT" lock acc2 >/dev/null
"$ACCT" rename acc2 renamed >/dev/null
eq "rename moves .locked flag" "true" "$(jq -r '(.locked.renamed // false)' "$AGY_HOME/accounts/state.json")"
eq "rename clears .locked for old name" "null" "$(jq -r '.locked.acc2 // "null"' "$AGY_HOME/accounts/state.json")"
eq "next skips renamed locked account" "acc3" "$("$ACCT" next)"
"$ACCT" del renamed >/dev/null
eq "del removes .locked flag" "null" "$(jq -r '.locked.renamed // "null"' "$AGY_HOME/accounts/state.json")"

# agyr test and agyr test -w also run on a locked account: the lock only keeps automatic rotation away, the user asked for this
setup
"$ACCT" lock acc2 >/dev/null
out="$("$ACCT" test 2>&1)"
hasnt "test without names does not skip a locked account" "skipped (locked)" "$out"
has "test without names tries the locked account" "ok in " "$(grep ' acc2 ' <<<"$out")"
eq "test without names: Hi went to all three accounts, locked one included" "3" "$(grep -c 'ok in ' <<<"$out" | tr -d ' ')"
out="$("$ACCT" test -w 2>&1)"
hasnt "test -w does not skip a locked account" "skipped (locked)" "$out"
has "test -w tries the locked account" "ok in " "$(grep ' acc2 ' <<<"$out")"
eq "test -w: Hi went to all three accounts, locked one included" "3" "$(grep -c 'ok in ' <<<"$out" | tr -d ' ')"
eq "the lock is still there after agyr test" "acc2" "$("$ACCT" locked)"

# test with names still tries a locked account
out="$("$ACCT" test acc2 2>&1)"
hasnt "named locked account not skipped" "skipped" "$out"
has "named locked account is tried" "ok in " "$out"

# test when all accounts are locked: still tests them all (cooldown is the only reason to skip)
setup
for a in acc1 acc2 acc3; do "$ACCT" lock "$a" >/dev/null; done
out="$("$ACCT" test 2>&1)"
hasnt "test with all accounts locked is not 'nothing to do'" "nothing to do" "$out"
eq "test with all accounts locked: Hi went to all three" "3" "$(grep -c 'ok in ' <<<"$out" | tr -d ' ')"
# a locked account that is also on cooldown is still skipped for the cooldown, and stays marked
setup
"$ACCT" lock acc2 >/dev/null
"$ACCT" cooldown acc2 1h >/dev/null
out="$("$ACCT" test 2>&1)"
row_acc2="$(grep ' acc2 ' <<<"$out")"
has "locked + cooldown: skipped for the cooldown" "skipped (cooldown, 1h00m left)" "$row_acc2"
has "locked + cooldown: still marked !!" "!! acc2" "$row_acc2"

# agyr test table: the same marker column as 'agyr list' ("!!" = locked), the note explains it, nothing shifts
setup
out="$("$ACCT" test 2>/dev/null)"
hasnt "test table: nothing locked -> no !! marker" "!!" "$out"
hasnt "test table: nothing locked -> no lock note" "locked account" "$out"
"$ACCT" lock acc2 >/dev/null
out="$("$ACCT" test 2>/dev/null)"
row_acc1="$(grep ' acc1 ' <<<"$out")"; row_acc2="$(grep ' acc2 ' <<<"$out")"; row_acc3="$(grep ' acc3 ' <<<"$out")"
has "test table: locked acc2 is marked !!" "!! acc2" "$row_acc2"
has "test table: locked acc2 was tested too" "ok in" "$row_acc2"
hasnt "test table: unlocked acc1 has no marker" "!!" "$row_acc1"
has "test table: unlocked acc1 was tested" "ok in" "$row_acc1"
has "test table: the note explains !!" "!! = locked account, do not use this)" "$out"
pfx1="${row_acc1%%acc1*}"; pfx2="${row_acc2%%acc2*}"; pfx3="${row_acc3%%acc3*}"
eq "test table: names start in the same column (marked vs unmarked row)" "${#pfx1}" "${#pfx2}"
eq "test table: acc3 too" "${#pfx1}" "${#pfx3}"
eq "test table: every data row is as wide as the header" "1" "$(grep '^│ ' <<<"$out" | while IFS= read -r l; do echo "${#l}"; done | sort -u | wc -l | tr -d ' ')"
# test -w: the same marker on a locked account
out="$("$ACCT" test -w 2>/dev/null)"
row_acc2="$(grep ' acc2 ' <<<"$out")"
has "test -w table: locked account is marked !!" "!! acc2" "$row_acc2"
has "test -w table: locked account was tested" "ok in" "$row_acc2"
# a long name widens the ACCOUNT column, with and without a lock, and every row keeps the same width
setup
echo "tok-long" >"$AGY_HOME/antigravity-oauth-token"
"$ACCT" save averylongaccountname01 >/dev/null
"$ACCT" use acc1 >/dev/null
out="$("$ACCT" test 2>/dev/null)"
has "test table: long name shown in full" "averylongaccountname01" "$out"
eq "test table: long name, every data row has the same width" "1" "$(grep '^│ ' <<<"$out" | while IFS= read -r l; do echo "${#l}"; done | sort -u | wc -l | tr -d ' ')"
"$ACCT" lock averylongaccountname01 >/dev/null
out="$("$ACCT" test 2>/dev/null)"
has "test table: long locked name: !! before the full name" "!! averylongaccountname01" "$out"
eq "test table: long locked name, every data row has the same width" "1" "$(grep '^│ ' <<<"$out" | while IFS= read -r l; do echo "${#l}"; done | sort -u | wc -l | tr -d ' ')"
# narrow terminal: the shrunk table still fits when a lock widens the ACCOUNT column
out="$(AGYR_RESPONSIVE=1 AGYR_COLUMNS=120 "$ACCT" test 2>/dev/null)"
eq "test table at 120 columns with a locked account: no line wider than the terminal" "0" "$(grep '^[│┌├└]' <<<"$out" | while IFS= read -r l; do echo "${#l}"; done | awk '$1 > 120' | wc -l | tr -d ' ')"

# manual use of a locked account works
setup
"$ACCT" lock acc2 >/dev/null
out="$("$ACCT" use acc2)"
has "use locked account works" "switched to account 'acc2'" "$out"
eq "active is acc2 after use" "acc2" "$("$ACCT" active)"

# old state.json without .locked key keeps working
setup
state="$(jq 'del(.locked)' "$AGY_HOME/accounts/state.json")"
echo "$state" >"$AGY_HOME/accounts/state.json"
eq "next works with old state file (no .locked)" "acc2" "$("$ACCT" next)"
out="$("$ACCT" list -c)"
has "list works with old state file" "not measured" "$out"

# help lock and help unlock
has "help lock: usage" "Usage: agyr lock <name>" "$("$ACCT" help lock)"
has "help unlock: usage" "Usage: agyr unlock <name>" "$("$ACCT" help unlock)"
has "lock --help works" "Usage: agyr lock <name>" "$("$ACCT" lock --help)"
has "unlock --help works" "Usage: agyr unlock <name>" "$("$ACCT" unlock --help)"

# agyr locked with and without a name
setup
out="$("$ACCT" locked)"
eq "locked with no accounts locked: empty output" "" "$out"

# exit 1 when slot is not locked
"$ACCT" locked acc2 >/dev/null 2>&1; rc=$?
eq "locked on unlocked slot -> exit 1" "1" "$rc"
out="$("$ACCT" locked acc2)"
eq "locked on unlocked slot prints nothing" "" "$out"

# exit 2 when slot does not exist
"$ACCT" locked nope >/dev/null 2>&1; rc=$?
eq "locked on nonexistent slot -> exit 2" "2" "$rc"
out="$("$ACCT" locked nope 2>&1)"
has "locked on nonexistent slot error message" "no slot 'nope'" "$out"

# exit 0 when slot is locked
"$ACCT" lock acc3 >/dev/null
"$ACCT" lock acc1 >/dev/null
"$ACCT" locked acc1 >/dev/null 2>&1; rc=$?
eq "locked on locked slot -> exit 0" "0" "$rc"
out="$("$ACCT" locked acc1)"
eq "locked on locked slot prints nothing" "" "$out"

# without a name: print locked slot names, one per line, sorted; exit 0
out="$("$ACCT" locked)"
eq "locked without args lists sorted locked slots" "acc1 acc3" "$(echo $out)"
has "help locked: usage" "Usage: agyr locked" "$("$ACCT" help locked)"
has "locked --help works" "Usage: agyr locked" "$("$ACCT" locked --help)"

# agy-run started while active account is locked
setup
"$ACCT" lock acc1 >/dev/null
runit; rc=$?
eq "agy-run on locked active account: exit 0" "0" "$rc"
has "agy-run logs rotation before run" "account 'acc1' is locked; rotating before the run" "$(cat "$T/run.err")"
first="$(sed -n 1p "$FAKE_ARGS_LOG")"
has "agy-run ran on rotated account (acc2)" "tok-acc2|" "$first"
eq "locked account acc1 has no cooldown" "0" "$(cd_of acc1)"
eq "active account switched to acc2" "acc2" "$("$ACCT" active)"
eq "fake agy ran only once" "1" "$(lines)"

# pre-flight switch does not count towards max-switch
setup
"$ACCT" lock acc1 >/dev/null
AGY_RUN_MAX_SWITCH=0 runit; rc=$?
eq "agy-run pre-flight does not count towards max-switch" "0" "$rc"
first="$(sed -n 1p "$FAKE_ARGS_LOG")"
has "ran on acc2 despite MAX_SWITCH=0" "tok-acc2|" "$first"

# agy-run when active is locked and all other accounts are on cooldown -> exit 5
setup
"$ACCT" lock acc1 >/dev/null
"$ACCT" cooldown acc2 2h >/dev/null
"$ACCT" cooldown acc3 1h >/dev/null
runit; rc=$?
eq "agy-run with locked active and rest on cooldown -> exit 5" "5" "$rc"
has "agy-run reports every unlocked account is out of quota" "every unlocked account is out of quota" "$(cat "$T/run.err")"
eq "fake agy was not run when exit 5" "0" "$(lines)"

# agy-run with non-locked active account behaves as before
setup
runit; rc=$?
eq "agy-run with unlocked active account: exit 0" "0" "$rc"
first="$(sed -n 1p "$FAKE_ARGS_LOG")"
has "ran on active acc1" "tok-acc1|" "$first"
hasnt "no pre-flight rotation logged" "is locked; rotating" "$(cat "$T/run.err")"
exit 0
