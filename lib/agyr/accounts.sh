cmd_save() {
  [ $# -eq 1 ] || die "usage: agyr save <name>"
  valid_name "$1"; need_jq
  init_state
  lock_acquire
  live_load # again: the login may have changed while waiting for the lock
  [ -n "$LIVE" ] || die "no login yet (${TOKEN_WHERE}). Log in with 'agyr' first"
  atomic_cp "$LIVE" "$ACCTS/$1.token" || die "cannot write slot '$1'"
  state_update '.active=$n | del(.cooldown[$n])' --arg n "$1"
  echo "saved account '$1' (now active)"
}

cmd_use() {
  [ $# -eq 1 ] || die "usage: agyr use <name>"
  valid_name "$1"; need_jq; init_state
  [ -f "$ACCTS/$1.token" ] || die "no slot '$1' (see: agyr list)"
  lock_acquire
  live_load # again: the login may have changed while waiting for the lock
  local snap cur=""
  snap="$(live_snapshot)"
  if [ -n "$snap" ]; then
    # Which slot the login in use belongs to is decided from the SAME copy that is written back: it can only ever go to the
    # slot with the same account (a write-back that re-read the live file once lost to another switch and put one account's
    # login into another's slot)
    cur="$(owner_of "$snap")"
    # backup first, before anything is overwritten
    atomic_cp "$snap" "$ACCTS/.last-token.bak"
    # keep the access token agy refreshed, but only write it back to the slot it belongs to; if it matches no slot,
    # no slot is overwritten (the unsaved token is still in .last-token.bak)
    if [ -n "$cur" ] && [ "$cur" != "$1" ]; then atomic_cp "$snap" "$ACCTS/$cur.token"; fi
    rm -f "$snap"
  fi
  live_put "$ACCTS/$1.token"
  lock_release
  state_update '.active=$n' --arg n "$1"
  echo "switched to account '$1'"
}

cmd_cooldown() {
  [ $# -ge 2 ] || die "usage: agyr cooldown <name> <duration|'... Resets in 4h13m27s'>"
  local name="$1"; shift
  valid_name "$name"; need_jq; init_state
  [ -f "$ACCTS/$name.token" ] || die "no slot '$name'"
  local secs
  if ! secs="$(parse_duration "$*")"; then
    echo "agyr: cannot parse duration '$*', using default 5h" >&2
    secs=$DEFAULT_COOLDOWN
  fi
  local until=$(($(now) + secs))
  state_update '.cooldown[$n]=$u' --arg n "$name" --argjson u "$until"
  echo "account '$name' cooldown $(fmt_dur "$secs") (reset $(fmt_time "$until"))"
}

# rename <old> <new>: rename a slot. The login, the cooldown and the saved quota data move with it; nothing else changes
# (the real token file is not touched, no agy is started).
cmd_rename() {
  [ $# -eq 2 ] || die "usage: agyr rename <old> <new>"
  local old="$1" new="$2"
  valid_name "$old"; valid_name "$new"; need_jq; init_state
  lock_acquire # a concurrent use must not write a slot under the old name while it is being renamed
  [ "$old" != "$new" ] || die "old and new names are the same: '$old'"
  [ -f "$ACCTS/$old.token" ] || die "no slot '$old' (see: agyr list)"
  [ ! -e "$ACCTS/$new.token" ] || die "slot '$new' already exists; nothing was changed (remove it first if you really want to replace it)"
  mv "$ACCTS/$old.token" "$ACCTS/$new.token"
  state_update '(if .active == $o then .active = $n else . end)
    | (if ((.cooldown // {}) | has($o)) then .cooldown[$n] = .cooldown[$o] | del(.cooldown[$o]) else . end)
    | (if ((.locked // {}) | has($o)) then .locked[$n] = .locked[$o] | del(.locked[$o]) else . end)
    | (if ((.quota // {}) | has($o)) then .quota[$n] = .quota[$o] | del(.quota[$o]) else . end)
    | (if .ui_order then .ui_order |= map(if . == $o then $n else . end) else . end)' --arg o "$old" --arg n "$new"
  echo "renamed slot '$old' to '$new'"
}

cmd_del() {
  [ $# -eq 1 ] || die "usage: agyr del <name>"
  local name="$1"
  valid_name "$name"; need_jq; init_state
  lock_acquire
  live_load
  [ -f "$ACCTS/$name.token" ] || die "no slot '$name' (see: agyr list)"
  local is_live=0
  if [ -n "$LIVE" ] && [ "$(ident_of "$LIVE")" = "$(ident_of "$ACCTS/$name.token")" ]; then
    is_live=1
  fi
  if [ -f "$ACCTS/.last-token.bak" ] && [ "$(ident_of "$ACCTS/.last-token.bak")" = "$(ident_of "$ACCTS/$name.token")" ]; then
    rm -f "$ACCTS/.last-token.bak"
  fi
  rm -f "$ACCTS/$name.token"
  if [ "$is_live" = 1 ]; then
    live_clear
  fi
  state_update '(if .active == $n then .active = "" else . end) | del(.cooldown[$n]) | del(.locked[$n]) | del(.quota[$n]) | (if .ui_order then .ui_order |= map(select(. != $n)) else . end)' --arg n "$name"
  lock_release
  if [ "$is_live" = 1 ]; then
    echo "deleted account '$name' (and cleared active login)"
  else
    echo "deleted account '$name'"
  fi
}

cmd_clear() {
  [ $# -eq 1 ] || die "usage: agyr clear <name>"
  valid_name "$1"; need_jq; init_state
  state_update 'del(.cooldown[$n])' --arg n "$1"
  echo "cleared cooldown of '$1'"
}

cmd_lock() {
  [ $# -eq 1 ] || die "usage: agyr lock <name>"
  local name="$1"
  valid_name "$name"; need_jq; init_state
  [ -f "$ACCTS/$name.token" ] || die "no slot '$name'"
  if is_locked "$name"; then
    echo "account '$name' is already locked"
    return 0
  fi
  state_update '.locked = ((.locked // {}) | .[$n] = true)' --arg n "$name"
  echo "locked account '$name'"
  if [ "$name" = "$(active_name)" ]; then
    echo "note: '$name' is currently in use; it stays in use until the next quota hit or 'agyr use <other>'"
  fi
}

cmd_unlock() {
  [ $# -eq 1 ] || die "usage: agyr unlock <name>"
  local name="$1"
  valid_name "$name"; need_jq; init_state
  [ -f "$ACCTS/$name.token" ] || die "no slot '$name'"
  if ! is_locked "$name"; then
    echo "account '$name' is not locked"
    return 0
  fi
  state_update 'if .locked then del(.locked[$n]) else . end' --arg n "$name"
  echo "unlocked account '$name'"
}

cmd_locked() {
  need_jq; init_state
  if [ $# -gt 1 ]; then die "usage: agyr locked [<name>]" 2; fi
  if [ $# -eq 1 ]; then
    local name="$1"
    valid_name "$name"
    [ -f "$ACCTS/$name.token" ] || die "no slot '$name'" 2
    if is_locked "$name"; then
      return 0
    else
      return 1
    fi
  fi
  local n
  while read -r n; do
    [ -n "$n" ] || continue
    if is_locked "$n"; then echo "$n"; fi
  done < <(slots)
}

cmd_swapui() {
  need_jq; init_state
  if [ $# -eq 1 ] && { [ "$1" = "--reset" ] || [ "$1" = "reset" ]; }; then
    lock_acquire
    state_update 'del(.ui_order)'
    lock_release
    echo "reset UI display order to default (weekly limit reset order)"
    return 0
  fi
  [ $# -eq 2 ] || die "usage: agyr swapui <name1> <name2> (or: agyr swapui --reset)"
  local a="$1" b="$2"
  valid_name "$a"; valid_name "$b"
  [ -f "$ACCTS/$a.token" ] || die "no slot '$a' (see: agyr list)"
  [ -f "$ACCTS/$b.token" ] || die "no slot '$b' (see: agyr list)"
  [ "$a" != "$b" ] || die "cannot swap an account with itself: '$a'"
  lock_acquire
  local -a def_arr=()
  mapfile -t def_arr < <(rows_by_week_reset " ")
  local def_json="[]"
  if [ "${#def_arr[@]}" -gt 0 ]; then
    def_json="$(printf '%s\n' "${def_arr[@]}" | jq -R . | jq -s .)"
  fi
  state_update '
    (if (.ui_order // []) | length == 0 then $def else .ui_order end) as $base
    | ($base + [$def[] | select(. as $x | ($base | index($x)) == null)]) as $arr
    | ($arr | index($a)) as $ia
    | ($arr | index($b)) as $ib
    | if $ia != null and $ib != null then
        .ui_order = ($arr | .[$ia] = $b | .[$ib] = $a)
      else
        .
      end
  ' --arg a "$a" --arg b "$b" --argjson def "$def_json"
  lock_release
  echo "swapped UI positions of '$a' and '$b' in 'agyr list'"
}

# Print the account to switch to: among the READY accounts (no cooldown, not locked) the one whose weekly limit resets soonest, from the last
# measurement (the same order 'agyr list' shows); accounts never measured come last, ties by name. The account in use is only
# returned when nothing else is ready. Locked accounts are skipped entirely. If none is ready: exit 3 and report the earliest end of a cooldown
# (or that accounts are on cooldown or locked).
cmd_active() { need_jq; init_state; active_name; }

cmd_backend() { echo "$BACKEND"; }

# forget [--force]: drop the login in use LOCALLY so agy asks for a new login (replaces 'rm <token file>'; nothing is revoked at Google).
# Refuses when the login belongs to no slot (it would be lost), unless --force; it is always backed up first.
cmd_forget() {
  local force=0
  case "${1:-}" in
    "") ;;
    -f|--force) force=1 ;;
    *) die "usage: agyr forget [-f|--force]" 2 ;;
  esac
  need_jq; init_state
  lock_acquire
  live_load # again: the login may have changed while waiting for the lock
  if [ -z "$LIVE" ]; then echo "no login in use; nothing to forget"; lock_release; return 0; fi
  local snap cur
  snap="$(live_snapshot)"; cur="$(owner_of "$snap")"
  if [ -z "$cur" ] && [ "$force" = 0 ]; then
    rm -f "$snap"
    die "the login in use matches no slot, so forgetting it would lose it: run 'agyr save <name>' first (or 'agyr forget --force'; it is kept in $ACCTS/.last-token.bak either way)"
  fi
  atomic_cp "$snap" "$ACCTS/.last-token.bak"
  if [ -n "$cur" ]; then atomic_cp "$snap" "$ACCTS/$cur.token"; fi # keep the freshest copy
  rm -f "$snap"
  live_clear
  state_update '.active=""' # nobody is logged in now: 'agyr active' prints nothing and agy-run stops with "no active account"
  lock_release
  echo "login removed from this machine${cur:+ (still saved as slot '$cur')}; nothing was revoked at Google."
  echo "run 'agyr' to log in to another account, then 'agyr save <name>'"
}
