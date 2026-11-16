quota_fetch() {
  local home="$1" agyhome="$2" tmp out
  tmp="$(mktemp -d)"
  # PLATFORM_DETACH_WAIT (setsid -w, empty stdin): agy runs without a controlling terminal. Otherwise several agy processes
  # running in parallel all change/restore your terminal mode (raw mode, terminal capability queries) and leave the
  # terminal garbled (staircase newlines, no echo). The keyring bypass and the /quota argument exclusion come from the
  # platform layer (platforms/linux/platform.sh, platforms/windows/platform.sh).
  out="$(env HOME="$home" AGY_HOME="$agyhome" "${PLATFORM_ENV_KEYRING[@]}" "${PLATFORM_ENV_NOCONV_QUOTA[@]}" \
    "${PLATFORM_DETACH_WAIT[@]}" "$AGY_BIN" -p /quota --add-dir "$tmp" \
    --model gemini-3.8-flash-high --output-format stream-json </dev/null 2>/dev/null |
    grep '^{' | jq -r 'select(.event=="result") | select(.result.status=="SUCCESS") | .result.response' 2>/dev/null)" || true
  rm -rf "$tmp"
  [ -n "$out" ] || return 1
  printf '%s\n' "$out"
}

# Measure one slot's quota in a temp HOME: does NOT touch the real token file, so it cannot break a running agy/agy-run
# and can run in parallel. $1 = slot name, $2 = file for the raw result, $3 = name of the active account.
measure_one() {
  local name="$1" out="$2" act="$3" home d src rc=0
  home="$(mktemp -d)"
  trap 'rm -rf "$home"' EXIT INT TERM
  d="$home/.gemini/antigravity-cli"
  mkdir -p "$d"
  # the account in use is measured from the private copy taken once in measure_all_parallel, never from the live file
  if [ "$name" = "$act" ] && [ -n "$LIVE_SNAP" ]; then src="$LIVE_SNAP"; else src="$ACCTS/$name.token"; fi
  cp "$src" "$d/antigravity-oauth-token"; chmod 600 "$d/antigravity-oauth-token"
  # keep the same installation_id so Google sees the same agy installation
  if [ -f "$AGY_HOME/installation_id" ]; then cp "$AGY_HOME/installation_id" "$d/installation_id"; fi
  "$PROBE_FN" "$home" "$d" "$name" >"$out" 2>/dev/null || rc=$?
  # agy may have refreshed the token itself: write it back to the slot (for the active account the real token file is the source of truth),
  # but only if it is still the same account: whatever else is in that file must never replace a slot
  if [ "$name" != "$act" ] && [ -s "$d/antigravity-oauth-token" ] && ! cmp -s "$d/antigravity-oauth-token" "$ACCTS/$name.token" \
    && [ "$(ident_of "$d/antigravity-oauth-token")" = "$(ident_of "$ACCTS/$name.token")" ]; then
    atomic_cp "$d/antigravity-oauth-token" "$ACCTS/$name.token"
  fi
  return "$rc"
}

# Parse the raw /quota output ($2) and store a Gemini snapshot in state. What was just measured is the truth, so:
# at 0% set a cooldown until the reset time; with quota left, clear any cooldown (e.g. the default 5h one set before the reset time was known).
# Fails if the Gemini numbers are missing.
quota_ingest() {
  local name="$1" raw="$2" grp metric pct reset epoch g5="" g5r=0 gw="" gwr=0 g5off=0
  local c5=null c5r=null cw=null cwr=null # Claude / GPT limits: kept only for accounts that also report Gemini 4 Argon
  local a5=null a5r=null aw=null awr=null # Gemini 4 Argon (only some accounts have it): null = no such limit reported
  while IFS=$'\t' read -r grp metric pct reset; do
    case "$grp|$metric" in
      "Claude and GPT models|"*)
        [ -n "$reset" ] || continue
        epoch="$(date -d "$reset" +%s 2>/dev/null)" || continue
        case "$metric" in
          *"Five Hour"*) c5="${pct%\%}"; c5r="$epoch" ;;
          *Weekly*) cw="${pct%\%}"; cwr="$epoch" ;;
        esac ;;
      "Gemini 4 Argon|"*)
        # reported as its own group, e.g. "Gemini 4 Argon<TAB>Gemini 4 Argon Weekly Limit<TAB>25%<TAB>2026-11-13T02:27:40Z"
        [ -n "$reset" ] || continue
        epoch="$(date -d "$reset" +%s 2>/dev/null)" || continue
        case "$metric" in
          *"Five Hour"*) a5="${pct%\%}"; a5r="$epoch" ;;
          *Weekly*) aw="${pct%\%}"; awr="$epoch" ;;
        esac ;;
      "Gemini Models|Five Hour"*)
        if [ -n "$reset" ]; then
          epoch="$(date -d "$reset" +%s 2>/dev/null)" || continue
          g5="${pct%\%}"; g5r="$epoch"
        elif [[ "$pct" =~ ^[A-Za-z]+$ ]]; then
          g5off=1 # "disabled", no reset time: the weekly limit is used up, so the 5-hour limit does not apply
        fi ;;
      "Gemini Models|Weekly"*)
        [ -n "$reset" ] || continue
        epoch="$(date -d "$reset" +%s 2>/dev/null)" || continue
        gw="${pct%\%}"; gwr="$epoch" ;;
    esac
  done <<<"$raw"
  # g5 = -1 stands for "5-hour limit disabled" (state keeps numbers only, so -1 is the marker)
  if [ "$g5off" = 1 ] && [ -z "$g5" ]; then g5=-1; g5r=0; fi
  [[ "$g5" =~ ^-?[0-9]+$ && "$gw" =~ ^[0-9]+$ ]] || return 1
  [[ "$a5" == null || "$a5" =~ ^[0-9]+$ ]] || { a5=null; a5r=null; }
  [[ "$aw" == null || "$aw" =~ ^[0-9]+$ ]] || { aw=null; awr=null; }
  # only accounts that have Gemini 4 Argon get the Claude columns
  if [ "$a5" == null ] && [ "$aw" == null ]; then c5=null; c5r=null; cw=null; cwr=null; fi
  [[ "$c5" == null || "$c5" =~ ^[0-9]+$ ]] || { c5=null; c5r=null; }
  [[ "$cw" == null || "$cw" =~ ^[0-9]+$ ]] || { cw=null; cwr=null; }
  state_update '.quota[$n]={at:$t,g5:$a,g5r:$ar,gw:$b,gwr:$br,a5:$x5,a5r:$x5r,aw:$xw,awr:$xwr,c5:$y5,c5r:$y5r,cw:$yw,cwr:$ywr}' --arg n "$name" --argjson t "$(now)" \
    --argjson a "$g5" --argjson ar "$g5r" --argjson b "$gw" --argjson br "$gwr" \
    --argjson x5 "$a5" --argjson x5r "$a5r" --argjson xw "$aw" --argjson xwr "$awr" \
    --argjson y5 "$c5" --argjson y5r "$c5r" --argjson yw "$cw" --argjson ywr "$cwr"
  local until=0
  if [ "$g5" -eq 0 ]; then until=$g5r; fi
  if [ "$gw" -eq 0 ] && [ "$gwr" -gt "$until" ]; then until=$gwr; fi
  if [ "$until" -gt "$(now)" ]; then
    state_update '.cooldown[$n]=$u' --arg n "$name" --argjson u "$until"
  else
    state_update 'del(.cooldown[$n])' --arg n "$name"
  fi
  return 0
}

