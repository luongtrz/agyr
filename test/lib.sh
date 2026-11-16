#!/usr/bin/env bash
# Shared test helpers. Each test section sources this in its own bash process.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACCT="$HERE/../bin/agyr"
RUN="$HERE/../bin/agy-run"
TASK="$HERE/../bin/agy-task"
export AGY_BIN="$HERE/fake-agy"
export AGY_ACCT="$ACCT"
export AGY_RUN_POLL=0.1
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) ON_WINDOWS=1 ;; *) ON_WINDOWS=0 ;; esac
export AGYR_BACKEND=file AGYR_CRED_HELPER="$HERE/fake-cred" AGY_CRED_TARGET="agyr-test:never-real"
export TZ=UTC-7
export AGY_NOW=1000000
unset FAKE_CRED_FILE AGY_HOME AGY_RUN AGY_RUN_MAX_SWITCH

# Drop caller-supplied fake state so each section starts from the same clean environment.
while IFS= read -r env_name; do
  case "$env_name" in FAKE_*) unset "$env_name" ;; esac
done < <(compgen -e)
FAKE_TASK_RUN="$HERE/fake-agy-run"
export FAKE_KEYRING=1

# A native Windows jq.exe prints CRLF; -b keeps the assertions below honest.
if jq -b -n . >/dev/null 2>&1; then jq() { command jq -b "$@"; }; fi

PASS=0 FAIL=0
pass() { PASS=$((PASS + 1)); echo "  ok   $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL $1"; [ $# -gt 1 ] && echo "       $2"; }
eq() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "expected '$2', got '$3'"; fi; }
has() { if grep -qF -- "$2" <<<"$3"; then pass "$1"; else fail "$1" "'$2' not found in: $3"; fi; }
hasnt() { if grep -qF -- "$2" <<<"$3"; then fail "$1" "must not contain '$2' in: $3"; else pass "$1"; fi; }

TMPS=()
# Safety net: until a section calls setup(), any agyr / agy-run / agy-task command it runs must see a throw-away pool, never the
# real account pool. (In the old single-process run a section silently inherited AGY_HOME from the previous section's last setup().)
SANDBOX="$(mktemp -d)"; TMPS+=("$SANDBOX")
export AGY_HOME="$SANDBOX/home"; mkdir -p "$AGY_HOME"
export FAKE_ARGS_LOG="$SANDBOX/args.log"; : >"$FAKE_ARGS_LOG"
# Number of fake-agy processes started by THIS section: they inherit its exported FAKE_ARGS_LOG. A plain pgrep would also count the
# fake-agy processes of the other sections that run in parallel.
leaked_fake_agy() {
  local p n=0
  for p in $(pgrep -f "$HERE/fake-agy" 2>/dev/null); do
    if [ -r "/proc/$p/environ" ] && tr '\0' '\n' <"/proc/$p/environ" 2>/dev/null | grep -qxF "FAKE_ARGS_LOG=$FAKE_ARGS_LOG"; then n=$((n + 1)); fi
  done
  echo "$n"
}
cleanup() {
  local d
  for d in "${TMPS[@]:-}"; do
    [ -n "$d" ] && rm -rf "$d"
  done
}
section_finish() {
  local rc=$?
  cleanup
  if [ -n "${SECTION_RESULT:-}" ]; then
    printf '%s %s\n' "$PASS" "$FAIL" >"$SECTION_RESULT"
  fi
  [ "$FAIL" -eq 0 ] || rc=1
  exit "$rc"
}
if [ "${AGYR_SECTION_WORKER:-0}" = 1 ]; then
  trap section_finish EXIT
else
  trap cleanup EXIT
fi

# 3-account pool; acc1 is active, token = tok-acc1
setup() {
  T="$(mktemp -d)"; TMPS+=("$T")
  export AGY_HOME="$T/home"; mkdir -p "$AGY_HOME"
  export AGY_NOW=1000000
  export FAKE_ARGS_LOG="$T/args.log"; : >"$FAKE_ARGS_LOG"
  unset FAKE_QUOTA_TOKENS FAKE_AUTH FAKE_AUTH_ECHO FAKE_AUTH_RESULT FAKE_RESET AGY_RUN_MAX_SWITCH
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

ESC=$'\033'
GREEN="${ESC}[32m"; YELLOW="${ESC}[33m"; RED="${ESC}[31m"
strip() { sed "s/${ESC}\[[0-9;]*m//g"; }
hi_lines() { grep -F -- '|-p Hi ' "$FAKE_ARGS_LOG"; }
hi_count() { hi_lines | wc -l | tr -d ' '; }
nopct() { sed -E 's/[0-9]+%>[0-9]+%/P%>P%/g; s/ok in [0-9]+s/ok in Ns/g'; }

# 12 accounts a01..a12, a01 in use
mk12() {
  T="$(mktemp -d)"; TMPS+=("$T")
  export AGY_HOME="$T/home"; mkdir -p "$AGY_HOME"
  export AGY_NOW=1000000
  export FAKE_ARGS_LOG="$T/args.log"; : >"$FAKE_ARGS_LOG"
  unset FAKE_QUOTA_TOKENS FAKE_AUTH FAKE_RESET AGY_RUN_MAX_SWITCH FAKE_REFRESH FAKE_WEEK_ORDER
  local i a
  for i in 01 02 03 04 05 06 07 08 09 10 11 12; do
    a="a$i"; echo "tok-$a" >"$AGY_HOME/antigravity-oauth-token"; "$ACCT" save "$a" >/dev/null
  done
  "$ACCT" use a01 >/dev/null
  echo "do the thing" >"$T/prompt.txt"; mkdir -p "$T/work"
}
