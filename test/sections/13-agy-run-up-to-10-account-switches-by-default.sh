#!/usr/bin/env bash
# Independent core test section.
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$TEST_DIR/lib.sh"

echo "== agy-run: up to 10 account switches by default"
mk12
export FAKE_QUOTA_TOKENS="tok-a01 tok-a02 tok-a03 tok-a04 tok-a05 tok-a06 tok-a07 tok-a08 tok-a09 tok-a10"
runit; rc=$?
eq "10 exhausted accounts -> 10 switches are allowed by default, the 11th account answers (exit 0)" "0" "$rc"
eq "that took 11 runs" "11" "$(lines)"
has "the last run used a11" "tok-a11|" "$(tail -1 "$FAKE_ARGS_LOG")"
mk12
export FAKE_QUOTA_TOKENS="tok-a01 tok-a02 tok-a03 tok-a04 tok-a05 tok-a06 tok-a07 tok-a08 tok-a09 tok-a10 tok-a11"
runit; rc=$?
eq "11 exhausted accounts -> the 11th switch is refused (exit 6)" "6" "$rc"
has "the message names the limit" "switched accounts 10 times" "$(cat "$T/run.err")"
unset FAKE_QUOTA_TOKENS
has "agy-run --help: documents the default of 10" "AGY_RUN_MAX_SWITCH (default 10)" "$("$RUN" --help 2>&1)"
mk12; export FAKE_QUOTA_TOKENS="tok-a01 tok-a02 tok-a03" AGY_RUN_MAX_SWITCH=2
runit; rc=$?
eq "AGY_RUN_MAX_SWITCH still overrides the default (2 -> exit 6)" "6" "$rc"
unset FAKE_QUOTA_TOKENS AGY_RUN_MAX_SWITCH

exit 0
