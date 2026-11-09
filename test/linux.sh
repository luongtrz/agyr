# Linux platform tests (file backend, GNOME keyring D-Bus bypass, platforms/linux/install.sh).
# Sourced by test/run.sh.

echo "== run / keyring (agy >= 1.2.14)"
setup
"$ACCT" run -p hello >/dev/null 2>&1
has "agyr run: agy uses the token file (keyring made unreachable)" "tok-acc1|-p hello" "$(cat "$FAKE_ARGS_LOG")"
"$ACCT" use acc2 >/dev/null
"$ACCT" run -c >/dev/null 2>&1
has "agyr run: follows 'agyr use' (acc2)" "tok-acc2|-c" "$(sed -n 2p "$FAKE_ARGS_LOG")"
out="$(FAKE_QUOTA_TOKENS="tok-acc2" "$ACCT" run -p x 2>&1 | head -1)"
has "agyr run: passes agy's output through" "init" "$out"
"$ACCT" run --version >/dev/null 2>&1; rc=$?
eq "agyr run: the exit code of agy is propagated (fake agy ignores unknown flags)" "0" "$rc"
out="$(AGY_BIN=/nonexistent/agy "$ACCT" run 2>&1)"; rc=$?
eq "agyr run: no agy -> error" "1" "$rc"
has "agyr run: no agy -> message" "agy not found" "$out"
mkdir -p "$T/empty2"
AGY_HOME="$T/empty2" "$ACCT" run -p hi >/dev/null 2>&1
eq "agyr run does not create the accounts directory" "no" "$([ -e "$T/empty2/accounts" ] && echo yes || echo no)"
# the fake really does ignore the token file when the keyring is reachable (so the checks above are meaningful)
setup
DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/x/bus "$AGY_BIN" -p hi >/dev/null 2>&1
has "sanity: with a reachable keyring the fake agy uses the keyring account" "keyring-account|-p hi" "$(tail -1 "$FAKE_ARGS_LOG")"
# agyr list and agy-run measure / run every account with its own token even though the keyring says otherwise
setup
"$ACCT" list >/dev/null 2>&1
eq "list: every account measured with its own token, not the keyring's" "tok-acc1 tok-acc2 tok-acc3 " "$(cut -d'|' -f1 "$FAKE_ARGS_LOG" | sort | tr '\n' ' ')"
setup
runit >/dev/null 2>&1
has "agy-run: agy ran with the selected account's token, not the keyring's" "tok-acc1|" "$(cat "$FAKE_ARGS_LOG")"
hasnt "agy-run: the keyring account was not used" "keyring-account" "$(cat "$FAKE_ARGS_LOG")"
out="$("$ACCT" rotate 1h 2>&1)"
has "rotate: tells you to reopen with agyr -c" "agyr -c" "$out"

echo "== forget (file backend)"
setup
out="$("$ACCT" forget 2>&1)"; rc=$?
eq "forget: exit 0" "0" "$rc"
eq "forget: the token file is gone" "no" "$([ -e "$AGY_HOME/antigravity-oauth-token" ] && echo yes || echo no)"
eq "forget: backed up first" "tok-acc1" "$(cat "$AGY_HOME/accounts/.last-token.bak")"
eq "forget: the slot keeps the login" "tok-acc1" "$(cat "$AGY_HOME/accounts/acc1.token")"
has "forget: says nothing was revoked" "nothing was revoked" "$out"
hasnt "forget: does not print the token" "tok-" "$out"
out="$("$ACCT" forget 2>&1)"; has "forget: with no login -> nothing to forget" "nothing to forget" "$out"
setup
echo "tok-unsaved" >"$AGY_HOME/antigravity-oauth-token"
out="$("$ACCT" forget 2>&1)"; rc=$?
eq "forget: refuses a login that matches no slot" "1" "$rc"
has "forget: ... and says why" "would lose it" "$out"
eq "forget: ... and leaves the login alone" "tok-unsaved" "$(cat "$AGY_HOME/antigravity-oauth-token")"
"$ACCT" forget --force >/dev/null 2>&1
eq "forget --force: removes it" "no" "$([ -e "$AGY_HOME/antigravity-oauth-token" ] && echo yes || echo no)"
eq "forget --force: after backing it up" "tok-unsaved" "$(cat "$AGY_HOME/accounts/.last-token.bak")"
"$ACCT" forget --bogus >/dev/null 2>&1; eq "forget: unknown option -> exit 2" "2" "$?"


echo "== platforms/linux/install.sh (into temp bin dirs, never the real ~/.local/bin)"
INST_LIN="$(mktemp -d)"; TMPS+=("$INST_LIN")
REPO_ABS="$(cd "$HERE/.." && pwd)"
if bash "$HERE/../platforms/linux/install.sh" "$INST_LIN/lin" >/dev/null 2>&1; then pass "platforms/linux/install.sh runs"; else fail "platforms/linux/install.sh runs"; fi
if [ "$ON_WINDOWS" = 1 ]; then
  echo "  skip symlink target check: Git Bash ln -s copies files unless Developer Mode symlinks are enabled"
else
  eq "platforms/linux/install.sh links agyr to bin/agyr" "$REPO_ABS/bin/agyr" "$(readlink -f "$INST_LIN/lin/agyr")"
fi
has "linked agyr answers help" "agyr" "$("$INST_LIN/lin/agyr" help 2>&1 | head -1)"
mkdir -p "$INST_LIN/guard" && echo mine >"$INST_LIN/guard/agyr"
if bash "$HERE/../platforms/linux/install.sh" "$INST_LIN/guard" >/dev/null 2>&1; then fail "platforms/linux/install.sh refuses to replace a regular file"; else pass "platforms/linux/install.sh refuses to replace a regular file"; fi
eq "the regular file is left as it was" "mine" "$(cat "$INST_LIN/guard/agyr")"

echo "== install.sh (unified root installer)"
if bash "$HERE/../install.sh" "$INST_LIN/top" >/dev/null 2>&1; then pass "install.sh runs directly"; else fail "install.sh runs directly"; fi
if [ "$ON_WINDOWS" = 1 ]; then
  echo "  skip symlink target check: Git Bash ln -s copies files unless Developer Mode symlinks are enabled"
else
  eq "install.sh links agyr to bin/agyr" "$REPO_ABS/bin/agyr" "$(readlink -f "$INST_LIN/top/agyr")"
fi
has "install.sh (direct) linked agyr answers help" "agyr" "$("$INST_LIN/top/agyr" help 2>&1 | head -1)"

if AGYR_INSTALL_DIR="$INST_LIN/cloned" AGYR_REPO_URL="$REPO_ABS" bash -s -- "$INST_LIN/piped" < "$HERE/../install.sh" >/dev/null 2>&1; then
  pass "install.sh runs when piped via stdin"
else
  fail "install.sh runs when piped via stdin"
fi
eq "install.sh (piped) clones repo into AGYR_INSTALL_DIR" "yes" "$([ -d "$INST_LIN/cloned/.git" ] && echo yes || echo no)"
has "install.sh (piped) linked agyr answers help" "agyr" "$("$INST_LIN/piped/agyr" help 2>&1 | head -1)"

if AGYR_INSTALL_DIR="$INST_LIN/cloned" AGYR_REPO_URL="$REPO_ABS" bash -s -- "$INST_LIN/piped-update" < "$HERE/../install.sh" >/dev/null 2>&1; then
  pass "install.sh (piped) updates existing clone"
else
  fail "install.sh (piped) updates existing clone"
fi
has "install.sh (piped update) linked agyr answers help" "agyr" "$("$INST_LIN/piped-update/agyr" help 2>&1 | head -1)"
