# Windows platform tests (wincred backend, MSYS path-conversion guards, platforms/windows/install.sh).
# Sourced by test/run.sh.

echo "== wincred backend (Windows Credential Manager; here a fake one: nothing in this section touches a real login)"
export AGYR_BACKEND=wincred
eq "wincred: tests only ever use the fake credential helper" "$HERE/fake-cred" "$AGYR_CRED_HELPER"
# regression (seen on a real Windows machine: every account 'measure failed'): Git Bash rewrote the argument /quota into
# C:/Program Files/Git/quota. The fake agy is a bash script, so it cannot show this; check that the protection is there.
has "wincred: agyr hands the /quota exclusion to quota_fetch" 'PLATFORM_ENV_NOCONV_QUOTA' "$(grep -n 'PLATFORM_ENV_NOCONV_QUOTA' "$ACCT")"
has "wincred: windows platform shields /quota from msys path conversion" 'MSYS2_ARG_CONV_EXCL=/quota' "$(grep -n 'MSYS2_ARG_CONV_EXCL' "$HERE/../platforms/windows/platform.sh")"
has "wincred: agy-run hands the prompt over unchanged (PLATFORM_ENV_NOCONV_ALL)" 'PLATFORM_ENV_NOCONV_ALL' "$(grep -n 'PLATFORM_ENV_NOCONV_ALL' "$RUN")"
has "wincred: windows platform shields the prompt from msys path conversion" "MSYS2_ARG_CONV_EXCL='*'" "$(grep -n 'MSYS2_ARG_CONV_EXCL' "$HERE/../platforms/windows/platform.sh")"

# like setup, but the login lives in the fake credential entry $T/cred (there is no token file at all)
setupw() {
  T="$(mktemp -d)"; TMPS+=("$T")
  export AGY_HOME="$T/home"; mkdir -p "$AGY_HOME"
  export AGY_NOW=1000000
  export FAKE_ARGS_LOG="$T/args.log"; : >"$FAKE_ARGS_LOG"
  export FAKE_CRED_FILE="$T/cred"
  unset FAKE_QUOTA_TOKENS FAKE_AUTH FAKE_RESET AGY_RUN_MAX_SWITCH FAKE_REFRESH FAKE_CRED_FAIL_AT AGYR_LOCK_WAIT
  local a
  for a in acc1 acc2 acc3; do
    if [ "${1:-}" = json ]; then jtok "$a" "at-$a" >"$FAKE_CRED_FILE"; else echo "tok-$a" >"$FAKE_CRED_FILE"; fi
    "$ACCT" save "$a" >/dev/null
  done
  "$ACCT" use acc1 >/dev/null
  rm -f "$FAKE_CRED_FILE.writes"
  echo "do the thing" >"$T/prompt.txt"
  mkdir -p "$T/work"
}
cred_exists() { [ -f "$FAKE_CRED_FILE" ] && echo yes || echo no; }

setupw
eq "wincred: backend" "wincred" "$("$ACCT" backend)"
eq "wincred: save took the login from the credential entry" "tok-acc2" "$(cat "$AGY_HOME/accounts/acc2.token")"
eq "wincred: active = acc1" "acc1" "$("$ACCT" active)"
eq "wincred: no token file is ever created in the agy directory" "no" "$([ -e "$AGY_HOME/antigravity-oauth-token" ] && echo yes || echo no)"
out="$("$ACCT" list -c)"; has "wincred: list -c marks the selected account" "* acc1" "$out"
(AGYR_BACKEND=bogus "$ACCT" backend >/dev/null 2>&1); eq "wincred: an unknown backend name -> exit 2" "2" "$?"

# use
setupw
out="$("$ACCT" use acc2 2>&1)"
eq "wincred: use writes the slot's login into the entry" "tok-acc2" "$(cat "$FAKE_CRED_FILE")"
eq "wincred: use backs up the previous login first" "tok-acc1" "$(cat "$AGY_HOME/accounts/.last-token.bak")"
eq "wincred: active follows use" "acc2" "$("$ACCT" active)"
hasnt "wincred: use does not print the login" "tok-" "$out"
eq "wincred: use leaves no lock behind" "no" "$([ -e "$AGY_HOME/accounts/.swap.lock" ] && echo yes || echo no)"
"$ACCT" use nope >/dev/null 2>&1; eq "wincred: use of a missing slot -> error" "1" "$?"
eq "wincred: a failed use leaves the login alone" "tok-acc2" "$(cat "$FAKE_CRED_FILE")"

