table_dash() { local s; printf -v s "%*s" "$1" ""; echo -n "${s// /─}"; }

use_color() {
  case "${AGYR_COLOR:-auto}" in always) return 0 ;; never) return 1 ;; *) [ -t 1 ] && [ -z "${NO_COLOR:-}" ] ;; esac
}

init_table_colors() {
  G=""; Y=""; R=""; Z=""; BG_ALT=""; ALL_RST=""
  if use_color; then
    G=$'\033[32m'; Y=$'\033[33m'; R=$'\033[31m'; Z=$'\033[39m'
    ALL_RST=$'\033[0m'
    case "${COLORFGBG:-}" in
      *";15"|"0;"*) BG_ALT=$'\033[48;5;254m' ;;
      *) BG_ALT=$'\033[48;5;236m' ;;
    esac
  fi
  if [ "${1:-0}" -gt 0 ] && [ "${1:-0}" -lt 30 ]; then G=""; Y=""; R=""; Z=""; ALL_RST=""; fi
}

term_width_known() {
  if [ -n "${AGYR_RESPONSIVE:-}" ] || [ "${1:-}" = "1" ] || [ -t 1 ]; then
    local w="${AGYR_COLUMNS:-${COLUMNS:-}}"
    if [ -z "$w" ] || [ "$w" -le 0 ] 2>/dev/null; then w="$(tput cols 2>/dev/null || echo 0)"; fi
    if [ -z "$w" ] || [ "$w" -le 0 ] 2>/dev/null; then w="$(stty size 2>/dev/null | awk '{print $2}')"; fi
    if [ -z "$w" ] || [ "$w" -le 0 ] 2>/dev/null; then w="$(stty size < /dev/tty 2>/dev/null | awk '{print $2}')"; fi
    echo "${w:-0}"
  else
    echo 0
  fi
}

wrap_text() {
  local line="$1" tw="${2:-${tw:-0}}"
  if [ "$tw" -le 0 ] || [ "${#line}" -le "$tw" ]; then echo "$line"; return; fi
  if [ "$tw" -lt 30 ]; then echo "${line:0:$tw}"; return; fi
  fold -s -w "$tw" <<<"$line" | sed 's/[ \t]*$//'
}

