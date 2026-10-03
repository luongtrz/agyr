#!/usr/bin/env bash
# cred.sh <read|write|delete> [FILE] — bash front end of cred.ps1 (Windows only: Git Bash / MSYS / Cygwin).
# FILE is a POSIX path; it is converted for PowerShell. Exit codes: 0 ok | 3 no such entry | 1 error | 2 bad usage.
# This is the interface agyr expects from AGYR_CRED_HELPER (the tests plug in a fake one).
set -euo pipefail

here="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
op="${1:-}"
args=()
case "$op" in
  read|write)
    [ $# -eq 2 ] || { echo "usage: cred.sh $op FILE" >&2; exit 2; }
    args=("$(cygpath -w "$2")")
    ;;
  delete) ;;
  *) echo "usage: cred.sh read|write FILE | cred.sh delete" >&2; exit 2 ;;
esac

exec powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass \
  -File "$(cygpath -w "$here/cred.ps1")" "$op" "${args[@]}"
