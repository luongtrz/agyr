#!/usr/bin/env bash
# Independent core test section.
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$TEST_DIR/lib.sh"

echo "== test: Gemini 4 Argon and Claude Hi calls"
setup
out="$(AGYR_COLOR=never "$ACCT" test 2>/dev/null)"; rc=$?
eq "test without argon: exit 0" "0" "$rc"
eq "test without argon: 1 Hi per account (3 total)" "3" "$(hi_count)"
eq "test without argon: all 3 Hi calls use gemini-3.8-flash-low" "3" "$(hi_lines | grep -c -- '--model gemini-3.8-flash-low')"
eq "test without argon: no argon Hi calls" "0" "$(hi_lines | grep -c -- '--model gemini-4-argon-low')"
eq "test without argon: no claude Hi calls" "0" "$(hi_lines | grep -c -- '--model claude-sonnet-5-5-low')"
hasnt "test without argon: no ARGON column" "ARGON" "$out"
hasnt "test without argon: no CLAUDE column" "CLAUDE" "$out"

setup
out="$(FAKE_ARGON_TOKENS="tok-acc2" AGYR_COLOR=never "$ACCT" test 2>/dev/null)"; rc=$?
eq "test with argon: exit 0" "0" "$rc"
eq "test with argon: 5 Hi calls total" "5" "$(hi_count)"
eq "test with argon: 3 calls to gemini-3.8-flash-low" "3" "$(hi_lines | grep -c -- '--model gemini-3.8-flash-low')"
eq "test with argon: 1 call to gemini-4-argon-low" "1" "$(hi_lines | grep -c -- '--model gemini-4-argon-low')"
eq "test with argon: 1 call to claude-sonnet-5-5-low" "1" "$(hi_lines | grep -c -- '--model claude-sonnet-5-5-low')"
eq "test with argon: acc1 got 1 Hi call" "1" "$(hi_lines | grep -cF 'tok-acc1|')"
eq "test with argon: acc2 got 3 Hi calls" "3" "$(hi_lines | grep -cF 'tok-acc2|')"
eq "test with argon: acc3 got 1 Hi call" "1" "$(hi_lines | grep -cF 'tok-acc3|')"
has "test with argon: ARGON WEEK column in header" "ARGON WEEK" "$out"
has "test with argon: ARGON RESETS column in header" "ARGON RESETS" "$out"
has "test with argon: CLAUDE 5H column in header" "CLAUDE 5H" "$out"
has "test with argon: CLAUDE RESETS column in header" "CLAUDE RESETS" "$out"
row1="$(grep '  acc1 ' <<<"$out")"
row2="$(grep '  acc2 ' <<<"$out")"
row3="$(grep '  acc3 ' <<<"$out")"
has "test with argon: acc2 Argon before>after (45%>44%)" "45%>44%" "$row2"
has "test with argon: acc2 Claude 5H before>after (100%>99%)" "100%>99%" "$row2"
has "test with argon: acc1 shows - for Argon" " - " "$row1"
has "test with argon: acc3 shows - for Argon" " - " "$row3"

setup
out="$(FAKE_ARGON_TOKENS="tok-acc2" FAKE_ARGON_5H=1 AGYR_COLOR=never "$ACCT" test 2>/dev/null)"; rc=$?
eq "test with argon 5h: exit 0" "0" "$rc"
has "test with argon 5h: ARGON 5H column in header" "ARGON 5H" "$out"
has "test with argon 5h: acc2 Argon 5H before>after (65%>64%)" "65%>64%" "$(grep '  acc2 ' <<<"$out")"
has "help test: mentions gemini-4-argon-low" "gemini-4-argon-low" "$("$ACCT" help test)"
has "help test: mentions claude-sonnet-5-5-low" "claude-sonnet-5-5-low" "$("$ACCT" help test)"

exit 0