# Measure all slots ($@) and store snapshots; MEASURE_FAILED = names of the accounts that failed (space-separated).
# Runs in the main shell (never in $(...)): the wincred variant must keep its restore/lock state and traps.
measure_all() {
  if [ "$BACKEND" = wincred ]; then measure_all_swap "$@"; else measure_all_parallel "$@"; fi
}

# file backend: every account is measured in parallel, in its own throwaway HOME
measure_all_parallel() {
  local -a names=("$@") pids=() failed=()
  local d act i n
  d="$(mktemp -d)"
  # one consistent look at the login in use: which account it is, and a private copy to measure it with, so that a switch made
  # meanwhile by another agyr / agy-run cannot change what is measured under this account's name
  lock_acquire; live_load
  LIVE_SNAP="$(live_snapshot)"; act=""
  if [ -n "$LIVE_SNAP" ]; then act="$(owner_of "$LIVE_SNAP")"; fi
  lock_release
  for n in "${names[@]}"; do
    measure_one "$n" "$d/$n.out" "$act" &
    pids+=($!)
  done
  for i in "${!names[@]}"; do
    n="${names[$i]}"
    if wait "${pids[$i]}" && "$INGEST_FN" "$n" "$(cat "$d/$n.out")"; then :; else failed+=("$n"); fi
  done
  rm -rf "$d"
  if [ -n "$LIVE_SNAP" ]; then rm -f "$LIVE_SNAP"; LIVE_SNAP=""; fi
  MEASURE_FAILED="${failed[*]:-}"
}

# wincred backend: the login is ONE shared entry, so the accounts are measured one after another: install a slot's login,
# run agy -p /quota, take back whatever agy refreshed, go on to the next. At the end the login that was in use is put
# back (also when interrupted: RESTORE_* + on_exit). A running agy keeps its own copy of the old login, but do not log in
# or refresh agy by hand while this runs.
measure_all_swap() {
  local -a names=("$@") failed=()
  local d act n
  d="$(mktemp -d)"
  lock_acquire
  live_load
  act="$(real_owner)"
  if [ -n "$LIVE" ]; then
    cp "$LIVE" "$d/orig"
    atomic_cp "$LIVE" "$ACCTS/.last-token.bak"
    # the freshest copy of the login in use goes back into its slot first (as 'use' does)
    if [ -n "$act" ]; then atomic_cp "$LIVE" "$ACCTS/$act.token"; fi
    RESTORE_KIND=file; RESTORE_FILE="$d/orig"
  else
    RESTORE_KIND=none
  fi
  for n in "${names[@]}"; do
    live_put "$ACCTS/$n.token"
    if "$PROBE_FN" "$HOME" "$AGY_HOME" "$n" >"$d/$n.out" 2>/dev/null && "$INGEST_FN" "$n" "$(cat "$d/$n.out")"; then :; else failed+=("$n"); fi
    # agy may have refreshed the login itself: take it back into the slot, but only if it is still the same account
    live_load
    if [ -n "$LIVE" ] && [ "$(ident_of "$LIVE")" = "$(ident_of "$ACCTS/$n.token")" ] && ! cmp -s "$LIVE" "$ACCTS/$n.token"; then
      atomic_cp "$LIVE" "$ACCTS/$n.token"
    fi
  done
  # put the login that was in use back: its slot (freshest), else the unsaved original, else no login at all
  if [ -n "$act" ]; then live_put "$ACCTS/$act.token"
  elif [ -f "$d/orig" ]; then live_put "$d/orig"
  else live_clear
  fi
  RESTORE_KIND=""; RESTORE_FILE=""
  lock_release
  rm -rf "$d"
  MEASURE_FAILED="${failed[*]:-}"
}

# Slot names ordered by when the weekly limit resets (from the last measurement), soonest first. Accounts without usable data
# (never measured, or just failed to measure) come last; ties are broken by name. $1 = " names that failed " (padded with spaces).
