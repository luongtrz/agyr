hi_call() {
  local home="$1" agyhome="$2" model="${3:-gemini-3.8-flash-low}" tmp res
  tmp="$(mktemp -d)"
  local -a cap=()
  # timeout runs INSIDE setsid (PLATFORM_DETACH_WAIT): it then leads its own process group and kills agy and whatever agy started
  if command -v timeout >/dev/null; then cap=(timeout "${AGYR_TEST_TIMEOUT:-120}"); fi
  res="$(cd "$tmp" && env HOME="$home" AGY_HOME="$agyhome" "${PLATFORM_ENV_KEYRING[@]}" \
    "${PLATFORM_DETACH_WAIT[@]}" "${cap[@]}" "$AGY_BIN" -p Hi --add-dir "$tmp" --model "$model" --print-timeout 90s \
    --output-format stream-json </dev/null 2>/dev/null |
    grep '^{' | jq -r 'select(.event=="result") | .result
      | "\(.status)\u001f\((.response // "") | gsub("[\\t\\r\\n]+"; " ") | .[0:200])\u001f\((.error // "") | gsub("[\\t\\r\\n]+"; " ") | .[0:200])"' 2>/dev/null |
    tail -n 1)" || true
  rm -rf "$tmp"
  [ -n "$res" ] || return 1
  printf '%s\n' "$res"
}

# Every "Hi" goes to the LOWEST-effort variant of its model (gemini-3.8-flash-low, gemini-4-argon-low, claude-sonnet-5-5-low): the only
# point is to make the request, so the cheapest one keeps the quota and token cost down.
# the probe measure_all runs for 'agyr test': quota before, "Hi", quota after (prints the raw quota output of the last one)
test_probe() {
  local home="$1" agyhome="$2" name="$3" t0 res
  quota_fetch "$home" "$agyhome" >"$TEST_DIR/$name.before" 2>/dev/null || : >"$TEST_DIR/$name.before"
  t0="$(date +%s)"
  res="$(hi_call "$home" "$agyhome" gemini-3.8-flash-low)" || res="NO_RESULT"$'\x1f'$'\x1f'
  printf '%s\x1f%s\n' "$res" "$(($(date +%s) - t0))" >"$TEST_DIR/$name.hi"
  if grep -q '^Gemini 4 Argon	' "$TEST_DIR/$name.before" 2>/dev/null; then
    t0="$(date +%s)"
    res="$(hi_call "$home" "$agyhome" gemini-4-argon-low)" || res="NO_RESULT"$'\x1f'$'\x1f'
    printf '%s\x1f%s\n' "$res" "$(($(date +%s) - t0))" >"$TEST_DIR/$name.hi.argon"
    t0="$(date +%s)"
    res="$(hi_call "$home" "$agyhome" claude-sonnet-5-5-low)" || res="NO_RESULT"$'\x1f'$'\x1f'
    printf '%s\x1f%s\n' "$res" "$(($(date +%s) - t0))" >"$TEST_DIR/$name.hi.claude"
  fi
  quota_fetch "$home" "$agyhome"
}

# the ingest for 'agyr test': store the quota; the account counts as failed unless it answered "Hi" and its quota was readable
test_ingest() {
  local name="$1" raw="$2" st
  quota_ingest "$name" "$raw" || return 1
  st="$(cut -d$'\x1f' -f1 "$TEST_DIR/$name.hi" 2>/dev/null)"
  [ "$st" = SUCCESS ] || return 1
  if [ -f "$TEST_DIR/$name.hi.argon" ]; then
    st="$(cut -d$'\x1f' -f1 "$TEST_DIR/$name.hi.argon" 2>/dev/null)"
    [ "$st" = SUCCESS ] || return 1
  fi
  if [ -f "$TEST_DIR/$name.hi.claude" ]; then
    st="$(cut -d$'\x1f' -f1 "$TEST_DIR/$name.hi.claude" 2>/dev/null)"
    [ "$st" = SUCCESS ] || return 1
  fi
  return 0
}

