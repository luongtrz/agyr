#!/usr/bin/env bash
# Independent core test section.
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$TEST_DIR/lib.sh"

echo "== root install.sh (auto-detects platform)"
INST_AUTO="$(mktemp -d)"; TMPS+=("$INST_AUTO")
REPO_ABS="$(cd "$HERE/.." && pwd)"
if bash "$HERE/../install.sh" "$INST_AUTO/bin" >/dev/null 2>&1; then pass "root install.sh runs"; else fail "root install.sh runs"; fi
has "root install.sh installs working agyr" "agyr" "$("$INST_AUTO/bin/agyr" help 2>&1 | head -1)"

exit 0
