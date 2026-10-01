#!/usr/bin/env bash
# Test cho agyr và agy-run. Dùng token giả + agy giả, không đụng token thật.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ACCT="$HERE/../bin/agyr"
RUN="$HERE/../bin/agy-run"
export AGY_BIN="$HERE/fake-agy"
export AGY_ACCT="$ACCT"
export AGY_RUN_POLL=0.1

export TZ=UTC-7 # cùng múi giờ với agyr để dựng dòng log giả cho khớp
REAL_TOKEN="$HOME/.gemini/antigravity-cli/antigravity-oauth-token"
REAL_MTIME_BEFORE="$(stat -c %Y "$REAL_TOKEN" 2>/dev/null || echo none)"

PASS=0 FAIL=0
pass() { PASS=$((PASS + 1)); echo "  ok   $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL $1"; [ $# -gt 1 ] && echo "       $2"; }
eq() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "mong đợi '$2', được '$3'"; fi; }
has() { if grep -qF -- "$2" <<<"$3"; then pass "$1"; else fail "$1" "không thấy '$2' trong: $3"; fi; }
hasnt() { if grep -qF -- "$2" <<<"$3"; then fail "$1" "không được có '$2' trong: $3"; else pass "$1"; fi; }

TMPS=()
cleanup() { for d in "${TMPS[@]}"; do rm -rf "$d"; done; }
trap cleanup EXIT

# pool 3 account; account acc1 đang active, token = tok-acc1
setup() {
  T="$(mktemp -d)"; TMPS+=("$T")
  export AGY_HOME="$T/home"; mkdir -p "$AGY_HOME"
  export AGY_NOW=1000000
  export FAKE_ARGS_LOG="$T/args.log"; : >"$FAKE_ARGS_LOG"
  unset FAKE_QUOTA_TOKENS FAKE_AUTH FAKE_RESET AGY_RUN_MAX_SWITCH
  local a
  for a in "${@:-acc1 acc2 acc3}"; do :; done
  for a in acc1 acc2 acc3; do
    echo "tok-$a" >"$AGY_HOME/antigravity-oauth-token"
    "$ACCT" save "$a" >/dev/null
  done
  "$ACCT" use acc1 >/dev/null
  echo "do the thing" >"$T/prompt.txt"
  mkdir -p "$T/work"
}
cd_of() { jq -r --arg n "$1" '.cooldown[$n] // 0' "$AGY_HOME/accounts/state.json"; }
runit() { "$RUN" --prompt "$T/prompt.txt" --add-dir "$T/work" --log "$T/run.jsonl" 2>"$T/run.err"; }
lines() { wc -l <"$FAKE_ARGS_LOG" | tr -d ' '; }

echo "== agyr"

setup
out="$("$ACCT" list)"
has "list: có acc1 active" "* acc1" "$out"
has "list: có acc2" "  acc2" "$out"
eq "active = acc1" "acc1" "$("$ACCT" active)"
eq "slot quyền 600" "600" "$(stat -c %a "$AGY_HOME/accounts/acc1.token")"
eq "thư mục accounts quyền 700" "700" "$(stat -c %a "$AGY_HOME/accounts")"
eq "token chuyển đúng sau use" "tok-acc1" "$(cat "$AGY_HOME/antigravity-oauth-token")"

out="$("$ACCT" save acc9 2>&1)"; hasnt "save không in token" "tok-" "$out"
"$ACCT" use acc1 >/dev/null

echo "tok-acc1-refreshed" >"$AGY_HOME/antigravity-oauth-token"
out="$("$ACCT" use acc2 2>&1)"
hasnt "use không in token" "tok-" "$out"
eq "use: token = slot acc2" "tok-acc2" "$(cat "$AGY_HOME/antigravity-oauth-token")"
eq "use: sync-back token đã refresh về acc1" "tok-acc1-refreshed" "$(cat "$AGY_HOME/accounts/acc1.token")"
eq "use: có backup token trước khi ghi đè" "tok-acc1-refreshed" "$(cat "$AGY_HOME/accounts/.last-token.bak")"
eq "use: active = acc2" "acc2" "$("$ACCT" active)"

"$ACCT" use nope >/dev/null 2>&1; eq "use slot không tồn tại -> lỗi" "1" "$?"
"$ACCT" use '../x' >/dev/null 2>&1; eq "tên account sai -> lỗi" "1" "$?"
"$ACCT" bogus >/dev/null 2>&1; eq "lệnh lạ -> exit 2" "2" "$?"

echo "== cooldown / next"
setup
"$ACCT" cooldown acc1 "Resets in 4h13m27s" >/dev/null
eq "parse 4h13m27s" "$((1000000 + 15207))" "$(cd_of acc1)"
"$ACCT" cooldown acc1 "43m29s" >/dev/null;  eq "parse 43m29s" "$((1000000 + 2609))" "$(cd_of acc1)"
"$ACCT" cooldown acc1 90 >/dev/null;        eq "parse số giây thuần" "$((1000000 + 90))" "$(cd_of acc1)"
"$ACCT" cooldown acc1 "1d2h" >/dev/null;    eq "parse 1d2h" "$((1000000 + 93600))" "$(cd_of acc1)"
"$ACCT" cooldown acc1 "error: Individual quota reached. Resets in 2h. (x)" >/dev/null
eq "parse cả câu lỗi" "$((1000000 + 7200))" "$(cd_of acc1)"
out="$("$ACCT" cooldown acc1 "linh tinh" 2>&1)"
eq "không parse được -> mặc định 5h" "$((1000000 + 18000))" "$(cd_of acc1)"
has "báo cảnh báo khi không parse được" "mặc định 5h" "$out"
"$ACCT" clear acc1 >/dev/null; eq "clear xóa cooldown" "0" "$(cd_of acc1)"

setup
eq "next từ acc1 (không cooldown) = acc2" "acc2" "$("$ACCT" next)"
"$ACCT" use acc3 >/dev/null; eq "next từ acc3 vòng về acc1" "acc1" "$("$ACCT" next)"
"$ACCT" use acc1 >/dev/null
"$ACCT" cooldown acc2 2h >/dev/null
eq "next bỏ qua acc2 đang cooldown" "acc3" "$("$ACCT" next)"
"$ACCT" cooldown acc3 1h >/dev/null
eq "next quay lại acc1 (active, còn sẵn sàng)" "acc1" "$("$ACCT" next)"
"$ACCT" cooldown acc1 3h >/dev/null
out="$("$ACCT" next 2>&1)"; rc=$?
eq "cả pool cooldown -> exit 3" "3" "$rc"
has "báo account reset sớm nhất" "'acc3'" "$out"
out="$("$ACCT" list)"
has "list hiện cooldown" "cooldown" "$out"
AGY_NOW=$((1000000 + 3601)) ; export AGY_NOW
eq "hết cooldown acc3 sau 1h" "acc3" "$("$ACCT" next)"
AGY_NOW=1000000; export AGY_NOW

echo "== agy-run"

setup
runit; rc=$?
eq "thành công ngay: exit 0" "0" "$rc"
eq "chỉ chạy 1 lần" "1" "$(lines)"
has "dùng token acc1" "tok-acc1|" "$(cat "$FAKE_ARGS_LOG")"
has "truyền --add-dir" "--add-dir $T/work" "$(cat "$FAKE_ARGS_LOG")"
has "truyền --model gemini-3.8-flash-high" "--model gemini-3.8-flash-high" "$(cat "$FAKE_ARGS_LOG")"
has "truyền --dangerously-skip-permissions" "--dangerously-skip-permissions" "$(cat "$FAKE_ARGS_LOG")"

setup
export FAKE_QUOTA_TOKENS="tok-acc1"
start=$SECONDS
runit; rc=$?
elapsed=$((SECONDS - start))
eq "quota acc1 -> đổi acc2, exit 0" "0" "$rc"
eq "chạy 2 lần" "2" "$(lines)"
second="$(sed -n 2p "$FAKE_ARGS_LOG")"
has "lần 2 dùng token acc2" "tok-acc2|" "$second"
has "lần 2 resume đúng conversation" "--conversation conv-fake-1" "$second"
hasnt "lần 2 không gửi lại prompt gốc" "do the thing" "$second"
eq "acc1 cooldown 15199s (4h13m19s)" "$((1000000 + 15199))" "$(cd_of acc1)"
eq "active = acc2" "acc2" "$("$ACCT" active)"
[ "$elapsed" -lt 20 ] && pass "kill ngay, không chờ agy retry (${elapsed}s)" || fail "kill ngay, không chờ agy retry" "mất ${elapsed}s"
sleep 0.3
eq "không còn process fake-agy sót" "0" "$(pgrep -fc "$HERE/fake-agy" || true)"

setup
export FAKE_QUOTA_TOKENS="tok-acc1 tok-acc2"
runit; rc=$?
eq "quota 2 account liên tiếp -> exit 0" "0" "$rc"
eq "chạy 3 lần" "3" "$(lines)"
has "lần 3 dùng acc3" "tok-acc3|" "$(sed -n 3p "$FAKE_ARGS_LOG")"
has "lần 3 vẫn đúng conversation" "--conversation conv-fake-1" "$(sed -n 3p "$FAKE_ARGS_LOG")"

setup
export FAKE_QUOTA_TOKENS="tok-acc1 tok-acc2 tok-acc3"
runit; rc=$?
eq "cả pool quota -> exit 5" "5" "$rc"
has "báo cả pool hết quota" "cả pool hết quota" "$(cat "$T/run.err")"
out="$("$ACCT" next 2>&1)"; eq "state: cả 3 đều cooldown" "3" "$?"

setup
export FAKE_QUOTA_TOKENS="tok-acc1 tok-acc2 tok-acc3" AGY_RUN_MAX_SWITCH=1
runit; rc=$?
eq "vượt số lần đổi tối đa -> exit 6" "6" "$rc"

setup
export FAKE_AUTH=1
runit; rc=$?
eq "lỗi auth -> exit 4" "4" "$rc"
eq "lỗi auth: không đổi account" "acc1" "$("$ACCT" active)"
eq "lỗi auth: chỉ chạy 1 lần" "1" "$(lines)"

setup
rm -f "$AGY_HOME/accounts/state.json"
runit; rc=$?
eq "chưa có account active -> exit 4" "4" "$rc"
eq "không chạy agy khi chưa có active" "0" "$(lines)"

setup
echo 'error: Individual quota reached. Resets in 1h.' >"$T/run.jsonl"
runit; rc=$?
eq "dòng 429 cũ trong log không bị tính lại" "0" "$rc"
eq "log cũ: chỉ chạy 1 lần" "1" "$(lines)"

setup
runit >/dev/null; "$RUN" --bogus 2>/dev/null; eq "tham số lạ -> exit 2" "2" "$?"

echo "== rotate (dùng agy tay)"
# tạo một dòng log kiểu agy: E<MMDD> <HH:MM:SS.uuuuuu> ... Resets in X.   ($1 = số giây trước "bây giờ", $2 = Resets in)
logline() {
  printf 'E%s.123456  1 errorreport.go:224] generating and executing: RESOURCE_EXHAUSTED (code 429): Individual quota reached. Please upgrade your subscription to increase your limits. Resets in %s.\n' \
    "$(date -d "@$((AGY_NOW - $1))" '+%m%d %H:%M:%S')" "$2"
}

setup
mkdir -p "$AGY_HOME/log"; logline 120 "3h13m51s" >"$AGY_HOME/log/cli-20261001_100000.log"
out="$("$ACCT" rotate 2>&1)"; rc=$?
eq "rotate: exit 0" "0" "$rc"
has "rotate: nói đọc từ log" "đọc từ log agy" "$out"
eq "rotate: acc1 cooldown = log time + Resets in" "$((1000000 - 120 + 11631))" "$(cd_of acc1)"
eq "rotate: chuyển sang acc2" "acc2" "$("$ACCT" active)"
eq "rotate: token = acc2" "tok-acc2" "$(cat "$AGY_HOME/antigravity-oauth-token")"
has "rotate: nhắc mở lại bằng agy -c" "agy -c" "$out"
hasnt "rotate: không in token" "tok-" "$out"

setup
mkdir -p "$AGY_HOME/log"; logline 120 "3h13m51s" >"$AGY_HOME/log/cli-20261001_100000.log"
"$ACCT" rotate 1h >/dev/null 2>&1
eq "rotate: thời gian nhập tay ghi đè log" "$((1000000 + 3600))" "$(cd_of acc1)"

setup
mkdir -p "$AGY_HOME/log"; logline 7200 "3h13m51s" >"$AGY_HOME/log/cli-20261001_100000.log"
out="$("$ACCT" rotate 2>&1)"
eq "rotate: dòng log cũ hơn 1 giờ bị bỏ, dùng 5h" "$((1000000 + 18000))" "$(cd_of acc1)"
has "rotate: báo dùng mặc định 5h" "mặc định 5h" "$out"

setup
mkdir -p "$AGY_HOME/log"
logline 600 "4h13m19s" >"$AGY_HOME/log/cli-20261001_100000.log"
logline 60 "43m29s" >"$AGY_HOME/log/cli-20261001_110000.log"
touch -d '2 minutes ago' "$AGY_HOME/log/cli-20261001_100000.log"
"$ACCT" rotate >/dev/null 2>&1
eq "rotate: lấy dòng mới nhất trong các log" "$((1000000 - 60 + 2609))" "$(cd_of acc1)"

setup
"$ACCT" rotate >/dev/null 2>&1
eq "rotate: không có thư mục log -> mặc định 5h" "$((1000000 + 18000))" "$(cd_of acc1)"

setup
mkdir -p "$AGY_HOME/log"; : >"$AGY_HOME/log/cli-20261001_100000.log"
"$ACCT" cooldown acc2 3h >/dev/null; "$ACCT" cooldown acc3 2h >/dev/null
out="$("$ACCT" rotate 1h 2>&1)"; rc=$?
eq "rotate: cả pool cooldown -> exit 3" "3" "$rc"
eq "rotate: cả pool cooldown vẫn ghi cooldown cho account hiện tại" "$((1000000 + 3600))" "$(cd_of acc1)"
eq "rotate: cả pool cooldown không đổi token" "tok-acc1" "$(cat "$AGY_HOME/antigravity-oauth-token")"
"$ACCT" rotate xyz >/dev/null 2>&1; eq "rotate: thời gian sai -> lỗi" "1" "$?"

setup
rm -f "$AGY_HOME/accounts/state.json"
"$ACCT" rotate >/dev/null 2>&1; eq "rotate: chưa có account active -> lỗi" "1" "$?"

echo "== quota"
setup
export FAKE_ARGS_LOG="$T/args.log"
out="$("$ACCT" quota 2>&1)"; rc=$?
eq "quota: exit 0" "0" "$rc"
has "quota: in dòng Gemini 5 giờ" "Five Hour Limit Remaining" "$out"
has "quota: header là account active" "acc1 (active):" "$out"
eq "quota: lưu g5 (tok-acc1 -> 60)" "60" "$(jq -r '.quota.acc1.g5' "$AGY_HOME/accounts/state.json")"
eq "quota: lưu gw (tok-acc1 -> 50)" "50" "$(jq -r '.quota.acc1.gw' "$AGY_HOME/accounts/state.json")"
eq "quota: reset 5h = now+3600" "$((1000000 + 3600))" "$(jq -r '.quota.acc1.g5r' "$AGY_HOME/accounts/state.json")"
hasnt "quota: không in token" "tok-" "$out"
eq "quota: không tạo cooldown khi còn quota" "0" "$(cd_of acc1)"
out="$("$ACCT" list)"
has "list: hiện quota snapshot 5h" "quota Gemini: 5h 60%" "$out"
has "list: hiện quota snapshot tuần" "tuần 50%" "$out"
AGY_NOW=$((1000000 + 4000)); export AGY_NOW
out="$("$ACCT" list)"
has "list: 5h đã qua giờ reset -> 'đã reset'" "5h đã reset" "$out"
hasnt "list: tuần chưa reset vẫn hiện %" "tuần đã reset" "$out"
AGY_NOW=1000000; export AGY_NOW

setup
out="$("$ACCT" quota --all 2>&1)"; rc=$?
eq "quota --all: exit 0" "0" "$rc"
for a in acc1 acc2 acc3; do has "quota --all: có $a" "$a" "$out"; done
eq "quota --all: acc2 g5=70" "70" "$(jq -r '.quota.acc2.g5' "$AGY_HOME/accounts/state.json")"
eq "quota --all: acc3 g5=80" "80" "$(jq -r '.quota.acc3.g5' "$AGY_HOME/accounts/state.json")"
eq "quota --all: trả active về acc1" "acc1" "$("$ACCT" active)"
eq "quota --all: token trả về acc1" "tok-acc1" "$(cat "$AGY_HOME/antigravity-oauth-token")"
eq "quota --all: slot acc2 còn nguyên" "tok-acc2" "$(cat "$AGY_HOME/accounts/acc2.token")"

setup
out="$("$ACCT" quota acc3 2>&1)"
has "quota <tên>: header acc3" "acc3:" "$out"
eq "quota <tên>: trả active về acc1" "acc1" "$("$ACCT" active)"
eq "quota <tên>: token trả về acc1" "tok-acc1" "$(cat "$AGY_HOME/antigravity-oauth-token")"
"$ACCT" quota nope >/dev/null 2>&1; eq "quota slot không tồn tại -> lỗi" "1" "$?"

setup
export FAKE_ZERO_TOKENS="tok-acc2"
out="$("$ACCT" quota --all 2>&1)"
has "quota: báo hết quota Gemini" "hết quota Gemini" "$out"
eq "quota 0%: cooldown acc2 = giờ reset 5h" "$((1000000 + 3600))" "$(cd_of acc2)"
eq "quota 0%: acc1 không bị cooldown" "0" "$(cd_of acc1)"
eq "next bỏ qua acc2 (0% quota)" "acc3" "$("$ACCT" next)"

setup
export FAKE_DEAD_TOKENS="tok-acc2"
out="$("$ACCT" quota --all 2>&1)"; rc=$?
eq "quota --all: một account chết -> exit 1" "1" "$rc"
has "quota: báo không lấy được cho account chết" "không lấy được quota" "$out"
eq "quota: account còn lại vẫn đo (acc3 g5=80)" "80" "$(jq -r '.quota.acc3.g5' "$AGY_HOME/accounts/state.json")"
eq "quota: account chết không có snapshot" "null" "$(jq -r '.quota.acc2.g5' "$AGY_HOME/accounts/state.json")"
eq "quota: vẫn trả active về acc1" "acc1" "$("$ACCT" active)"
eq "quota: token trả về acc1" "tok-acc1" "$(cat "$AGY_HOME/antigravity-oauth-token")"

setup
AGY_BIN=/nonexistent/agy "$ACCT" quota >/dev/null 2>&1; eq "quota: không có agy -> lỗi" "1" "$?"
unset FAKE_ZERO_TOKENS FAKE_DEAD_TOKENS

setup
rm -f "$AGY_HOME/accounts/state.json"
"$ACCT" quota >/dev/null 2>&1; eq "quota: chưa có account active -> lỗi" "1" "$?"

echo "== múi giờ UTC+7"
setup
# AGY_NOW=1000000 = 1970-01-12 13:46:40 UTC; +1h = 14:46 UTC = 21:46 theo UTC+7 = 09:46 PM
out="$(TZ=UTC "$ACCT" cooldown acc1 1h)"
has "giờ hiển thị luôn UTC+7 dù TZ môi trường là UTC" "12/01/1970 09:46 PM" "$out"
out="$(TZ=America/New_York "$ACCT" list)"
has "list cũng theo UTC+7 dù TZ môi trường khác" "12/01/1970 09:46 PM" "$out"
out="$(TZ=UTC AGY_TZ=UTC "$ACCT" cooldown acc1 1h)"
has "AGY_TZ đổi được múi giờ hiển thị" "12/01/1970 02:46 PM" "$out"
out="$("$ACCT" cooldown acc1 10h)"
has "định dạng dd/mm/yyyy hh:mm AM (buổi sáng, sang ngày hôm sau)" "13/01/1970 06:46 AM" "$out"
out="$(LC_ALL=C LC_TIME=de_DE.UTF-8 "$ACCT" cooldown acc1 1h)"
has "AM/PM không phụ thuộc locale của máy" "09:46 PM" "$out"
"$ACCT" quota >/dev/null 2>&1
out="$("$ACCT" list)"
has "list: giờ đo quota (jq) cũng dd/mm/yyyy hh:mm AM/PM" "đo lúc 12/01/1970 08:46 PM" "$out"
has "list: giờ reset (5h = đo + 1 giờ) theo định dạng mới" "(reset 12/01/1970 09:46 PM)" "$out"

echo "== an toàn"
eq "token thật không bị đụng (mtime)" "$REAL_MTIME_BEFORE" "$(stat -c %Y "$REAL_TOKEN" 2>/dev/null || echo none)"

echo
echo "kết quả: $PASS pass, $FAIL fail"
[ "$FAIL" -eq 0 ]