read_hi_result() {
  local n="$1" st="" resp="" err="" secs="" ast="" aresp="" aerr="" asecs="" cst="" cresp="" cerr="" csecs=""
  IFS=$'\x1f' read -r st resp err secs <"$TEST_DIR/$n.hi" || true
  has_acct_argon=0
  if [ -f "$TEST_DIR/$n.hi.argon" ]; then
    has_acct_argon=1
    IFS=$'\x1f' read -r ast aresp aerr asecs <"$TEST_DIR/$n.hi.argon" || true
  fi
  if [ -f "$TEST_DIR/$n.hi.claude" ]; then
    IFS=$'\x1f' read -r cst cresp cerr csecs <"$TEST_DIR/$n.hi.claude" || true
  fi

  if [ "$has_acct_argon" -eq 0 ]; then
    if [ "$st" = SUCCESS ]; then
      txt="ok in ${secs}s"
      if [ -n "$resp" ]; then txt="$txt: \"${resp:0:24}\""; fi
      hcol="$G"
    elif [ "$st" = NO_RESULT ] || [ -z "$st" ]; then
      txt="failed: agy gave no answer (${secs:-?}s)"
      hcol="$R"
    else
      txt="failed: ${err:-$st}"
      hcol="$R"
    fi
  else
    if [ "$st" = NO_RESULT ] || [ -z "$st" ]; then
      txt="failed (gemini): agy gave no answer (${secs:-?}s)"
      hcol="$R"
    elif [ "$st" != SUCCESS ]; then
      txt="failed (gemini): ${err:-$st}"
      hcol="$R"
    elif [ "$ast" = NO_RESULT ] || [ -z "$ast" ]; then
      txt="failed (argon): agy gave no answer (${asecs:-?}s)"
      hcol="$R"
    elif [ "$ast" != SUCCESS ]; then
      txt="failed (argon): ${aerr:-$ast}"
      hcol="$R"
    elif [ "$cst" = NO_RESULT ] || [ -z "$cst" ]; then
      txt="failed (claude): agy gave no answer (${csecs:-?}s)"
      hcol="$R"
    elif [ "$cst" != SUCCESS ]; then
      txt="failed (claude): ${cerr:-$cst}"
      hcol="$R"
    else
      txt="ok in ${secs}s"
      if [ -n "$resp" ]; then txt="$txt: \"${resp:0:24}\""; fi
      hcol="$G"
    fi
  fi
  if [ "${#txt}" -gt 46 ]; then
    txt="${txt:0:43}..."
  fi
}

test_col_cell() {
  local n="$1" m="$2" qtype="$3" qval="${4:-}" r="${5:-}" pad="${6:-35}" tier="${7:-1}"
  local before="" b_iso=""
  { read -r before || true; read -r b_iso || true; } < <(awk -F'\t' -v m="$m" -v q="$qtype" '$1==m && $2 ~ q {print $3; print $4; exit}' "$TEST_DIR/$n.before" 2>/dev/null)
  local after="${qval:+$qval%}"
  if [ "$qval" = -1 ]; then after="off"; fi
  if [ "$before" = disabled ]; then before="off"; fi
  local b_epoch=""
  if [ -n "$b_iso" ]; then
    b_epoch="$(date -d "$b_iso" +%s 2>/dev/null)" || b_epoch=""
  fi

  local rst
  if [ "$tier" -eq 1 ]; then
    rst="$(fmt_full_reset "$r" "$b_epoch" "$pad")"
  elif [ "$tier" -eq 2 ]; then
    rst="$(fmt_compact_reset "$r" "$b_epoch" "$pad")"
  else
    rst=""
  fi
  out_val="${before:-?}>${after:-?}"
  out_rst="$rst"
  out_b_epoch="$b_epoch"
}

