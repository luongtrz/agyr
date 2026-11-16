die() { echo "agyr: $*" >&2; exit "${2:-1}"; }
now() { echo "${AGY_NOW:-$(date +%s)}"; }

need_jq() { command -v jq >/dev/null || die "jq is required"; }

valid_name() { [[ "$1" =~ ^[A-Za-z0-9_-]+$ ]] || die "account name may only contain letters, digits, '-' and '_': '$1'"; }
init_state() {
  mkdir -p "$ACCTS"
  chmod 700 "$ACCTS"
  [ -f "$STATE" ] || echo '{"active":"","cooldown":{},"locked":{}}' >"$STATE"
}

# atomic state write: $1 = jq expression, remaining args are passed to jq
state_update() {
  local expr="$1"; shift
  local tmp own=0
  # read-modify-write of state.json: take the lock (unless this process already holds it), or two agyr running at the same
  # time (parallel agy-run switching accounts) overwrite each other's change
  if [ "$LOCK_HELD" = 0 ]; then lock_acquire; own=1; fi
  tmp="$(mktemp "$ACCTS/.state.XXXXXX")"
  if jq "$@" "$expr" "$STATE" >"$tmp"; then mv "$tmp" "$STATE"; else rm -f "$tmp"; die "failed to write state"; fi
  if [ "$own" = 1 ]; then lock_release; fi
}
parse_duration() {
  local s="$1"
  if [[ "$s" =~ Resets\ in\ ([0-9dhms]+) ]]; then s="${BASH_REMATCH[1]}"; fi
  if [[ "$s" =~ ^[0-9]+$ ]]; then echo "$s"; return 0; fi
  [[ "$s" =~ ^([0-9]+d)?([0-9]+h)?([0-9]+m)?([0-9]+s)?$ && -n "$s" ]] || return 1
  local total=0 d=${BASH_REMATCH[1]:-} h=${BASH_REMATCH[2]:-} m=${BASH_REMATCH[3]:-} sec=${BASH_REMATCH[4]:-}
  [ -n "$d" ] && total=$((total + ${d%d} * 86400))
  [ -n "$h" ] && total=$((total + ${h%h} * 3600))
  [ -n "$m" ] && total=$((total + ${m%m} * 60))
  [ -n "$sec" ] && total=$((total + ${sec%s}))
  echo "$total"
}

# epoch -> "dd/mm/yyyy hh:mm AM|PM" (in AGY_TZ)
fmt_time() { date -d "@$1" '+%d/%m/%Y %I:%M %p'; }
fmt_short_time() { date -d "@$1" '+%d/%m %H:%M'; }

fmt_dur() { # seconds -> "4h13m"
  local s=$1
  if [ "$s" -ge 3600 ]; then printf '%dh%02dm' $((s / 3600)) $((s % 3600 / 60))
  elif [ "$s" -ge 60 ]; then printf '%dm%02ds' $((s / 60)) $((s % 60))
  else printf '%ds' "$s"; fi
}

slots() { # sorted slot names
  local f
  for f in "$ACCTS"/*.token; do
    [ -e "$f" ] || continue
    basename "$f" .token
  done | sort
}

cooldown_until() { jq -r --arg n "$1" '.cooldown[$n] // 0' "$STATE"; }

is_locked() { [ "$(jq -r --arg n "$1" '((.locked // {})[$n] == true)' "$STATE" 2>/dev/null)" = "true" ]; }
