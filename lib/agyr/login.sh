live_load() {
  LIVE=""
  case "$BACKEND" in
    file) if [ -f "$TOKEN" ]; then LIVE="$TOKEN"; fi ;;
    wincred)
      [ -n "$LIVE_TMP" ] || LIVE_TMP="$(mktemp -d)"
      rm -f "$LIVE_TMP/live"
      local rc=0
      "$CRED_HELPER" read "$LIVE_TMP/live" || rc=$?
      case "$rc" in
        0) LIVE="$LIVE_TMP/live" ;;
        3) ;;
        *) die "cannot read the login from Credential Manager (helper exit $rc)" ;;
      esac
      ;;
  esac
  return 0
}

# install file $1 as the login in use
live_put() {
  case "$BACKEND" in
    file) atomic_cp "$1" "$TOKEN" || die "cannot write the login ($TOKEN)"; LIVE="$TOKEN" ;;
    wincred)
      "$CRED_HELPER" write "$1" || die "cannot write the login to Credential Manager"
      # LIVE now mirrors what was just written
      [ -n "$LIVE_TMP" ] || LIVE_TMP="$(mktemp -d)"
      cp "$1" "$LIVE_TMP/live.new" && mv -f "$LIVE_TMP/live.new" "$LIVE_TMP/live"; LIVE="$LIVE_TMP/live"
      ;;
  esac
}

# remove the login in use (only to undo a measurement that started with no login at all)
live_clear() {
  case "$BACKEND" in
    file) rm -f "$TOKEN" ;;
    wincred) "$CRED_HELPER" delete || [ $? -eq 3 ] ;;
  esac
  LIVE=""
}

# wincred only: whoever swaps the one shared login must hold this lock (mkdir is atomic); a lock whose owner is gone is stolen
# One agyr at a time may change the login in use, the slots or state.json. It used to cover only the Windows backend; on Linux
# several parallel agy-run switching accounts at once corrupted slots (a slot ended up with another account's login).
# The lock is a file created exclusively (bash noclobber = open with O_EXCL) holding the owner's pid. NOT mkdir: on this
# machine mkdir is uutils coreutils, whose mkdir let 2 to 7 of 12 parallel callers all "create" the same directory.
lock_acquire() {
  [ "$LOCK_HELD" = 0 ] || return 0
  mkdir -p "$ACCTS"
  local waited=0 owner
  # a lock left by an older agyr was a directory holding a pid file
  if [ -d "$LOCKDIR" ]; then
    owner="$(cat "$LOCKDIR/pid" 2>/dev/null || true)"
    if [ -z "$owner" ] || ! kill -0 "$owner" 2>/dev/null; then rm -rf "$LOCKDIR"; fi
  fi
  until ( set -o noclobber; echo "$$" >"$LOCKDIR" ) 2>/dev/null; do
    owner="$(cat "$LOCKDIR" 2>/dev/null || true)"
    if [ -n "$owner" ] && ! kill -0 "$owner" 2>/dev/null; then
      # looks abandoned (its owner is gone). But that owner may simply have released it and exited, and somebody else taken
      # the lock since: remove it only if it still names that same dead owner (else two agyr would both hold the lock)
      if [ "$(cat "$LOCKDIR" 2>/dev/null || true)" = "$owner" ]; then rm -f "$LOCKDIR"; fi
      continue
    fi
    waited=$((waited + 1))
    [ "$waited" -le $((${AGYR_LOCK_WAIT:-120} * 20)) ] || die "another agyr is switching accounts (lock: $LOCKDIR); try again in a moment"
    sleep 0.05
  done
  LOCK_HELD=1
}

lock_release() {
  # only remove the lock if it is still ours
  if [ "$LOCK_HELD" = 1 ]; then
    if [ "$(cat "$LOCKDIR" 2>/dev/null || true)" = "$$" ]; then
      rm -f "$LOCKDIR" 2>/dev/null || { sleep 0.02; rm -f "$LOCKDIR" 2>/dev/null || true; }
    fi
    LOCK_HELD=0
  fi
  return 0
}

on_exit() {
  local rc=$?
  trap - EXIT
  # interrupted while a measurement had another account's login installed: put the original back
  case "$RESTORE_KIND" in
    file) "$CRED_HELPER" write "$RESTORE_FILE" || echo "agyr: COULD NOT RESTORE your login; the original is in $RESTORE_FILE" >&2 ;;
    none) "$CRED_HELPER" delete || true ;;
  esac
  [ -z "$LIVE_TMP" ] || rm -rf "$LIVE_TMP"
  [ -z "$LIVE_SNAP" ] || rm -f "$LIVE_SNAP"
  rm -f "$ACCTS"/.snap.$$.* 2>/dev/null || true
  lock_release
  exit "$rc"
}
trap on_exit EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Internal identity of a token file, for comparison only — NEVER printed: the refresh_token if it is JSON, else the whole content.
ident_of() {
  local r
  r="$(jq -r '.token.refresh_token // empty' "$1" 2>/dev/null)" || r=""
  if [ -n "$r" ]; then printf 'rt:%s' "$r"; else printf 'raw:%s' "$(cat "$1")"; fi
}

# The slot the real token file belongs to (by identity); empty if it matches no slot (e.g. just logged in to an unsaved account).
# The slot whose login is the one in FILE (matched by identity); empty when it matches no slot.
owner_of() {
  [ -s "$1" ] || return 0
  local id n
  id="$(ident_of "$1")"
  while read -r n; do
    if [ "$(ident_of "$ACCTS/$n.token")" = "$id" ]; then echo "$n"; return 0; fi
  done < <(slots)
  return 0
}
real_owner() {
  [ -n "$LIVE" ] || return 0
  owner_of "$LIVE"
}

# Write DEST by renaming a private temp file from the same directory: nobody (agy starting, a measurement copying a slot)
# ever reads a half-written login.
atomic_cp() {
  local tmp
  tmp="$(mktemp "$2.XXXXXX")" || return 1
  if cp "$1" "$tmp" && chmod 600 "$tmp" && mv -f "$tmp" "$2"; then return 0; fi
  rm -f "$tmp"; return 1
}

# A private copy of the login in use; prints its path (nothing when nobody is logged in). Decisions and write-backs are made
# from this one copy, so they always agree even if the live file changes in the meantime (it is shared with agy and with
# every other agyr / agy-run). Removed by the caller, or at exit.
live_snapshot() {
  [ -n "$LIVE" ] || return 0
  local f
  f="$(mktemp "$ACCTS/.snap.$$.XXXXXX")" || return 1
  if cp "$LIVE" "$f"; then echo "$f"; else rm -f "$f"; return 1; fi
}

# The account actually in use = the slot matching the real token file. Only when no slot matches do we fall back to the name
# stored in state (state can be stale when you log in with agyr by hand without saving).
active_name() {
  local o
  o="$(real_owner)"
  if [ -n "$o" ]; then echo "$o"; else jq -r '.active // ""' "$STATE"; fi
}

