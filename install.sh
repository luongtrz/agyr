#!/usr/bin/env bash
# Unified install script for agyr, agy-run, and agy-task.
# Auto-detects the operating system and delegates to the platform-specific installer.
#
# Usage: ./install.sh [BIN_DIR]        (default: ~/.local/bin)
set -euo pipefail

REPO="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    exec bash "$REPO/platforms/windows/install.sh" "$@"
    ;;
  *)
    exec bash "$REPO/platforms/linux/install.sh" "$@"
    ;;
esac
