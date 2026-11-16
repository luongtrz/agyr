#!/usr/bin/env bash
# Independent core test section.
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$TEST_DIR/lib.sh"

echo "== terminal"
if command -v script >/dev/null; then
  setup
  export FAKE_TTY=1
  cat >"$T/tty.sh" <<EOS
snap() { stty -a | grep -oE -- '(^|[ ])-?(onlcr|icanon|echo)([ ;]|\$)' | tr -d ' ;' | tr '\n' ' '; }
a="\$(snap)"
"$ACCT" list >/dev/null 2>&1
b="\$(snap)"
[ -n "\$a" ] && [ "\$a" = "\$b" ] && echo SAME || echo "DIFF: [\$a] -> [\$b]"
EOS
  out="$(script -qec "bash $T/tty.sh" /dev/null 2>&1 | tr -d '\r' | tail -n 1)"
  eq "list: leaves the terminal settings unchanged (parallel agy does not touch the tty)" "SAME" "$out"
  unset FAKE_TTY
else
  echo "  (skipped: no 'script' command)"
fi

exit 0
