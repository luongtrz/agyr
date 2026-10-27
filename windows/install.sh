#!/usr/bin/env bash
# Install agyr, agy-run and agy-task as small wrappers that run this clone (Windows, Git Bash).
#
# Usage: windows/install.sh [BIN_DIR]     (default: ~/.local/bin)
#
# Git Bash cannot make working symlinks here, so each command is a one-line script that execs bin/<name> in this clone.
# The clone path is written into the wrappers: run this script again if the clone is moved. It only writes those wrappers.
# It never logs in, never saves or forgets a login, and never reads the Credential Manager entry.
set -euo pipefail

REPO="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
BIN_DIR="${1:-$HOME/.local/bin}"
COMMANDS=(agyr agy-run agy-task)

missing=0
for c in jq git; do
  if ! command -v "$c" >/dev/null; then echo "missing: $c (required; winget install jqlang.jq for jq)" >&2; missing=1; fi
done
[ "$missing" = 0 ] || exit 1

for n in "${COMMANDS[@]}"; do
  if [ -e "$BIN_DIR/$n" ] && [ ! -L "$BIN_DIR/$n" ]; then
    # a file this script did not write (a previous wrapper is also a plain file, so check its content first)
    if ! grep -q "$REPO/bin/$n" "$BIN_DIR/$n" 2>/dev/null; then
      echo "refusing to replace $BIN_DIR/$n: it is not a wrapper for this clone" >&2
      exit 1
    fi
  fi
done

mkdir -p "$BIN_DIR"
for n in "${COMMANDS[@]}"; do
  printf '#!/usr/bin/env bash\nexec "%s/bin/%s" "$@"\n' "$REPO" "$n" > "$BIN_DIR/$n"
  chmod +x "$BIN_DIR/$n"
  echo "wrote $BIN_DIR/$n -> $REPO/bin/$n"
done

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) echo "note: $BIN_DIR is not on PATH; add it before using the commands" ;;
esac