setupw json
jtok acc1 "at-acc1-refreshed" >"$FAKE_CRED_FILE" # agy refreshed the access token itself (same refresh_token)
"$ACCT" use acc2 >/dev/null
eq "wincred: use syncs the refreshed login back into its own slot" "at-acc1-refreshed" "$(jq -r .token.access_token "$AGY_HOME/accounts/acc1.token")"
eq "wincred: use writes acc2's login" "at-acc2" "$(jq -r .token.access_token "$FAKE_CRED_FILE")"

setupw
echo "tok-unsaved" >"$FAKE_CRED_FILE" # logged in to an account that was never saved
out="$("$ACCT" list -c)"; has "wincred: warns when the login in use matches no slot" "matches no slot" "$out"
"$ACCT" use acc2 >/dev/null
eq "wincred: an unsaved login is kept in .last-token.bak" "tok-unsaved" "$(cat "$AGY_HOME/accounts/.last-token.bak")"
eq "wincred: an unsaved login overwrites no slot (acc1)" "tok-acc1" "$(cat "$AGY_HOME/accounts/acc1.token")"
eq "wincred: an unsaved login overwrites no slot (acc2)" "tok-acc2" "$(cat "$AGY_HOME/accounts/acc2.token")"

# lock
setupw
echo 999999 >"$AGY_HOME/accounts/.swap.lock" # its owner is gone
"$ACCT" use acc2 >/dev/null 2>&1; eq "wincred: a stale lock (owner gone) is taken over" "0" "$?"
eq "wincred: ... and the switch happened" "tok-acc2" "$(cat "$FAKE_CRED_FILE")"
setupw
echo $$ >"$AGY_HOME/accounts/.swap.lock" # its owner (this shell) is alive
out="$(AGYR_LOCK_WAIT=1 "$ACCT" use acc2 2>&1)"; rc=$?
eq "wincred: a lock held by a live process -> error" "1" "$rc"
has "wincred: ... with a clear message" "another agyr is switching accounts" "$out"
eq "wincred: ... and the login is untouched" "tok-acc1" "$(cat "$FAKE_CRED_FILE")"
rm -rf "$AGY_HOME/accounts/.swap.lock"

# list: accounts are measured one after another by swapping the shared login, then the original is put back
setupw
out="$("$ACCT" list 2>&1)"; rc=$?
eq "wincred list: exit 0" "0" "$rc"
has "wincred list: * marks the selected account" "* acc1" "$out"
has "wincred list: acc1 5h = 60%" " 60%" "$out"
has "wincred list: acc2 5h = 70%" " 70%" "$out"
has "wincred list: acc3 5h = 80%" " 80%" "$out"
hasnt "wincred list: does not print any login" "tok-" "$out"
eq "wincred list: every account was measured with its own login" "tok-acc1 tok-acc2 tok-acc3 " "$(cut -d'|' -f1 "$FAKE_ARGS_LOG" | sort | tr '\n' ' ')"
eq "wincred list: the login in use is put back" "tok-acc1" "$(cat "$FAKE_CRED_FILE")"
eq "wincred list: the active account is unchanged" "acc1" "$("$ACCT" active)"
eq "wincred list: no lock left behind" "no" "$([ -e "$AGY_HOME/accounts/.swap.lock" ] && echo yes || echo no)"
eq "wincred list: stores the acc3 snapshot gw=70" "70" "$(jq -r '.quota.acc3.gw' "$AGY_HOME/accounts/state.json")"
eq "wincred list: backs the login up before swapping" "tok-acc1" "$(cat "$AGY_HOME/accounts/.last-token.bak")"
mkdir -p "$T/tmp"; TMPDIR="$T/tmp" "$ACCT" list >/dev/null 2>&1
eq "wincred list: no temp copy of a login left behind" "0" "$(ls -A "$T/tmp" | wc -l | tr -d ' ')"