# table for 'agyr test'; every account of this run has its files in $TEST_DIR
print_test_table() {
  local n snap g5 g5r a5 a5r aw awr c5 c5r any_locked=0
  local has_argon=0 has_argon_5h=0
  for n in "${!TEST_TRY[@]}"; do
    if [ -f "$TEST_DIR/$n.hi.argon" ] || grep -q '^Gemini 4 Argon	' "$TEST_DIR/$n.before" 2>/dev/null; then
      has_argon=1
      if [ "$(jq -r --arg n "$n" '.quota[$n] | select(.a5 != null) | 1' "$STATE" 2>/dev/null)" = 1 ]; then
        has_argon_5h=1
      fi
    fi
  done

  local acct_g=1 acct_nw=14 acct_w an
  while read -r an; do
    [ -n "$an" ] || continue
    if [ "${#an}" -gt "$acct_nw" ]; then acct_nw=${#an}; fi
    if is_locked "$an"; then acct_g=2; fi
  done < <(slots)
  acct_w=$((acct_g + 1 + acct_nw))
  local aw_extra=$((acct_w - 16))

  local is_tty=0; [ -t 1 ] && is_tty=1
  local is_wide=0; [ -n "${AGYR_WIDE:-}" ] && is_wide=1
  local tw; tw="$(term_width_known "$is_tty")"
  local G Y R Z BG_ALT ALL_RST
  init_table_colors "$tw"

  local show_test_claude=1 show_test_argon=1
  local claude_hidden=0 argon_hidden=0
  local hi_dash=48 hi_pad=46
  local rst_dash=37 rst_pad=35
  local c_rst_dash=37 c_rst_pad=35
  local layout_tier=1 # 1: full, 2: compact, 3: vertical

  shrink_test_tier1() {
    local extra_w="${1:-0}"
    local avail=$((tw - acct_w - 21 - extra_w))
    if [ "$avail" -lt 36 ]; then avail=36; fi
    hi_dash=$((avail * 55 / 100))
    rst_dash=$((avail - hi_dash))
    if [ "$hi_dash" -lt 18 ]; then hi_dash=18; fi
    if [ "$rst_dash" -lt 18 ]; then rst_dash=18; fi
    hi_pad=$((hi_dash - 2))
    rst_pad=$((rst_dash - 2))
  }

  if [ "$tw" -gt 0 ]; then
    if [ "$is_wide" = 1 ]; then
      local extra_w=0
      if [ "$has_argon" -eq 1 ]; then extra_w=106; fi
      if [ "$tw" -ge $((122 + aw_extra + extra_w)) ]; then
        layout_tier=1
      elif [ "$tw" -ge $((88 + aw_extra + extra_w)) ]; then
        shrink_test_tier1 "$extra_w"
      else
        layout_tier=2
      fi
    else
      if [ "$has_argon" -eq 1 ] && [ "$tw" -ge $((228 + aw_extra)) ]; then
        :
      elif [ "$has_argon" -eq 1 ] && [ "$tw" -ge $((175 + aw_extra)) ]; then
        show_test_claude=0; claude_hidden=1
      elif [ "$tw" -ge $((122 + aw_extra)) ]; then
        if [ "$has_argon" -eq 1 ]; then
          show_test_claude=0; claude_hidden=1
          show_test_argon=0; argon_hidden=1
        fi
      elif [ "$tw" -ge $((88 + aw_extra)) ]; then
        if [ "$has_argon" -eq 1 ]; then
          show_test_claude=0; claude_hidden=1
          show_test_argon=0; argon_hidden=1
        fi
        shrink_test_tier1 0
      else
        if [ "$has_argon" -eq 1 ]; then
          show_test_claude=0; claude_hidden=1
          show_test_argon=0; argon_hidden=1
        fi
        layout_tier=2
      fi
    fi

    # Check Tier 2 (compact tier)
    if [ "$layout_tier" -eq 2 ]; then
      if [ "$is_wide" = 1 ]; then
        show_test_claude=1; show_test_argon=1
        claude_hidden=0; argon_hidden=0
      fi
      local full_acct_nw="$acct_nw"
      local fixed_w
      if [ "$has_argon" -eq 1 ] && [ "$show_test_argon" -eq 1 ] && [ "$show_test_claude" -eq 1 ]; then
        fixed_w=$((99 + acct_g))
        rst_dash=14; rst_pad=12
        c_rst_dash=15; c_rst_pad=13
      elif [ "$has_argon" -eq 1 ] && [ "$show_test_argon" -eq 1 ]; then
        fixed_w=$((68 + acct_g))
        rst_dash=14; rst_pad=12
        c_rst_dash=14; c_rst_pad=12
      else
        fixed_w=$((38 + acct_g))
        rst_dash=14; rst_pad=12
        c_rst_dash=14; c_rst_pad=12
      fi

      local avail=$((tw - fixed_w))
      if [ "$avail" -ge 20 ]; then
        local rem="$avail"
        if [ "$full_acct_nw" -le $((rem - 12)) ]; then
          acct_nw="$full_acct_nw"
        else
          acct_nw=$((rem - 12))
          if [ "$acct_nw" -lt 8 ]; then acct_nw=8; fi
        fi
        rem=$((rem - acct_nw))
        if [ "$rem" -gt 46 ]; then
          hi_pad=46
          local extra=$((rem - 46))
          if [ "$extra" -gt 11 ]; then
            rst_dash=$((14 + 11))
          else
            rst_dash=$((14 + extra))
          fi
          rst_pad=$((rst_dash - 2))
        else
          hi_pad="$rem"
        fi
        hi_dash=$((hi_pad + 2))
        acct_w=$((acct_g + 1 + acct_nw))
      else
        layout_tier=3
      fi
    fi
  fi

  local argon_hdr="ARGON WEEK"
  if [ "$has_argon_5h" -eq 1 ]; then argon_hdr="ARGON 5H"; fi

  local any_locked=0
  if [ "$layout_tier" -le 2 ]; then
    local a_rst_pad="$rst_pad"
    if [ "$layout_tier" -eq 1 ]; then
      a_rst_pad=35
      c_rst_pad=35
    fi

    local cols=( "ACCOUNT" "$acct_w" "HI" "$hi_pad" "GEMINI 5H" 12 "RESETS" "$rst_pad" )
    if [ "$has_argon" -eq 1 ]; then
      if [ "$show_test_argon" -eq 1 ]; then
        cols+=( "$argon_hdr" 12 "ARGON RESETS" "$a_rst_pad" )
      fi
      if [ "$show_test_claude" -eq 1 ]; then
        cols+=( "CLAUDE 5H" 12 "CLAUDE RESETS" "$c_rst_pad" )
      fi
    fi

    local top mid bot hdr
    build_frame "${cols[@]}"
    echo "$top"
    echo "$hdr"
    echo "$mid"

    local row_idx=0
    while read -r n; do
      local row_bg=""
      if [ $((row_idx % 2)) -eq 1 ]; then row_bg="$BG_ALT"; fi
      row_idx=$((row_idx + 1))

      local mk=""
      if is_locked "$n"; then mk="!!"; fi
      local an_disp="$n"
      if [ "${#an_disp}" -gt "$acct_nw" ]; then
        an_disp="${an_disp:0:$((acct_nw - 1))}…"
      fi
      local ncell
      printf -v ncell '%-*s %s' "$acct_g" "$mk" "$an_disp"
      if [ -n "$mk" ] && { [ -n "${TEST_SKIP[$n]:-}" ] || [ -n "${TEST_TRY[$n]:-}" ]; }; then
        any_locked=1
      fi

      if [ -n "${TEST_SKIP[$n]:-}" ]; then
        local skip_txt="skipped (${TEST_SKIP[$n]})"
        if [ "${#skip_txt}" -gt "$hi_pad" ]; then
          skip_txt="${skip_txt:0:$((hi_pad - 1))}…"
        fi
        local extra=""
        if [ "$has_argon" -eq 1 ]; then
          if [ "$show_test_argon" -eq 1 ]; then
            extra+="$(printf ' │ %-12s │ %-*s' "-" "$a_rst_pad" "-")"
          fi
          if [ "$show_test_claude" -eq 1 ]; then
            extra+="$(printf ' │ %-12s │ %-*s' "-" "$c_rst_pad" "-")"
          fi
        fi
        printf '%s│ %-*s │ %s%-*s%s │ %-12s │ %-*s%s │%s\n' "$row_bg" "$acct_w" "$ncell" "$Y" "$hi_pad" "$skip_txt" "$Z" "-" "$rst_pad" "-" "$extra" "$ALL_RST"
        continue
      fi
      if [ -z "${TEST_TRY[$n]:-}" ]; then continue; fi

      local txt hcol has_acct_argon
      read_hi_result "$n"

      snap="$(jq -r --arg n "$n" '.quota[$n] // empty | [(.g5 // "-"), (.g5r // 0), (.a5 // "-"), (.a5r // 0), (.aw // "-"), (.awr // 0), (.c5 // "-"), (.c5r // 0)] | @tsv' "$STATE" 2>/dev/null)"
      g5="" g5r="" a5="" a5r="" aw="" awr="" c5="" c5r=""
      if [ -n "$snap" ]; then
        IFS=$'\t' read -r g5 g5r a5 a5r aw awr c5 c5r <<<"$snap"
      fi
      if [ "${g5:-}" = "-" ]; then g5=""; fi
      if [ "${a5:-}" = "-" ]; then a5=""; fi
      if [ "${aw:-}" = "-" ]; then aw=""; fi
      if [ "${c5:-}" = "-" ]; then c5=""; fi

      local out_val out_rst out_b_epoch
      test_col_cell "$n" "Gemini Models" "Five Hour" "$g5" "$g5r" "$rst_pad" "$layout_tier"
      local g_val="$out_val" reset_disp="$out_rst"

      local argon_val="-" argon_rst="-" claude_val="-" claude_rst="-"
      if [ "$has_argon" -eq 1 ] && [ "$has_acct_argon" -eq 1 ]; then
        if [ "$has_argon_5h" -eq 1 ]; then
          test_col_cell "$n" "Gemini 4 Argon" "Five Hour" "$a5" "$a5r" "$a_rst_pad" "$layout_tier"
        else
          test_col_cell "$n" "Gemini 4 Argon" "Weekly" "$aw" "$awr" "$a_rst_pad" "$layout_tier"
        fi
        argon_val="$out_val"
        argon_rst="$out_rst"

        test_col_cell "$n" "Claude and GPT models" "Five Hour" "$c5" "$c5r" "$c_rst_pad" "$layout_tier"
        claude_val="$out_val"
        claude_rst="$out_rst"
      fi

      local extra=""
      if [ "$has_argon" -eq 1 ]; then
        if [ "$show_test_argon" -eq 1 ]; then
          extra+="$(printf ' │ %-12s │ %-*s' "${argon_val:-?}" "$a_rst_pad" "${argon_rst:--}")"
        fi
        if [ "$show_test_claude" -eq 1 ]; then
          extra+="$(printf ' │ %-12s │ %-*s' "${claude_val:-?}" "$c_rst_pad" "${claude_rst:--}")"
        fi
      fi

      local hi_out="$txt"
      if [ "$layout_tier" -eq 2 ] && [ "${#hi_out}" -gt "$hi_pad" ]; then
        hi_out="${hi_out:0:$((hi_pad - 1))}…"
      fi
      printf '%s│ %-*s │ %s%-*s%s │ %-12s │ %-*s%s │%s\n' "$row_bg" "$acct_w" "$ncell" "$hcol" "$hi_pad" "$hi_out" "$Z" "$g_val" "$rst_pad" "$reset_disp" "$extra" "$ALL_RST"
    done < <(slots)
    echo "$bot"
  else # layout_tier == 3: vertical blocks
    local col_w=11 block_idx=0
    print_vert_test_line() {
      local qlbl="$1" qval="$2" qepoch="${3:-0}" qb_epoch="${4:-}"
      local qpfx
      if [ "$tw" -gt 0 ] && [ "$tw" -lt 35 ]; then
        printf -v qpfx '%*s %s ' "$acct_g" "" "$qlbl"
      else
        printf -v qpfx '%*s %-*s  ' "$acct_g" "" "$col_w" "$qlbl"
      fi
      local qpfx_len=${#qpfx}
      if [ "$tw" -gt 0 ] && [ "$qpfx_len" -ge "$tw" ]; then
        if [ "$tw" -lt 30 ]; then printf '%s\n' "${qpfx:0:$tw}"; else printf '%s\n' "${qpfx:0:$((tw - 1))}…"; fi
        return
      fi

      local rst_str=""
      if [ -n "$qepoch" ] && [ "$qepoch" != 0 ]; then
        local diff=0
        if [ -n "$qb_epoch" ] && [ "$qb_epoch" != 0 ]; then
          diff=$((qepoch - qb_epoch))
          if [ "$diff" -lt 0 ]; then diff=$((-diff)); fi
        fi
        local full_rst="resets $(fmt_time "$qepoch")"
        if [ "$diff" -gt 120 ]; then
          local was_iso
          was_iso="$(date -d "@$qb_epoch" '+%I:%M %p' 2>/dev/null || echo "")"
          if [ -n "$was_iso" ]; then full_rst+=" (was $was_iso)"; fi
        fi

        if [ "$tw" -le 0 ] || [ $((qpfx_len + ${#qval} + 4 + ${#full_rst})) -le "$tw" ]; then
          rst_str="$full_rst"
        else
          local short_rst="resets $(fmt_short_time "$qepoch")"
          if [ "$diff" -gt 120 ]; then
            local was_short
            was_short="$(date -d "@$qb_epoch" '+%H:%M' 2>/dev/null || echo "")"
            if [ -n "$was_short" ] && [ $((qpfx_len + ${#qval} + 4 + ${#short_rst} + ${#was_short} + 7)) -le "$tw" ]; then
              short_rst+=" (was $was_short)"
            elif [ $((qpfx_len + ${#qval} + 4 + ${#short_rst} + 1)) -le "$tw" ]; then
              short_rst+="*"
            fi
          fi
          if [ $((qpfx_len + ${#qval} + 4 + ${#short_rst})) -le "$tw" ]; then
            rst_str="$short_rst"
          else
            local avail_rst=$((tw - qpfx_len - ${#qval} - 4))
            if [ "$avail_rst" -gt 8 ]; then
              rst_str="${short_rst:0:$((avail_rst - 1))}…"
            else
              rst_str=""
            fi
          fi
        fi
      fi

      local full_val="$qval"
      if [ -n "$rst_str" ]; then
        printf -v full_val '%-10s  %s' "$qval" "$rst_str"
      fi

      local full_line="${qpfx}${full_val}"
      if [ "$tw" -gt 0 ] && [ "${#full_line}" -gt "$tw" ]; then
        if [ "$tw" -lt 30 ]; then printf '%s\n' "${full_line:0:$tw}"; else printf '%s\n' "${full_line:0:$((tw - 1))}…"; fi
      else
        printf '%s\n' "$full_line"
      fi
    }

    while read -r n; do
      if [ -z "${TEST_SKIP[$n]:-}" ] && [ -z "${TEST_TRY[$n]:-}" ]; then continue; fi
      if [ "$block_idx" -gt 0 ]; then echo ""; fi
      block_idx=$((block_idx + 1))

      local mk=""
      if is_locked "$n"; then mk="!!"; any_locked=1; fi
      local line1
      printf -v line1 '%-*s %s' "$acct_g" "$mk" "$n"
      if [ "$tw" -gt 0 ] && [ "${#line1}" -gt "$tw" ]; then
        if [ "$tw" -lt 30 ]; then line1="${line1:0:$tw}"; else line1="${line1:0:$((tw - 1))}…"; fi
      fi
      printf '%s\n' "$line1"

      if [ -n "${TEST_SKIP[$n]:-}" ]; then
        local skip_txt="skipped (${TEST_SKIP[$n]})"
        local pfx
        if [ "$tw" -gt 0 ] && [ "$tw" -lt 35 ]; then
          printf -v pfx '%*s %s ' "$acct_g" "" "HI"
        else
          printf -v pfx '%*s %-*s  ' "$acct_g" "" "$col_w" "HI"
        fi
        if [ "$tw" -gt 0 ]; then
          local avail=$((tw - ${#pfx}))
          if [ "${#skip_txt}" -gt "$avail" ]; then
            if [ "$tw" -lt 30 ]; then skip_txt="${skip_txt:0:$avail}"
            elif [ "$avail" -gt 1 ]; then skip_txt="${skip_txt:0:$((avail - 1))}…"
            else skip_txt=""; fi
          fi
        fi
        printf '%s%s%s%s\n' "$pfx" "$Y" "$skip_txt" "$ALL_RST"
        continue
      fi

      local txt hcol has_acct_argon
      read_hi_result "$n"

      local pfx
      if [ "$tw" -gt 0 ] && [ "$tw" -lt 35 ]; then
        printf -v pfx '%*s %s ' "$acct_g" "" "HI"
      else
        printf -v pfx '%*s %-*s  ' "$acct_g" "" "$col_w" "HI"
      fi
      local hi_txt="$txt"
      if [ "$tw" -gt 0 ]; then
        local avail=$((tw - ${#pfx}))
        if [ "${#hi_txt}" -gt "$avail" ]; then
          if [ "$tw" -lt 30 ]; then hi_txt="${hi_txt:0:$avail}"
          elif [ "$avail" -gt 1 ]; then hi_txt="${hi_txt:0:$((avail - 1))}…"
          else hi_txt=""; fi
        fi
      fi
      printf '%s%s%s%s\n' "$pfx" "$hcol" "$hi_txt" "$ALL_RST"

      snap="$(jq -r --arg n "$n" '.quota[$n] // empty | [(.g5 // "-"), (.g5r // 0), (.a5 // "-"), (.a5r // 0), (.aw // "-"), (.awr // 0), (.c5 // "-"), (.c5r // 0)] | @tsv' "$STATE" 2>/dev/null)"
      g5="" g5r="" a5="" a5r="" aw="" awr="" c5="" c5r=""
      if [ -n "$snap" ]; then
        IFS=$'\t' read -r g5 g5r a5 a5r aw awr c5 c5r <<<"$snap"
      fi
      if [ "${g5:-}" = "-" ]; then g5=""; fi
      if [ "${a5:-}" = "-" ]; then a5=""; fi
      if [ "${aw:-}" = "-" ]; then aw=""; fi
      if [ "${c5:-}" = "-" ]; then c5=""; fi

      local out_val out_rst out_b_epoch
      test_col_cell "$n" "Gemini Models" "Five Hour" "$g5" "$g5r" 0 3
      print_vert_test_line "GEMINI 5H" "$out_val" "$g5r" "$out_b_epoch"

      if [ "$has_argon" -eq 1 ] && [ "$has_acct_argon" -eq 1 ]; then
        if [ "$argon_hidden" -eq 0 ]; then
          if [ "$has_argon_5h" -eq 1 ]; then
            test_col_cell "$n" "Gemini 4 Argon" "Five Hour" "$a5" "$a5r" 0 3
            print_vert_test_line "$argon_hdr" "$out_val" "$a5r" "$out_b_epoch"
          else
            test_col_cell "$n" "Gemini 4 Argon" "Weekly" "$aw" "$awr" 0 3
            print_vert_test_line "$argon_hdr" "$out_val" "$awr" "$out_b_epoch"
          fi
        fi

        if [ "$claude_hidden" -eq 0 ]; then
          test_col_cell "$n" "Claude and GPT models" "Five Hour" "$c5" "$c5r" 0 3
          print_vert_test_line "CLAUDE 5H" "$out_val" "$c5r" "$out_b_epoch"
        fi
      fi
    done < <(slots)
  fi

  if [ "$is_wide" = 0 ] && [ "$has_argon" -eq 1 ]; then
    print_hidden_note "test" "$claude_hidden" "$argon_hidden" "$tw"
  fi
  print_tier_note "test" "$layout_tier" "$is_wide" "$tw"

  local lock_note=""
  if [ "$any_locked" = 1 ]; then lock_note="; !! = locked account, do not use this"; fi
  local msg="Measured at $(fmt_time "$(now)")"
  local legend_txt="(GEMINI 5H = before>after; RESETS = end of the account's current 5-hour window; \"(was ...)\" = it moved because of the Hi${lock_note})"
  print_footer "$msg" "$legend_txt" "$tw"
}

# test [name...]: send "Hi" to every account (or only the named ones) and show what it cost
cmd_test() {
  need_jq; init_state
  command -v "$AGY_BIN" >/dev/null || die "agy not found ($AGY_BIN)"
  local a n t until
  local -a all=() names=() args=()
  for a in "$@"; do
    case "$a" in
      -w|--wide) export AGYR_WIDE=1 ;;
      *) args+=("$a") ;;
    esac
  done
  set -- "${args[@]}"
  for a in "$@"; do
    valid_name "$a"
    [ -f "$ACCTS/$a.token" ] || die "no slot '$a' (see: agyr list)"
  done
  mapfile -t all < <(slots)
  if [ "${#all[@]}" -eq 0 ]; then echo "(no accounts yet; log in with 'agyr', then run 'agyr save <name>')"; return 0; fi
  TEST_TRY=() TEST_SKIP=()
  t="$(now)"
  if [ $# -gt 0 ]; then
    for n in "$@"; do
      if [ -z "${TEST_TRY[$n]:-}" ]; then TEST_TRY[$n]=1; names+=("$n"); fi
    done
  else
    # a locked account is tested too: 'agyr test' is something the user runs on purpose, the lock only keeps automatic
    # rotation (next / rotate / agy-run) away from an account; the table marks it with "!!"
    for n in "${all[@]}"; do
      until="$(cooldown_until "$n")"
      if [ "$until" -gt "$t" ]; then TEST_SKIP[$n]="cooldown, $(fmt_dur $((until - t))) left"; else TEST_TRY[$n]=1; names+=("$n"); fi
    done
  fi
  if [ "${#names[@]}" -eq 0 ]; then
    echo "nothing to do: every account is on cooldown (name an account to send it \"Hi\" anyway: agyr test <name>)"
    return 0
  fi
  echo "Sending \"Hi\" to ${#names[@]} account(s): one real request each, so it uses a little quota..." >&2
  TEST_DIR="$(mktemp -d)"
  PROBE_FN=test_probe INGEST_FN=test_ingest
  measure_all "${names[@]}"
  PROBE_FN=quota_fetch INGEST_FN=quota_ingest
  local failed="$MEASURE_FAILED"
  print_test_table
  rm -rf "$TEST_DIR"; TEST_DIR=""
  [ -z "$failed" ]
}