build_frame() {
  local sep="" title w d s
  top="┌"; mid="├"; bot="└"; hdr="│"
  while [ $# -gt 0 ]; do
    title="$1"; w="$2"; shift 2
    d=$((w + 2)); printf -v s "%*s" "$d" ""; s="${s// /─}"
    if [ -n "$sep" ]; then top+="┬$s"; mid+="┼$s"; bot+="┴$s"; else top+="$s"; mid+="$s"; bot+="$s"; fi
    hdr+="$(printf ' %-*s │' "$w" "$title")"; sep=1
  done
  top+="┐"; mid+="┤"; bot+="┘"
}

print_hidden_note() {
  local cmd="$1" ch="$2" ah="$3" tw="$4"
  if [ "$ch" -eq 1 ] && [ "$ah" -eq 1 ]; then
    wrap_text "(Note: Argon and Claude columns hidden to fit terminal width ${tw}. Use 'agyr $cmd -w' to show all)" "$tw"
  elif [ "$ch" -eq 1 ]; then
    wrap_text "(Note: Claude columns hidden to fit terminal width ${tw}. Use 'agyr $cmd -w' to show all)" "$tw"
  elif [ "$ah" -eq 1 ]; then
    wrap_text "(Note: Argon columns hidden to fit terminal width ${tw}. Use 'agyr $cmd -w' to show all)" "$tw"
  fi
}

print_tier_note() {
  local cmd="$1" tier="$2" wide="$3" tw="$4" hint=""
  [ "$wide" = 0 ] && hint=". Use 'agyr $cmd -w' to show all"
  if [ "$tier" -eq 2 ]; then wrap_text "(Note: compact layout to fit terminal width ${tw}${hint})" "$tw"
  elif [ "$tier" -eq 3 ]; then wrap_text "(Note: one block per account to fit terminal width ${tw}${hint})" "$tw"; fi
}

print_footer() {
  local msg="$1" leg="$2" tw="${3:-0}"
  if [ "$tw" -le 0 ] || [ $((${#msg} + 3 + ${#leg})) -le "$tw" ]; then
    wrap_text "$msg   $leg" "$tw"
  else
    wrap_text "$msg" "$tw"; wrap_text "$leg" "$tw"
  fi
}

acct_status() {
  local n="$1" g5="$2" g5r="$3" gw="$4" gwr="$5" failed="$6" t="$7" until
  until="$(cooldown_until "$n")"
  if [[ "$failed" == *" $n "* ]]; then st="measure failed (token expired or agy error)"; sc="$R"
  elif [ -n "$g5" ] && [ "$gw" -eq 0 ] && [ "$gwr" -gt "$t" ]; then st="weekly limit reached, $(fmt_dur $((gwr - t))) left"; sc="$R"
  elif [ "$until" -gt "$t" ]; then st="cooldown, $(fmt_dur $((until - t))) left"; sc="$R"
  elif [ -z "$g5" ]; then st="not measured"; sc="$Y"
  elif { [ "$g5" != -1 ] && [ "$g5r" -le "$t" ]; } || [ "$gwr" -le "$t" ]; then st="stale, past reset time"; sc="$Y"
  elif { [ "$g5" != -1 ] && [ "$g5" -le 10 ]; } || [ "$gw" -le 10 ]; then st="low"; sc="$R"
  else st="ready"; sc="$G"; fi
}

# Print the table from state. $1 = names of accounts that failed to measure, $2 = 1 if measured just now.
print_table() {
  local failed=" $1 " live="$2" t cur n g5 g5r gw gwr at until st sc oldest=0
  t="$(now)"; cur="$(real_owner)"
  local acct_g=1 acct_nw=14 acct_w base_w an mk max_nl=0
  while read -r an; do
    [ -n "$an" ] || continue
    [ "${#an}" -gt "$max_nl" ] && max_nl=${#an}
    [ "${#an}" -gt "$acct_nw" ] && acct_nw=${#an}
    if is_locked "$an"; then
      if [ "$an" = "$cur" ]; then acct_g=3; elif [ "$acct_g" -lt 2 ]; then acct_g=2; fi
    fi
  done < <(slots)
  acct_w=$((acct_g + 1 + acct_nw))
  base_w=$((77 + acct_w - 16))

  pct() { # $1 = % left: <=10 red, <=40 yellow, otherwise green
    local c="$G"
    if [ "$1" -le 10 ]; then c="$R"; elif [ "$1" -le 40 ]; then c="$Y"; fi
    printf '%s%3s%%%s' "$c" "$1" "$Z"
  }
  cell() { # $1 = % left (-1 = limit disabled), $2 = reset time (epoch)
    if [ "$1" = -1 ]; then printf '%4s  %-19s' 'off' ''
    elif [ -z "$1" ] || [ "$2" -le "$t" ]; then printf '%4s  %-19s' '-' ''
    else printf '%s  %-19s' "$(pct "$1")" "$(fmt_time "$2")"; fi
  }
  cell_compact() { # $1 = % left (-1 = limit disabled), $2 = reset time (epoch)
    if [ "$1" = -1 ]; then printf '%4s  %-10s' 'off' ''
    elif [ -z "$1" ] || [ "$2" -le "$t" ]; then printf '%4s  %-10s' '-' ''
    else printf '%s %-11s' "$(pct "$1")" "$(fmt_short_time "$2")"; fi
  }

  local show_a5 show_aw show_c5=0 show_cw=0
  show_a5="$(jq -r '[.quota[]? | select(.a5 != null)] | length' "$STATE")"
  show_aw="$(jq -r '[.quota[]? | select(.aw != null)] | length' "$STATE")"
  if [ -n "${AGYR_CLAUDE:-}" ]; then
    show_c5="$(jq -r '[.quota[]? | select(.c5 != null)] | length' "$STATE")"
    show_cw="$(jq -r '[.quota[]? | select(.cw != null)] | length' "$STATE")"
  fi

  local is_tty=0; [ -t 1 ] && is_tty=1
  local is_wide=0; [ -n "${AGYR_WIDE:-}" ] && is_wide=1
  local tw; tw="$(term_width_known "$is_tty")"
  local G Y R Z BG_ALT ALL_RST
  init_table_colors "$tw"

  local claude_hidden=0 argon_hidden=0
  local status_dash=45 status_pad=43
  local layout_tier=1 # 1: full, 2: compact, 3: vertical

  if [ "$tw" -gt 0 ]; then
    while :; do
      local num_extra=0
      [ "$show_a5" -gt 0 ] && num_extra=$((num_extra + 1)) || :
      [ "$show_aw" -gt 0 ] && num_extra=$((num_extra + 1)) || :
      [ "$show_c5" -gt 0 ] && num_extra=$((num_extra + 1)) || :
      [ "$show_cw" -gt 0 ] && num_extra=$((num_extra + 1)) || :
      local extra_w=$((num_extra * 28))
      if [ "$tw" -ge $((base_w + extra_w + 45)) ]; then
        status_dash=45; layout_tier=1; break
      elif [ "$tw" -ge $((base_w + extra_w + 16)) ]; then
        status_dash=$((tw - base_w - extra_w)); layout_tier=1; break
      elif [ "$is_wide" = 1 ]; then
        layout_tier=2; break
      elif [ "$show_c5" -gt 0 ] || [ "$show_cw" -gt 0 ]; then
        claude_hidden=1; show_c5=0; show_cw=0
      elif [ "$show_a5" -gt 0 ] || [ "$show_aw" -gt 0 ]; then
        argon_hidden=1; show_a5=0; show_aw=0
      else
        layout_tier=2; break
      fi
    done

    if [ "$layout_tier" -eq 2 ]; then
      local comp_extra=0
      [ "$is_wide" = 1 ] && comp_extra="$num_extra"
      local avail_content=$((tw - (2 + comp_extra) * 19 - 5 - acct_g - 1))
      if [ "$avail_content" -ge 16 ]; then
        local full_acct_nw="$acct_nw"
        if [ $((full_acct_nw + 45)) -le "$avail_content" ]; then
          status_dash=45
        elif [ $((full_acct_nw + 8)) -le "$avail_content" ]; then
          status_dash=$((avail_content - full_acct_nw))
        else
          status_dash=8; acct_nw=$((avail_content - 8))
        fi
        acct_w=$((acct_g + 1 + acct_nw))
      else
        layout_tier=3
      fi
    fi
    status_pad=$((status_dash - 2))
  fi

  local any_locked=0
  if [ "$layout_tier" -le 2 ]; then
    local cell_fn="cell" col_quota_w=25
    if [ "$layout_tier" -eq 2 ]; then cell_fn="cell_compact"; col_quota_w=16; fi

    local cols=( "ACCOUNT" "$acct_w" "GEMINI 5H" "$col_quota_w" "GEMINI WEEK" "$col_quota_w" )
    [ "$show_a5" -gt 0 ] && cols+=( "ARGON 5H" "$col_quota_w" ) || :
    [ "$show_aw" -gt 0 ] && cols+=( "ARGON WEEK" "$col_quota_w" ) || :
    [ "$show_c5" -gt 0 ] && cols+=( "CLAUDE 5H" "$col_quota_w" ) || :
    [ "$show_cw" -gt 0 ] && cols+=( "CLAUDE WEEK" "$col_quota_w" ) || :
    cols+=( "STATUS" "$status_pad" )

    local top mid bot hdr
    build_frame "${cols[@]}"
    echo "$top"; echo "$hdr"; echo "$mid"

    local row_idx=0 snap ncell
    while read -r n; do
      local row_bg=""
      [ $((row_idx % 2)) -eq 1 ] && row_bg="$BG_ALT"
      row_idx=$((row_idx + 1))
      g5=""; g5r=0; gw=""; gwr=0; at=0
      snap="$(jq -r --arg n "$n" '.quota[$n] // empty | [.g5,.g5r,.gw,.gwr,.at] | @tsv' "$STATE")"
      if [ -n "$snap" ]; then IFS=$'\t' read -r g5 g5r gw gwr at <<<"$snap"; fi
      if [[ "$failed" == *" $n "* ]]; then g5=""; fi
      if [ -n "$g5" ] && { [ "$oldest" -eq 0 ] || [ "$at" -lt "$oldest" ]; }; then oldest=$at; fi
      acct_status "$n" "$g5" "$g5r" "$gw" "$gwr" "$failed" "$t"

      mk=""
      [ "$n" = "$cur" ] && mk="*"
      if is_locked "$n"; then mk+="!!"; any_locked=1; fi
      local an_disp="$n"
      [ "${#an_disp}" -gt "$acct_nw" ] && an_disp="${an_disp:0:$((acct_nw - 1))}…"
      printf -v ncell '%-*s %s' "$acct_g" "$mk" "$an_disp"

      local extra="" a5 a5r aw awr c5 c5r cw cwr
      IFS=$'\t' read -r c5 c5r cw cwr <<<"$(jq -r --arg n "$n" '.quota[$n] // empty | [(.c5 // "-"),(.c5r // 0),(.cw // "-"),(.cwr // 0)] | @tsv' "$STATE")"
      [ "${c5:-}" = "-" ] && c5=""; [ "${cw:-}" = "-" ] && cw=""
      IFS=$'\t' read -r a5 a5r aw awr <<<"$(jq -r --arg n "$n" '.quota[$n] // empty | [(.a5 // "-"),(.a5r // 0),(.aw // "-"),(.awr // 0)] | @tsv' "$STATE")"
      [ "${a5:-}" = "-" ] && a5=""; [ "${aw:-}" = "-" ] && aw=""
      [ "$show_a5" -gt 0 ] && extra+=" │ $($cell_fn "$a5" "${a5r:-0}")" || :
      [ "$show_aw" -gt 0 ] && extra+=" │ $($cell_fn "$aw" "${awr:-0}")" || :
      [ "$show_c5" -gt 0 ] && extra+=" │ $($cell_fn "$c5" "${c5r:-0}")" || :
      [ "$show_cw" -gt 0 ] && extra+=" │ $($cell_fn "$cw" "${cwr:-0}")" || :

      local st_disp="$st"
      [ "${#st}" -gt "$status_pad" ] && st_disp="${st:0:$((status_pad - 1))}…"
      printf '%s│ %-*s │ %s │ %s%s │ %s%-*s%s │%s\n' "$row_bg" "$acct_w" "$ncell" "$($cell_fn "$g5" "$g5r")" "$($cell_fn "$gw" "$gwr")" "$extra" "$sc" "$status_pad" "$st_disp" "$Z" "$ALL_RST"
    done < <(rows_for_list "$failed")
    echo "$bot"
  else # layout_tier == 3: vertical blocks
    local col_w=11 block_idx=0 snap
    if [ "$tw" -ge 45 ] && [ "$max_nl" -gt 11 ]; then col_w="$max_nl"; fi
    print_vert_quota() { # $1 = label, $2 = val, $3 = reset epoch
      local qlbl="$1" qval="$2" qepoch="${3:-0}" qpfx
      if [ "$tw" -gt 0 ] && [ "$tw" -lt 35 ]; then printf -v qpfx '%*s %s ' "$acct_g" "" "$qlbl"
      else printf -v qpfx '%*s %-*s  ' "$acct_g" "" "$col_w" "$qlbl"; fi
      local qpfx_len=${#qpfx}
      if [ "$tw" -gt 0 ] && [ "$qpfx_len" -ge "$tw" ]; then
        if [ "$tw" -lt 30 ]; then printf '%s\n' "${qpfx:0:$tw}"; else printf '%s\n' "${qpfx:0:$((tw - 1))}…"; fi
        return
      fi

      local cell_out=""
      if [ "$qval" = -1 ]; then cell_out=" off"
      elif [ -z "$qval" ] || [ "$qepoch" -le "$t" ]; then cell_out="   -"
      elif [ "$tw" -le 0 ] || [ $((qpfx_len + 25)) -le "$tw" ]; then cell_out="$(printf '%s  %s' "$(pct "$qval")" "$(fmt_time "$qepoch")")"
      else
        local s_time; s_time="$(fmt_short_time "$qepoch")"
        if [ $((qpfx_len + 16)) -le "$tw" ]; then cell_out="$(printf '%s %s' "$(pct "$qval")" "$s_time")"
        else
          local avail_time=$((tw - qpfx_len - 5))
          if [ "$avail_time" -gt 1 ]; then cell_out="$(printf '%s %s' "$(pct "$qval")" "${s_time:0:$((avail_time - 1))}…")"
          else cell_out="$(pct "$qval")"; fi
        fi
      fi
      local full_line="${qpfx}${cell_out}"
      if [ "$tw" -gt 0 ] && [ "$tw" -lt 30 ] && [ "${#full_line}" -gt "$tw" ]; then printf '%s\n' "${full_line:0:$tw}"
      else printf '%s\n' "$full_line"; fi
    }

    while read -r n; do
      [ "$block_idx" -gt 0 ] && echo ""
      block_idx=$((block_idx + 1))
      g5=""; g5r=0; gw=""; gwr=0; at=0
      snap="$(jq -r --arg n "$n" '.quota[$n] // empty | [.g5,.g5r,.gw,.gwr,.at] | @tsv' "$STATE")"
      if [ -n "$snap" ]; then IFS=$'\t' read -r g5 g5r gw gwr at <<<"$snap"; fi
      if [[ "$failed" == *" $n "* ]]; then g5=""; fi
      if [ -n "$g5" ] && { [ "$oldest" -eq 0 ] || [ "$at" -lt "$oldest" ]; }; then oldest=$at; fi
      acct_status "$n" "$g5" "$g5r" "$gw" "$gwr" "$failed" "$t"

      mk=""
      [ "$n" = "$cur" ] && mk="*"
      if is_locked "$n"; then mk+="!!"; any_locked=1; fi

      local pfx_str st_disp="$st"
      if [ "$tw" -gt 0 ] && [ "$tw" -lt 35 ]; then printf -v pfx_str '%-*s %s ' "$acct_g" "$mk" "$n"
      else printf -v pfx_str '%-*s %-*s  ' "$acct_g" "$mk" "$col_w" "$n"; fi
      if [ "$tw" -gt 0 ] && [ "${#pfx_str}" -ge "$tw" ]; then
        if [ "$tw" -lt 30 ]; then pfx_str="${pfx_str:0:$tw}"; else pfx_str="${pfx_str:0:$((tw - 1))}…"; fi
        st_disp=""
      elif [ "$tw" -gt 0 ]; then
        local avail_st=$((tw - ${#pfx_str}))
        if [ "${#st_disp}" -gt "$avail_st" ]; then
          if [ "$tw" -lt 30 ]; then st_disp="${st_disp:0:$avail_st}"
          elif [ "$avail_st" -gt 1 ]; then st_disp="${st_disp:0:$((avail_st - 1))}…"
          else st_disp=""; fi
        fi
      fi
      if [ -n "$st_disp" ]; then printf '%s%s%s%s\n' "$pfx_str" "$sc" "$st_disp" "$ALL_RST"
      else printf '%s\n' "$pfx_str"; fi

      print_vert_quota "GEMINI 5H" "$g5" "$g5r"
      print_vert_quota "GEMINI WEEK" "$gw" "$gwr"

      local a5 a5r aw awr c5 c5r cw cwr
      IFS=$'\t' read -r c5 c5r cw cwr <<<"$(jq -r --arg n "$n" '.quota[$n] // empty | [(.c5 // "-"),(.c5r // 0),(.cw // "-"),(.cwr // 0)] | @tsv' "$STATE")"
      [ "${c5:-}" = "-" ] && c5=""; [ "${cw:-}" = "-" ] && cw=""
      IFS=$'\t' read -r a5 a5r aw awr <<<"$(jq -r --arg n "$n" '.quota[$n] // empty | [(.a5 // "-"),(.a5r // 0),(.aw // "-"),(.awr // 0)] | @tsv' "$STATE")"
      [ "${a5:-}" = "-" ] && a5=""; [ "${aw:-}" = "-" ] && aw=""

      if [ "$argon_hidden" -eq 0 ]; then
        [ -n "$a5" ] && print_vert_quota "ARGON 5H" "$a5" "${a5r:-0}"
        [ -n "$aw" ] && print_vert_quota "ARGON WEEK" "$aw" "${awr:-0}"
      fi
      if [ -n "${AGYR_CLAUDE:-}" ] && [ "$claude_hidden" -eq 0 ]; then
        [ -n "$c5" ] && print_vert_quota "CLAUDE 5H" "$c5" "${c5r:-0}"
        [ -n "$cw" ] && print_vert_quota "CLAUDE WEEK" "$cw" "${cwr:-0}"
      fi
    done < <(rows_for_list "$failed")
  fi

  [ "$is_wide" = 0 ] && print_hidden_note "list" "$claude_hidden" "$argon_hidden" "$tw"
  print_tier_note "list" "$layout_tier" "$is_wide" "$tw"

  if [ -n "$LIVE" ] && [ -z "$cur" ]; then
    wrap_text "${Y}! The login in use matches no slot (just logged in to another account?). Run 'agyr save <name>' to store it; 'agyr use' will not overwrite any slot.${ALL_RST:-$Z}" "$tw"
  fi
  local legend="* = selected account"
  if [ "$any_locked" = 1 ]; then legend+=", !! = locked account, do not use this"; fi
  local msg
  if [ "$live" = 1 ]; then msg="Measured at $(fmt_time "$t")"
  elif [ "$oldest" -gt 0 ]; then msg="Oldest data measured at $(fmt_time "$oldest"). Run 'agyr list' (without -c) to refresh."
  else msg="No quota data yet; run 'agyr list' (without -c) to measure."; fi
  print_footer "$msg" "($legend)" "$tw"
}

# list [-c|--cached]: measure every account's real quota (agy -p /quota, 0 tokens, in parallel) and print a table; * = selected account.
# -c only prints the saved data and does not call agy.
fmt_compact_reset() {
  local epoch="$1" b_epoch="${2:-}" pad="${3:-12}"
  if [ -z "$epoch" ] || [ "$epoch" = 0 ]; then
    echo "-"
    return
  fi
  local short_time; short_time="$(fmt_short_time "$epoch")"
  if [ -n "$b_epoch" ] && [ "$b_epoch" != 0 ]; then
    local diff=$((epoch - b_epoch))
    [ "$diff" -lt 0 ] && diff=$((-diff))
    if [ "$diff" -gt 120 ]; then
      local was_time; was_time="$(date -d "@$b_epoch" '+%H:%M' 2>/dev/null || echo "")"
      if [ -n "$was_time" ]; then
        local with_was="$short_time (was $was_time)"
        if [ "${#with_was}" -le "$pad" ]; then
          echo "$with_was"
          return
        fi
        local with_star="$short_time*"
        if [ "${#with_star}" -le "$pad" ]; then
          echo "$with_star"
          return
        fi
      fi
    fi
  fi
  if [ "${#short_time}" -gt "$pad" ]; then
    echo "${short_time:0:$((pad - 1))}…"
  else
    echo "$short_time"
  fi
}

fmt_full_reset() {
  local epoch="${1:-}" b_epoch="${2:-}" pad="${3:-35}"
  local rst="-"
  if [ -n "$epoch" ] && [ "$epoch" != 0 ]; then
    rst="$(fmt_time "$epoch")"
  fi
  if [ -n "$b_epoch" ] && [ "$b_epoch" != 0 ] && [ -n "$epoch" ] && [ "$epoch" != 0 ]; then
    local diff=$((epoch - b_epoch))
    if [ "$diff" -lt 0 ]; then diff=$((-diff)); fi
    if [ "$diff" -gt 120 ]; then
      rst="$rst (was $(date -d "@$b_epoch" '+%I:%M %p'))"
    fi
  fi
  if [ "${#rst}" -gt "$pad" ]; then
    echo "${rst:0:$((pad - 1))}…"
  else
    echo "$rst"
  fi
}

