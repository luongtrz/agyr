# Windows platform layer (Git Bash / MSYS / Cygwin). Sourced by bin/agyr and bin/agy-run; never run on its own.
#
# The login is ONE Windows Credential Manager entry (gemini:antigravity) that agy reads and that 'agyr use' overwrites, so
# agy needs no keyring trick here: the D-Bus bypass is Linux-only. The helper scripts in this folder read and write it.
PLATFORM_ENV_KEYRING=()
# Git Bash rewrites arguments that look like POSIX paths (a prompt such as "/quota ..." or "/tmp/x ...") before they reach
# the native agy.exe. These environment assignments switch that off for one call:
#   quota calls (agyr): /quota must stay the command, not become C:/Program Files/Git/quota (every account "failed")
#   agy-run:            the prompt and the --add-dir path are handed over exactly as given
PLATFORM_ENV_NOCONV_QUOTA=(MSYS2_ARG_CONV_EXCL=/quota)
PLATFORM_ENV_NOCONV_ALL=(MSYS2_ARG_CONV_EXCL='*')
# Git Bash has no setsid: agy is started plainly, and its process tree is stopped with taskkill (platform_kill_tree).
PLATFORM_DETACH=()
PLATFORM_DETACH_WAIT=()

platform_init() {
  # a native Windows jq.exe prints CRLF; the \r would end up inside names and numbers (-b / --binary prevents that)
  if command jq -b -n . >/dev/null 2>&1; then jq() { command jq -b "$@"; }; fi
}

# Path of a directory as the native agy.exe should receive it: cygpath -m gives the form with forward slashes.
platform_arg_path() {
  if command -v cygpath >/dev/null; then cygpath -m "$1"; else printf '%s\n' "$1"; fi
}

# Stop the whole process tree of the agy.exe started as bash PID $1 (taskkill), then reap it. Returns 1 when that is not
# possible (no taskkill, or no Windows PID for the process), so the caller falls back to the process group.
platform_kill_tree() {
  local pid="$1"
  if [ ! -r "/proc/$pid/winpid" ] || ! command -v taskkill >/dev/null; then return 1; fi
  taskkill //T //F //PID "$(cat "/proc/$pid/winpid")" >/dev/null 2>&1 || true
  kill -KILL "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  return 0
}
