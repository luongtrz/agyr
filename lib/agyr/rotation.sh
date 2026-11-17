cmd_next() {
  local why=0
  case "${1:-}" in -v|--why) why=1 ;; esac
  need_jq; init_state
  local cur t n until gwr earliest=0 earliest_n="" fallback="" total=0 nother=0 pick="" nlocked=0
  cur="$(active_name)"; t="$(now)"
  while read -r n; do
    total=$((total + 1))
    if is_locked "$n"; then
      nlocked=$((nlocked + 1))
      continue
    fi
    until="$(cooldown_until "$n")"
    if [ "$until" -gt "$t" ]; then
      if [ "$earliest" -eq 0 ] || [ "$until" -lt "$earliest" ]; then earliest=$until; earliest_n=$n; fi
    else
      if [ "$n" = "$cur" ]; then fallback="$n"
      else nother=$((nother + 1)); if [ -z "$pick" ]; then pick="$n"; fi; fi
    fi
  done < <(rows_by_week_reset " ")
  [ "$total" -gt 0 ] || die "no accounts yet" 2
  if [ -z "$pick" ] && [ -n "$fallback" ]; then pick="$fallback"; fi
  if [ -n "$pick" ]; then
    if [ "$why" = 1 ]; then
      gwr="$(jq -r --arg n "$pick" '.quota[$n].gwr // empty' "$STATE")"
      if [ "$nother" -eq 0 ]; then echo "agyr: next account '$pick': no other account is ready, so the one in use stays" >&2
      elif [ -n "$gwr" ]; then echo "agyr: next account '$pick': weekly limit resets $(fmt_time "$gwr"), the soonest of the $nother other ready account(s)" >&2
      else echo "agyr: next account '$pick': no quota data yet (run 'agyr list'); first of the $nother other ready account(s) by name" >&2; fi
    fi
    echo "$pick"
    return 0
  fi
  local reason="on cooldown"
  if [ "$nlocked" -eq "$total" ]; then
    reason="locked"
  elif [ "$nlocked" -gt 0 ]; then
    reason="on cooldown or locked"
  fi
  if [ "$earliest" -gt 0 ]; then
    echo "agyr: all $total accounts are $reason; earliest: '$earliest_n' resets at $(fmt_time "$earliest") ($(fmt_dur $((earliest - t))) left)" >&2
  else
    echo "agyr: all $total accounts are $reason" >&2
  fi
  return 3
}

# Find the most recent quota hit in agy's logs; print the seconds left until reset (counted from "now").
# Log line format: E1001 12:49:02.672827 ... Individual quota reached ... Resets in 3h13m51s.
# Lines older than 1 hour are ignored (most likely from another account / an earlier hit).
detect_reset_secs() {
  local logdir="$AGY_HOME/log" f line best_ts=0 best_reset=0 ts reset d t y t0
  [ -d "$logdir" ] || return 1
  t0="$(now)"
  y="$(date -d "@$t0" +%Y)"
  while read -r f; do
    line="$(grep -E 'Individual quota reached.*Resets in [0-9dhms]+' "$f" | tail -n 1)" || true
    [ -n "$line" ] || continue
    if [[ "$line" =~ ^[A-Z]([0-9]{2})([0-9]{2})\ ([0-9:]{8}) ]]; then
      d="$y-${BASH_REMATCH[1]}-${BASH_REMATCH[2]}"; t="${BASH_REMATCH[3]}"
      ts="$(date -d "$d $t" +%s 2>/dev/null)" || continue
      [ "$ts" -gt $((t0 + 86400)) ] && ts="$(date -d "$((y - 1))-${BASH_REMATCH[1]}-${BASH_REMATCH[2]} $t" +%s)"
    else
      continue
    fi
    reset="$(parse_duration "$(grep -oE 'Resets in [0-9dhms]+' <<<"$line" | tail -n 1)")" || continue
    if [ "$ts" -gt "$best_ts" ]; then best_ts=$ts; best_reset=$reset; fi
  done < <(find "$logdir" -maxdepth 1 -name 'cli-*.log' -mmin -61 2>/dev/null)
  [ "$best_ts" -gt 0 ] || return 1
  [ $((t0 - best_ts)) -le 3600 ] || return 1
  local remain=$((best_ts + best_reset - t0))
  [ "$remain" -gt 0 ] || return 1
  echo "$remain"
}

# Out of quota while using agy by hand: put the active account on cooldown, then switch to the next account.
cmd_rotate() {
  need_jq; init_state
  local cur secs src
  cur="$(active_name)"
  [ -n "$cur" ] || die "no active account (see: agyr list)"
  if [ $# -ge 1 ]; then
    secs="$(parse_duration "$*")" || die "cannot parse duration '$*' (example: 4h13m)"
    src="as you entered"
  elif secs="$(detect_reset_secs)"; then
    src="read from the agy log"
  else
    secs=$DEFAULT_COOLDOWN
    src="no recent quota error in the log, using default 5h"
  fi
  local until=$(($(now) + secs))
  state_update '.cooldown[$n]=$u' --arg n "$cur" --argjson u "$until"
  echo "account '$cur' cooldown $(fmt_dur "$secs") ($src; reset $(fmt_time "$until"))"
  local nxt
  if ! nxt="$(cmd_next -v)"; then return 3; fi
  cmd_use "$nxt"
  echo "reopen agy (it must be a new process) with: agyr -c"
}

# Run `agy -p /quota` (no model call, 0 tokens) with HOME = $1 (a temp dir holding a copy of the token);
# print lines "<group>\t<metric>\t<percent>\t<reset time UTC>". Returns 1 on failure.
# AGY_HOME is also pointed there so the fake agy in tests reads the right token; real agy ignores it.
rows_by_week_reset() {
  local failed="$1" n gwr
  # every weekly reset time in ONE jq call (not one per account)
  local -A week_reset=()
  while IFS=$'\t' read -r n gwr; do
    week_reset["$n"]="$gwr"
  done < <(jq -r '(.quota // {}) | to_entries[] | .value.gwr as $g | select($g != null and $g != false) | [.key, $g] | @tsv' "$STATE")
  while read -r n; do
    gwr="${week_reset["$n"]:-}"
    if [[ "$failed" == *" $n "* ]] || [ -z "$gwr" ]; then gwr=99999999999; fi
    printf '%s %s\n' "$gwr" "$n"
  done < <(slots) | sort -k1,1n -k2,2 | cut -d' ' -f2
}

# Display order for 'agyr list': user-customized order from .ui_order in state.json,
# followed by any new/unpositioned slots in weekly-reset order.
rows_for_list() {
  local failed="$1"
  local -a ui_order=()
  mapfile -t ui_order < <(jq -r '(.ui_order // [])[]' "$STATE" 2>/dev/null)
  if [ "${#ui_order[@]}" -eq 0 ]; then
    rows_by_week_reset "$failed"
    return 0
  fi
  local -A seen=()
  local n
  for n in "${ui_order[@]}"; do
    if [ -f "$ACCTS/$n.token" ] && [ -z "${seen[$n]:-}" ]; then
      seen["$n"]=1
      echo "$n"
    fi
  done
  while read -r n; do
    [ -n "$n" ] || continue
    if [ -z "${seen[$n]:-}" ]; then
      echo "$n"
    fi
  done < <(rows_by_week_reset "$failed")
}