setupw
"$ACCT" use acc2 >/dev/null; "$ACCT" list >/dev/null 2>&1
eq "wincred list: restores the login that was in use (acc2, not the first/last measured)" "tok-acc2" "$(cat "$FAKE_CRED_FILE")"

setupw
echo "tok-unsaved" >"$FAKE_CRED_FILE"
"$ACCT" list >/dev/null 2>&1
eq "wincred list: a login that matches no slot is restored too" "tok-unsaved" "$(cat "$FAKE_CRED_FILE")"

setupw
rm -f "$FAKE_CRED_FILE"
"$ACCT" list >/dev/null 2>&1
eq "wincred list: started with no login -> ends with no login" "no" "$(cred_exists)"

setupw json
FAKE_REFRESH=1 "$ACCT" list >/dev/null 2>&1
eq "wincred list: a login agy refreshed is taken back into its slot (acc2)" "at-acc2-refreshed" "$(jq -r .token.access_token "$AGY_HOME/accounts/acc2.token")"
eq "wincred list: the active account's login is restored (refresh_token intact)" "rt-acc1" "$(jq -r .token.refresh_token "$FAKE_CRED_FILE")"
eq "wincred list: ... and it is the refreshed one" "at-acc1-refreshed" "$(jq -r .token.access_token "$FAKE_CRED_FILE")"
eq "wincred list: active is still acc1" "acc1" "$("$ACCT" active)"

# forget: drop the login so agy asks for a new one (the Linux 'rm <token file>')
setupw json
jtok acc1 "at-acc1-refreshed" >"$FAKE_CRED_FILE"
out="$("$ACCT" forget 2>&1)"; rc=$?
eq "wincred forget: exit 0" "0" "$rc"
eq "wincred forget: the entry is gone" "no" "$(cred_exists)"
eq "wincred forget: the slot gets the freshest copy" "at-acc1-refreshed" "$(jq -r .token.access_token "$AGY_HOME/accounts/acc1.token")"
eq "wincred forget: backed up first" "at-acc1-refreshed" "$(jq -r .token.access_token "$AGY_HOME/accounts/.last-token.bak")"
hasnt "wincred forget: does not print the login" "at-acc" "$out"
eq "wincred forget: no lock left" "no" "$([ -e "$AGY_HOME/accounts/.swap.lock" ] && echo yes || echo no)"
out="$("$ACCT" forget 2>&1)"; has "wincred forget: with no login -> nothing to forget" "nothing to forget" "$out"
echo "tok-new-login" >"$FAKE_CRED_FILE"; "$ACCT" save acc4 >/dev/null # the next account: log in, save
eq "wincred forget: a new login is saved as its own slot" "tok-new-login" "$(cat "$AGY_HOME/accounts/acc4.token")"
setupw
echo "tok-unsaved" >"$FAKE_CRED_FILE"
"$ACCT" forget >/dev/null 2>&1; eq "wincred forget: refuses a login that matches no slot" "1" "$?"
eq "wincred forget: ... and leaves the entry alone" "tok-unsaved" "$(cat "$FAKE_CRED_FILE")"
"$ACCT" forget --force >/dev/null 2>&1
eq "wincred forget --force: removes the entry" "no" "$(cred_exists)"
eq "wincred forget --force: after backing it up" "tok-unsaved" "$(cat "$AGY_HOME/accounts/.last-token.bak")"

# a write fails half way through the measurement: the original login must still come back, and the lock must go
setupw
FAKE_CRED_FAIL_AT=2 "$ACCT" list >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] && pass "wincred list: a failing write makes list fail" || fail "wincred list: a failing write makes list fail" "exit code was 0"
eq "wincred list: after a failed write the original login is restored" "tok-acc1" "$(cat "$FAKE_CRED_FILE")"
eq "wincred list: after a failed write no lock is left" "no" "$([ -e "$AGY_HOME/accounts/.swap.lock" ] && echo yes || echo no)"
unset FAKE_CRED_FAIL_AT

# agyr run / agy-run: agy needs no keyring trick here, it just reads the entry that 'use' wrote
setupw
"$ACCT" use acc2 >/dev/null
"$ACCT" run -p hello >/dev/null 2>&1
has "wincred: agyr run starts agy with the selected account" "tok-acc2|-p hello" "$(cat "$FAKE_ARGS_LOG")"

