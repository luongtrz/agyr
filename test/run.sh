#!/usr/bin/env bash
# Tests for agyr and agy-run. Uses fake tokens and a fake agy; never touches the real token.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ACCT="$HERE/../bin/agyr"
RUN="$HERE/../bin/agy-run"
TASK="$HERE/../bin/agy-task"
FAKE_TASK_RUN="$HERE/fake-agy-run"
export AGY_BIN="$HERE/fake-agy"
export AGY_ACCT="$ACCT"
export AGY_RUN_POLL=0.1
export FAKE_KEYRING=1 # emulate agy >= 1.2.14: it ignores the token file unless the keyring is unreachable
# Safety: this suite never touches a real login. The file backend is forced (agyr would pick wincred on Windows) and the
# credential helper is the fake one. FAKE_CRED_FILE stays unset except inside a test's own temp dir, so a stray call to
# the helper fails loudly instead of doing anything.
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) ON_WINDOWS=1 ;; *) ON_WINDOWS=0 ;; esac
export AGYR_BACKEND=file AGYR_CRED_HELPER="$HERE/fake-cred" AGY_CRED_TARGET="agyr-test:never-real"
unset FAKE_CRED_FILE
# a native Windows jq.exe prints CRLF; -b keeps the assertions below honest
if jq -b -n . >/dev/null 2>&1; then jq() { command jq -b "$@"; }; fi

export TZ=UTC-7 # same timezone as agyr, so the fake log lines line up
REAL_TOKEN="$HOME/.gemini/antigravity-cli/antigravity-oauth-token"
REAL_MTIME_BEFORE="$(stat -c %Y "$REAL_TOKEN" 2>/dev/null || echo none)"
# real agy / agy-run processes (not fake-agy) rewrite the real token file themselves (account switches, token refresh)
real_agy_busy() { pgrep -x agy >/dev/null 2>&1 || pgrep -x agy-run >/dev/null 2>&1; }
REAL_BUSY=0; real_agy_busy && REAL_BUSY=1

PASS=0 FAIL=0
pass() { PASS=$((PASS + 1)); echo "  ok   $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL $1"; [ $# -gt 1 ] && echo "       $2"; }
eq() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "expected '$2', got '$3'"; fi; }
has() { if grep -qF -- "$2" <<<"$3"; then pass "$1"; else fail "$1" "'$2' not found in: $3"; fi; }
hasnt() { if grep -qF -- "$2" <<<"$3"; then fail "$1" "must not contain '$2' in: $3"; else pass "$1"; fi; }

TMPS=()
cleanup() { for d in "${TMPS[@]}"; do rm -rf "$d"; done; }
trap cleanup EXIT

# 3-account pool; acc1 is active, token = tok-acc1
setup() {
  T="$(mktemp -d)"; TMPS+=("$T")
  export AGY_HOME="$T/home"; mkdir -p "$AGY_HOME"
  export AGY_NOW=1000000
  export FAKE_ARGS_LOG="$T/args.log"; : >"$FAKE_ARGS_LOG"
  unset FAKE_QUOTA_TOKENS FAKE_AUTH FAKE_RESET AGY_RUN_MAX_SWITCH
  local a
  for a in acc1 acc2 acc3; do
    echo "tok-$a" >"$AGY_HOME/antigravity-oauth-token"
    "$ACCT" save "$a" >/dev/null
  done
  "$ACCT" use acc1 >/dev/null
  echo "do the thing" >"$T/prompt.txt"
  mkdir -p "$T/work"
}
# JSON token shaped like the real one (compared by refresh_token): jtok <name> <access_token>
jtok() { printf '{"token":{"access_token":"%s","refresh_token":"rt-%s"}}\n' "$2" "$1"; }
cd_of() { jq -r --arg n "$1" '.cooldown[$n] // 0' "$AGY_HOME/accounts/state.json"; }
runit() { "$RUN" --prompt "$T/prompt.txt" --add-dir "$T/work" --log "$T/run.jsonl" 2>"$T/run.err"; }
lines() { wc -l <"$FAKE_ARGS_LOG" | tr -d ' '; }


SUITES=("$@")
if [ "${#SUITES[@]}" -eq 0 ]; then
  SUITES=(core linux windows)
fi

for suite in "${SUITES[@]}"; do
  case "$suite" in
    core|linux|windows)
      . "$HERE/$suite.sh"
      ;;
    *)
      echo "usage: test/run.sh [core|linux|windows ...]" >&2
      exit 2
      ;;
  esac
done

echo "== safety"
real_agy_busy && REAL_BUSY=1
if [ "$REAL_BUSY" = 1 ]; then
  echo "  skip the real token mtime check: real agy / agy-run processes are running and rewrite that file themselves"
else
  eq "the real token is untouched (mtime)" "$REAL_MTIME_BEFORE" "$(stat -c %Y "$REAL_TOKEN" 2>/dev/null || echo none)"
fi
# static guarantee, valid even when the check above is skipped: no test code points at the real agy directory
eq "no test code hard-codes the real agy directory (only the read-only REAL_TOKEN probe)" "0" "$(grep -n '\.gemini' "$HERE/run.sh" "$HERE/core.sh" "$HERE/linux.sh" "$HERE/windows.sh" "$HERE/fake-agy" | grep -vc -e 'REAL_TOKEN=' -e 'hard-codes the real agy directory')"

echo
echo "result: $PASS pass, $FAIL fail"
[ "$FAIL" -eq 0 ]
