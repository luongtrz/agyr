#!/usr/bin/env bash
# Independent core test section.
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$TEST_DIR/lib.sh"

echo "== responsive terminal width (-w / --wide)"
setup
FAKE_ARGON_TOKENS="tok-acc2" "$ACCT" list >/dev/null 2>&1
# At 120 columns: Argon and Claude are hidden
out="$(AGYR_RESPONSIVE=1 AGYR_COLUMNS=120 "$ACCT" list -c --claude)"
hasnt "responsive 120: CLAUDE hidden" "CLAUDE" "$out"
hasnt "responsive 120: ARGON hidden" "ARGON" "$out"
has "responsive 120: has STATUS" "STATUS" "$out"
has "responsive 120: notes hidden columns" "Note: Argon and Claude columns hidden to fit terminal width 120" "$out"

# With -w: forced full width
out="$("$ACCT" list -c -w --claude)"
has "responsive -w: CLAUDE shown" "CLAUDE" "$out"
has "responsive -w: ARGON shown" "ARGON" "$out"
hasnt "responsive -w: no hidden note" "columns hidden" "$out"

# At 150 columns: Claude hidden, Argon kept
out="$(AGYR_RESPONSIVE=1 AGYR_COLUMNS=150 "$ACCT" list -c --claude)"
hasnt "responsive 150: CLAUDE hidden" "CLAUDE" "$out"
has "responsive 150: ARGON shown" "ARGON" "$out"
has "responsive 150: notes Claude hidden" "Note: Claude columns hidden to fit terminal width 150" "$out"

# Progressive responsive tiers: line widths never exceed terminal columns (for widths 200 down to 30)
for w in 200 150 120 100 95 90 80 70 60 50 40 30; do
  out="$(AGYR_RESPONSIVE=1 AGYR_COLUMNS=$w "$ACCT" list -c)"
  over=0
  while IFS= read -r line; do
    if [ "${#line}" -gt "$w" ]; then over=1; fi
  done <<<"$out"
  eq "responsive $w: list -c no line wider than $w" "0" "$over"

  out="$(AGYR_RESPONSIVE=1 AGYR_COLUMNS=$w "$ACCT" list -c --claude)"
  over=0
  while IFS= read -r line; do
    if [ "${#line}" -gt "$w" ]; then over=1; fi
  done <<<"$out"
  eq "responsive $w: list -c --claude no line wider than $w" "0" "$over"
done

# Widths where full layout fits (>= today's minimum) match unconstrained output
out_resp="$(AGYR_RESPONSIVE=1 AGYR_COLUMNS=200 "$ACCT" list -c)"
out_norm="$("$ACCT" list -c)"
eq "responsive 200: full layout identical to unconstrained" "$out_norm" "$out_resp"
out_wide_resp="$(AGYR_RESPONSIVE=1 AGYR_COLUMNS=200 "$ACCT" list -c -w)"
out_wide_norm="$("$ACCT" list -c -w)"
eq "responsive 200: wide layout identical to unconstrained wide" "$out_wide_norm" "$out_wide_resp"

# At 80: compact cell format (no 4-digit year in rows) and all account names visible
out="$(AGYR_RESPONSIVE=1 AGYR_COLUMNS=80 "$ACCT" list -c)"
has "responsive 80: acc1 visible" "acc1" "$out"
has "responsive 80: acc2 visible" "acc2" "$out"
has "responsive 80: acc3 visible" "acc3" "$out"
row_lines="$(grep '│' <<<"$out" | grep -v 'ACCOUNT')"
hasnt "responsive 80: no 4-digit year in rows" "1970" "$row_lines"
has "responsive 80: compact note present" "compact layout to fit terminal width 80" "$out"

