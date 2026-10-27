# Linux platform layer. Sourced by bin/agyr and bin/agy-run; never run on its own.
#
# The login is agy's token file (the file backend). agy >= 1.2.14 reads its login from the GNOME keyring (libsecret, over
# D-Bus) instead and ignores the token file while the keyring is reachable, so swapping the file changes nothing (observed
# 2026-10-02: the banner kept showing the old account and every account measured the same quota). Without a reachable
# session bus agy falls back to the token file in its HOME, so every agy started by agyr or agy-run gets this unreachable
# bus address.
PLATFORM_ENV_KEYRING=(DBUS_SESSION_BUS_ADDRESS=unix:path=/nonexistent)
# Git Bash argument conversion does not exist here, so nothing has to be excluded from it (see windows/platform.sh).
PLATFORM_ENV_NOCONV_QUOTA=()
PLATFORM_ENV_NOCONV_ALL=()
# setsid gives agy its own process group (agy-run kills the group) and, for agyr's quota calls, no controlling terminal:
# several agy processes measuring in parallel otherwise change and restore the terminal mode and garble it. Not every
# system has setsid (macOS, Git Bash), so the arrays stay empty when it is missing.
PLATFORM_DETACH=()      # agy-run
PLATFORM_DETACH_WAIT=() # agyr: waits until agy has finished
if command -v setsid >/dev/null; then PLATFORM_DETACH=(setsid); PLATFORM_DETACH_WAIT=(setsid -w); fi

platform_init() { :; } # nothing to prepare on Linux

# Path of a directory as agy should receive it. Linux paths need no conversion.
platform_arg_path() { printf '%s\n' "$1"; }

# Stop the whole process tree of agy started as bash PID $1. Windows only: on Linux the caller uses the process group,
# so this returns 1 ("not handled").
platform_kill_tree() { return 1; }
