#!/usr/bin/env bash
# Tests for agyr and agy-run. Uses fake tokens and a fake agy; never touches the real token.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib.sh"

REAL_TOKEN="$HOME/.gemini/antigravity-cli/antigravity-oauth-token"
REAL_MTIME_BEFORE="$(stat -c %Y "$REAL_TOKEN" 2>/dev/null || echo none)"
# real agy / agy-run processes (not fake-agy) rewrite the real token file themselves (account switches, token refresh)
real_agy_busy() { pgrep -x agy >/dev/null 2>&1 || pgrep -x agy-run >/dev/null 2>&1; }
REAL_BUSY=0; real_agy_busy && REAL_BUSY=1

if [ "$#" -eq 0 ]; then
  SUITES=(core linux windows)
else
  SUITES=("$@")
fi
for suite in "${SUITES[@]}"; do
  case "$suite" in
    core|linux|windows) ;;
    *)
      echo "usage: test/run.sh [core|linux|windows ...]" >&2
      exit 2
      ;;
  esac
done

TASKS=()
for suite in "${SUITES[@]}"; do
  case "$suite" in
    core)
      for section in "$HERE"/sections/*.sh; do
        [ -f "$section" ] && TASKS+=("$section")
      done
      ;;
    linux|windows) TASKS+=("$HERE/$suite.sh") ;;
  esac
done

if [ -n "${JOBS:-}" ]; then
  JOBS="$JOBS"
else
  if command -v nproc >/dev/null 2>&1; then
    cpu_count="$(nproc 2>/dev/null || echo 2)"
  else
    cpu_count="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)"
  fi
  case "$cpu_count" in ''|*[!0-9]*) cpu_count=2 ;; esac
  JOBS=$((cpu_count / 2))
  [ "$JOBS" -ge 1 ] || JOBS=1
  [ "$JOBS" -le 4 ] || JOBS=4
fi
case "$JOBS" in ''|*[!0-9]*)
  echo "JOBS must be a positive integer" >&2
  exit 2
  ;;
esac
JOBS=$((10#$JOBS))
if [ "$JOBS" -le 0 ]; then
  echo "JOBS must be a positive integer" >&2
  exit 2
fi

RUN_TMP="$(mktemp -d "${TMPDIR:-/tmp}/agyr-tests.XXXXXX")" || exit 1
driver_cleanup() {
  cleanup
  rm -f "$RUN_TMP"/*
  rmdir "$RUN_TMP" 2>/dev/null || true
}
trap driver_cleanup EXIT

declare -a TASK_PIDS=()
declare -a TASK_INDEXES=()
declare -a TASK_STATUS=()
ACTIVE_COUNT=0 REAPED=0
reap_finished() {
  local running_set pid task_index rc slot old_count write_slot
  running_set=$'\n'"$(jobs -pr 2>/dev/null)"$'\n'
  REAPED=0
  old_count=$ACTIVE_COUNT
  write_slot=0
  for ((slot = 0; slot < old_count; slot++)); do
    pid=${TASK_PIDS[$slot]}
    task_index=${TASK_INDEXES[$slot]}
    case "$running_set" in
      *$'\n'"$pid"$'\n'*)
        TASK_PIDS[$write_slot]="$pid"
        TASK_INDEXES[$write_slot]="$task_index"
        write_slot=$((write_slot + 1))
        ;;
      *)
        wait "$pid"; rc=$?
        TASK_STATUS[$task_index]="$rc"
        REAPED=$((REAPED + 1))
        ;;
    esac
  done
  for ((slot = write_slot; slot < old_count; slot++)); do
    unset "TASK_PIDS[$slot]" "TASK_INDEXES[$slot]"
  done
  ACTIVE_COUNT=$write_slot
}

for ((i = 0; i < ${#TASKS[@]}; i++)); do
  printf -v task_id '%03d' "$i"
  output_file="$RUN_TMP/$task_id.out"
  count_file="$RUN_TMP/$task_id.count"
  AGYR_SECTION_WORKER=1 SECTION_RESULT="$count_file" nice -n 10 bash "${TASKS[$i]}" >"$output_file" 2>&1 &
  TASK_PIDS+=("$!")
  TASK_INDEXES+=("$i")
  ACTIVE_COUNT=$((ACTIVE_COUNT + 1))
  while [ "$ACTIVE_COUNT" -ge "$JOBS" ]; do
    reap_finished
    [ "$REAPED" -gt 0 ] || sleep 0.05
  done
done

while [ "$ACTIVE_COUNT" -gt 0 ]; do
  reap_finished
  [ "$REAPED" -gt 0 ] || sleep 0.05
done

# Print completed logs in their original suite and section order, independent of finish order.
for ((i = 0; i < ${#TASKS[@]}; i++)); do
  printf -v task_id '%03d' "$i"
  output_file="$RUN_TMP/$task_id.out"
  count_file="$RUN_TMP/$task_id.count"
  [ -f "$output_file" ] && cat "$output_file"

  section_pass=0 section_fail=0
  if [ -f "$count_file" ] && read -r section_pass section_fail <"$count_file" \
    && [[ "$section_pass" =~ ^[0-9]+$ && "$section_fail" =~ ^[0-9]+$ ]]; then
    PASS=$((PASS + section_pass))
    FAIL=$((FAIL + section_fail))
  else
    section_pass=0 section_fail=1
    fail "section process failed ($(basename "${TASKS[$i]}"))" "result counters were not written"
  fi

  section_rc="${TASK_STATUS[$i]:-1}"
  if [ "$section_rc" -ne 0 ] && [ "$section_fail" -eq 0 ]; then
    fail "section process failed ($(basename "${TASKS[$i]}"))" "exit code $section_rc"
  fi
done

echo "== safety"
real_agy_busy && REAL_BUSY=1
if [ "$REAL_BUSY" = 1 ]; then
  echo "  skip the real token mtime check: real agy / agy-run processes are running and rewrite that file themselves"
else
  eq "the real token is untouched (mtime)" "$REAL_MTIME_BEFORE" "$(stat -c %Y "$REAL_TOKEN" 2>/dev/null || echo none)"
fi
# static guarantee, valid even when the check above is skipped: no test code points at the real agy directory
eq "no test code hard-codes the real agy directory (only the read-only REAL_TOKEN probe)" "0" "$(grep -n '\.gemini' "$HERE"/*.sh "$HERE"/fake-* "$HERE"/sections/*.sh | grep -vc -e 'REAL_TOKEN=' -e 'hard-codes the real agy directory')"

echo
echo "result: $PASS pass, $FAIL fail"
[ "$FAIL" -eq 0 ]