# At 50: vertical tier, all names and labels appear, no line wider than 50
out="$(AGYR_RESPONSIVE=1 AGYR_COLUMNS=50 "$ACCT" list -c)"
has "responsive 50: acc1 appears" "acc1" "$out"
has "responsive 50: acc2 appears" "acc2" "$out"
has "responsive 50: acc3 appears" "acc3" "$out"
has "responsive 50: GEMINI 5H appears" "GEMINI 5H" "$out"
has "responsive 50: GEMINI WEEK appears" "GEMINI WEEK" "$out"
has "responsive 50: vertical note present" "one block per account to fit terminal width 50" "$(tr '\n' ' ' <<<"$out" | tr -s ' ')"
# the legend under the table is never cut in the middle of "(* = ...": at 100 columns it moves to its own line, whole
out100="$(AGYR_RESPONSIVE=1 AGYR_COLUMNS=100 "$ACCT" list -c)"
hasnt "responsive 100: legend not split after '(* ='" "(* =" "$(grep -v '(\* = selected' <<<"$out100")"
over=0
while IFS= read -r line; do
  if [ "${#line}" -gt 50 ]; then over=1; fi
done <<<"$out"
eq "responsive 50: no line wider than 50" "0" "$over"

# Markers in every tier: locked account and selected account
"$ACCT" lock acc2 >/dev/null
# Tier 1 (150)
out="$(AGYR_RESPONSIVE=1 AGYR_COLUMNS=150 "$ACCT" list -c)"
has "locked tier 1: * marker" "*  acc1" "$out"
has "locked tier 1: !! marker" "!! acc2" "$out"
has "locked tier 1: legend note" "!! = locked account, do not use this" "$out"
# Tier 2 (80)
out="$(AGYR_RESPONSIVE=1 AGYR_COLUMNS=80 "$ACCT" list -c)"
has "locked tier 2: * marker" "*  acc1" "$out"
has "locked tier 2: !! marker" "!! acc2" "$out"
has "locked tier 2: legend note" "!! = locked account, do not use this" "$out"
# Tier 3 (50)
out="$(AGYR_RESPONSIVE=1 AGYR_COLUMNS=50 "$ACCT" list -c)"
has "locked tier 3: * marker" "*  acc1" "$out"
has "locked tier 3: !! marker" "!! acc2" "$out"
has "locked tier 3: legend note" "!! = locked account, do not use this" "$(tr '\n' ' ' <<<"$out" | tr -s ' ')"
"$ACCT" unlock acc2 >/dev/null

# Wide mode: with FAKE_ARGON_TOKENS="tok-acc2" and list -c -w --claude under AGYR_RESPONSIVE=1
for w in 250 200 150 120 100 80 60 50 40 30; do
  out="$(FAKE_ARGON_TOKENS="tok-acc2" AGYR_RESPONSIVE=1 AGYR_COLUMNS=$w "$ACCT" list -c -w --claude)"
  over=0
  while IFS= read -r line; do
    if [ "${#line}" -gt "$w" ]; then over=1; fi
  done <<<"$out"
  eq "wide responsive $w: no line wider than $w" "0" "$over"

  if [ "$w" -ge 120 ]; then
    has "wide responsive $w: ARGON header present" "ARGON" "$out"
    has "wide responsive $w: CLAUDE header present" "CLAUDE" "$out"
    hasnt "wide responsive $w: no columns hidden note" "columns hidden" "$out"
  fi

  if [ "$w" -le 60 ]; then
    has "wide responsive $w: ARGON line present" "ARGON" "$out"
    has "wide responsive $w: CLAUDE line present" "CLAUDE" "$out"
  fi
done

# agyr test responsive
setup
out="$(FAKE_ARGON_TOKENS="tok-acc2" AGYR_COLOR=never AGYR_RESPONSIVE=1 AGYR_COLUMNS=120 "$ACCT" test 2>/dev/null)"
hasnt "test responsive 120: CLAUDE hidden" "CLAUDE" "$out"
hasnt "test responsive 120: ARGON hidden" "ARGON" "$out"
has "test responsive 120: notes hidden columns" "Note: Argon and Claude columns hidden to fit terminal width 120" "$out"