setupw
runit; rc=$?
eq "wincred agy-run: immediate success: exit 0" "0" "$rc"
has "wincred agy-run: uses the selected account" "tok-acc1|" "$(cat "$FAKE_ARGS_LOG")"

setupw
export FAKE_QUOTA_TOKENS="tok-acc1"
start=$SECONDS
runit; rc=$?
elapsed=$((SECONDS - start))
eq "wincred agy-run: acc1 out of quota -> switch to acc2, exit 0" "0" "$rc"
eq "wincred agy-run: runs twice" "2" "$(lines)"
second="$(sed -n 2p "$FAKE_ARGS_LOG")"
has "wincred agy-run: second run uses acc2's login" "tok-acc2|" "$second"
has "wincred agy-run: second run resumes the same conversation" "--conversation conv-fake-1" "$second"
eq "wincred agy-run: the entry now holds acc2's login" "tok-acc2" "$(cat "$FAKE_CRED_FILE")"
eq "wincred agy-run: active = acc2" "acc2" "$("$ACCT" active)"
[ "$elapsed" -lt 20 ] && pass "wincred agy-run: stopped agy immediately (${elapsed}s)" || fail "wincred agy-run: stopped agy immediately" "took ${elapsed}s"
unset FAKE_QUOTA_TOKENS

# agyr test: one account after the other through the credential entry, which ends up as it was
setupw
out="$("$ACCT" test 2>/dev/null)"; rc=$?
eq "wincred test: exit 0" "0" "$rc"
eq "wincred test: all three answered" "3" "$(grep -c 'ok in' <<<"$out")"
eq "wincred test: one Hi per account, each with its own login" "tok-acc1 tok-acc2 tok-acc3 " "$(grep -F -- '|-p Hi ' "$FAKE_ARGS_LOG" | cut -d'|' -f1 | sort | tr '\n' ' ')"
has "wincred test: before>after of acc2" "70%>69%" "$out"
eq "wincred test: the entry holds the login that was in use again (acc1)" "tok-acc1" "$(cat "$FAKE_CRED_FILE")"
eq "wincred test: no lock left behind" "no" "$([ -e "$AGY_HOME/accounts/.swap.lock" ] && echo yes || echo no)"
eq "wincred test: no token file was created" "no" "$([ -e "$AGY_HOME/antigravity-oauth-token" ] && echo yes || echo no)"
eq "wincred test: the account in use did not change" "acc1" "$("$ACCT" active)"

# back to the default for the rest of the suite
export AGYR_BACKEND=file
unset FAKE_CRED_FILE


echo "== platforms/windows/install.sh (into temp bin dirs, never the real ~/.local/bin)"
INST_WIN="$(mktemp -d)"; TMPS+=("$INST_WIN")
REPO_ABS="$(cd "$HERE/.." && pwd)"
if bash "$HERE/../platforms/windows/install.sh" "$INST_WIN/win" >/dev/null 2>&1; then pass "platforms/windows/install.sh writes the wrappers"; else fail "platforms/windows/install.sh writes the wrappers"; fi
has "windows wrapper points at this clone's bin/agyr" "exec \"$REPO_ABS/bin/agyr\"" "$(cat "$INST_WIN/win/agyr")"
has "windows .cmd wrapper points at this clone's bin/agyr" "$REPO_ABS/bin/agyr" "$(cat "$INST_WIN/win/agyr.cmd")"
has "windows .cmd wrapper invokes Git Bash explicitly" "Git\\bin\\bash.exe" "$(cat "$INST_WIN/win/agyr.cmd")"
has "windows wrapper answers help" "agyr" "$("$INST_WIN/win/agyr" help 2>&1 | head -1)"
mkdir -p "$INST_WIN/guard-wincmd" && echo mine >"$INST_WIN/guard-wincmd/agyr.cmd"
if bash "$HERE/../platforms/windows/install.sh" "$INST_WIN/guard-wincmd" >/dev/null 2>&1; then fail "platforms/windows/install.sh refuses to replace an unrelated agyr.cmd"; else pass "platforms/windows/install.sh refuses to replace an unrelated agyr.cmd"; fi
eq "the unrelated agyr.cmd file is left as it was" "mine" "$(cat "$INST_WIN/guard-wincmd/agyr.cmd")"