out="$(FAKE_ARGON_TOKENS="tok-acc2" AGYR_COLOR=never AGYR_RESPONSIVE=1 AGYR_COLUMNS=120 "$ACCT" test -w 2>/dev/null)"
has "test responsive -w: CLAUDE shown" "CLAUDE" "$out"
has "test responsive -w: ARGON shown" "ARGON" "$out"
hasnt "test responsive -w: no hidden note" "columns hidden" "$out"

# Progressive responsive tiers for agyr test: line widths never exceed terminal columns (widths 250 down to 30)
for w in 250 200 150 120 100 80 60 50 40 30; do
  out="$(FAKE_ARGON_TOKENS="tok-acc2" AGYR_COLOR=never AGYR_RESPONSIVE=1 AGYR_COLUMNS=$w "$ACCT" test 2>/dev/null)"
  over=0
  while IFS= read -r line; do
    if [ "${#line}" -gt "$w" ]; then over=1; fi
  done <<<"$out"
  eq "test responsive $w: no line wider than $w" "0" "$over"

  out="$(FAKE_ARGON_TOKENS="tok-acc2" AGYR_COLOR=never AGYR_RESPONSIVE=1 AGYR_COLUMNS=$w "$ACCT" test -w 2>/dev/null)"
  over=0
  while IFS= read -r line; do
    if [ "${#line}" -gt "$w" ]; then over=1; fi
  done <<<"$out"
  eq "test wide responsive $w: no line wider than $w" "0" "$over"
done

# With locked account: line widths never exceed terminal columns
"$ACCT" lock acc2 >/dev/null
for w in 250 200 150 120 100 80 60 50 40 30; do
  out="$(FAKE_ARGON_TOKENS="tok-acc2" AGYR_COLOR=never AGYR_RESPONSIVE=1 AGYR_COLUMNS=$w "$ACCT" test 2>/dev/null)"
  over=0
  while IFS= read -r line; do
    if [ "${#line}" -gt "$w" ]; then over=1; fi
  done <<<"$out"
  eq "test locked responsive $w: no line wider than $w" "0" "$over"

  out="$(FAKE_ARGON_TOKENS="tok-acc2" AGYR_COLOR=never AGYR_RESPONSIVE=1 AGYR_COLUMNS=$w "$ACCT" test -w 2>/dev/null)"
  over=0
  while IFS= read -r line; do
    if [ "${#line}" -gt "$w" ]; then over=1; fi
  done <<<"$out"
  eq "test locked wide responsive $w: no line wider than $w" "0" "$over"
done
"$ACCT" unlock acc2 >/dev/null

# Widths where full layout fits match unconstrained output
# (each 'agyr test' spends 1% of the fake quota and the seconds in "ok in Ns" depend on the clock: compare the layout only)
out_resp="$(AGYR_COLOR=never AGYR_RESPONSIVE=1 AGYR_COLUMNS=200 "$ACCT" test 2>/dev/null | nopct)"
out_norm="$(AGYR_COLOR=never "$ACCT" test 2>/dev/null | nopct)"
eq "test responsive 200: full layout identical to unconstrained" "$out_norm" "$out_resp"
out_wide_resp="$(AGYR_COLOR=never AGYR_RESPONSIVE=1 AGYR_COLUMNS=200 "$ACCT" test -w 2>/dev/null | nopct)"
out_wide_norm="$(AGYR_COLOR=never "$ACCT" test -w 2>/dev/null | nopct)"
eq "test responsive 200: wide layout identical to unconstrained wide" "$out_wide_norm" "$out_wide_resp"

# At 80: compact (no 4-digit year in RESETS cells) and every account name visible
out="$(AGYR_COLOR=never AGYR_RESPONSIVE=1 AGYR_COLUMNS=80 "$ACCT" test 2>/dev/null)"
has "test responsive 80: acc1 visible" "acc1" "$out"
has "test responsive 80: acc2 visible" "acc2" "$out"
has "test responsive 80: acc3 visible" "acc3" "$out"
row_lines="$(grep '│' <<<"$out" | grep -v 'ACCOUNT')"
hasnt "test responsive 80: no 4-digit year in rows" "1970" "$row_lines"
has "test responsive 80: compact note present" "compact layout to fit terminal width 80" "$out"

# At 50: vertical blocks, every account name, HI and GEMINI 5H labels, no line wider than 50
out="$(AGYR_COLOR=never AGYR_RESPONSIVE=1 AGYR_COLUMNS=50 "$ACCT" test 2>/dev/null)"
has "test responsive 50: acc1 appears" "acc1" "$out"
has "test responsive 50: acc2 appears" "acc2" "$out"
has "test responsive 50: acc3 appears" "acc3" "$out"
has "test responsive 50: HI appears" "HI" "$out"
has "test responsive 50: GEMINI 5H appears" "GEMINI 5H" "$out"
has "test responsive 50: vertical note present" "one block per account to fit terminal width 50" "$(tr '\n' ' ' <<<"$out" | tr -s ' ')"
over=0
while IFS= read -r line; do
  if [ "${#line}" -gt 50 ]; then over=1; fi
done <<<"$out"
eq "test responsive 50: no line wider than 50" "0" "$over"

# Markers in every tier: locked account
"$ACCT" lock acc2 >/dev/null
# Tier 1 (150)
out="$(AGYR_COLOR=never AGYR_RESPONSIVE=1 AGYR_COLUMNS=150 "$ACCT" test 2>/dev/null)"
has "test locked tier 1: !! marker" "!! acc2" "$out"
has "test locked tier 1: legend note" "!! = locked account, do not use this" "$(tr '\n' ' ' <<<"$out" | tr -s ' ')"
# Tier 2 (80)
out="$(AGYR_COLOR=never AGYR_RESPONSIVE=1 AGYR_COLUMNS=80 "$ACCT" test 2>/dev/null)"
has "test locked tier 2: !! marker" "!! acc2" "$out"
has "test locked tier 2: legend note" "!! = locked account, do not use this" "$(tr '\n' ' ' <<<"$out" | tr -s ' ')"
# Tier 3 (50)
out="$(AGYR_COLOR=never AGYR_RESPONSIVE=1 AGYR_COLUMNS=50 "$ACCT" test 2>/dev/null)"
has "test locked tier 3: !! marker" "!! acc2" "$out"
has "test locked tier 3: legend note" "!! = locked account, do not use this" "$(tr '\n' ' ' <<<"$out" | tr -s ' ')"
"$ACCT" unlock acc2 >/dev/null

# Wide mode with Argon fixtures: test -w at N >= 150 keeps ARGON and CLAUDE headers; at N <= 60 lines appear in block
for w in 250 200 150 120 100 80 60 50 40 30; do
  out="$(FAKE_ARGON_TOKENS="tok-acc2" AGYR_COLOR=never AGYR_RESPONSIVE=1 AGYR_COLUMNS=$w "$ACCT" test -w 2>/dev/null)"
  if [ "$w" -ge 150 ]; then
    has "test wide responsive $w: ARGON header present" "ARGON" "$out"
    has "test wide responsive $w: CLAUDE header present" "CLAUDE" "$out"
    hasnt "test wide responsive $w: no columns hidden note" "columns hidden" "$out"
  fi
  if [ "$w" -le 60 ]; then
    has "test wide responsive $w: ARGON line present" "ARGON" "$out"
    has "test wide responsive $w: CLAUDE line present" "CLAUDE" "$out"
  fi
done

has "help list: mentions -w" "-w, --wide" "$("$ACCT" help list)"
has "help list: mentions --claude" "--claude" "$("$ACCT" help list)"
has "help test: mentions -w" "-w, --wide" "$("$ACCT" help test)"

exit 0
