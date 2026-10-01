# agyr

Xoay vòng nhiều account Google cho `agy` (Antigravity CLI) khi một account hết quota (429), và xem quota thật của từng account.

Chỉ làm việc với binary `agy` chính thức: copy file `~/.gemini/antigravity-cli/antigravity-oauth-token` qua lại giữa các slot. Không proxy, không đọc hay in nội dung token.

> Rủi ro: Google từng khóa account vì dùng tool/proxy bên thứ 3 để lấy quota Antigravity. Cách này giống hệt việc login tay đổi account, nhưng không có gì đảm bảo 0 rủi ro. Dùng ở mức vừa phải.

Gồm hai lệnh trong `bin/`:

- `agyr`: quản lý slot, xem quota, đổi account. Đây là lệnh bạn tự gõ.
- `agy-run`: chạy một task agy và tự đổi account khi hết quota. Chủ yếu do Claude gọi qua skill `agy`, xem phần [agy-run](#agy-run-dành-cho-claude).

## Cài

```bash
ln -sf ~/tools/agy-acct/bin/agyr ~/.local/bin/agyr
ln -sf ~/tools/agy-acct/bin/agy-run  ~/.local/bin/agy-run
```

Cần `bash` và `jq`.

## Setup một lần

Tên slot do bạn tự đặt: chỉ gồm chữ cái không dấu, số, `-` và `_` (ví dụ `acct2`, `work`). Không dùng dấu cách, dấu chấm, `@` hay `/`.

Với từng account, đăng nhập bằng `agy` rồi lưu slot. Làm tay vì cần đăng nhập Google. **Đừng dùng lệnh logout của agy** (chưa rõ nó có thu hồi token ở phía Google không); thay vào đó xóa file token cục bộ, slot đã giữ bản copy:

```bash
agyr save acct1                 # account đang đăng nhập
rm ~/.gemini/antigravity-cli/antigravity-oauth-token
agy                                 # đăng nhập account 2, rồi thoát
agyr save acct2
rm ~/.gemini/antigravity-cli/antigravity-oauth-token
agy                                 # đăng nhập account 3, rồi thoát
agyr save acct3
```

Kiểm tra từng slot dùng được: `agyr use <tên>` rồi `agy models` (ra danh sách model là slot còn sống).

Về sau, mỗi lần bạn login tay một account, chạy lại `agyr save <tên>`; nếu quên, lần `use` kế tiếp sẽ ghi token của account khác đè vào slot cũ.

## Lệnh

```bash
agyr list                 # slot, account đang active (*), cooldown, quota lần đo gần nhất
agyr use <tên>            # đổi account
agyr quota                # quota thật của account đang active (agy -p /quota, 0 token)
agyr quota --all          # quota của cả pool; quota <tên> cho một account
agyr rotate               # dùng agy tay mà hết quota: cooldown account hiện tại + đổi sang account kế tiếp
agyr cooldown <tên> 4h13m # đánh dấu hết quota thủ công (nhận cả "… Resets in 4h13m27s")
agyr clear <tên>          # bỏ cooldown
agyr next                 # account sẵn sàng kế tiếp (exit 3 nếu cả pool cooldown)
agyr active               # tên account đang active
```

## Khi đang dùng agy tay mà hết quota

Thoát agy (process đang chạy giữ token cũ), rồi:

```bash
agyr rotate    # cooldown account hiện tại (đọc "Resets in …" từ log agy) + đổi sang account kế tiếp
agy -c             # mở lại, tiếp tục conversation gần nhất
```

`rotate [thời gian]` nhận thời gian nhập tay (ví dụ `rotate 4h13m`) nếu log không có lỗi quota trong 1 giờ gần đây (khi đó mặc định 5h). Cả pool đang cooldown thì exit 3 và không đổi token.

## Xem quota

`agyr quota` chạy `agy -p /quota` (không gọi model, tốn 0 token) và in quota 5 giờ / quota tuần của Gemini và Claude/GPT. `quota --all` đi qua từng account: đổi token sang account đó, đo, rồi trả token về account ban đầu (kể cả khi bị Ctrl+C). Đừng chạy `quota --all` lúc có `agy-run` đang chạy, vì nó đổi file token tạm thời.

Kết quả mỗi lần đo được lưu lại, nên `agyr list` hiện thêm dòng `quota Gemini: 5h … · tuần … · đo lúc …` (số liệu cũ, nhìn giờ đo; phần đã qua giờ reset hiện "đã reset"). Account về 0% thì tự đặt cooldown tới đúng giờ reset, nên `next`, `rotate` và `agy-run` bỏ qua nó.

## Múi giờ

Mọi giờ hiển thị đều theo **UTC+7** và có dạng `dd/mm/yyyy hh:mm AM|PM` (ví dụ `01/10/2026 07:14 PM`), không phụ thuộc múi giờ hay ngôn ngữ của máy. Đổi bằng biến môi trường `AGY_TZ` (ví dụ `AGY_TZ=UTC`; theo quy ước POSIX thì `UTC-7` nghĩa là UTC+7, và là giá trị mặc định). Giờ trong log của agy cũng được đọc theo múi giờ này.

## agy-run (dành cho Claude)

`agy-run` không phải lệnh để gõ tay hằng ngày: Claude gọi nó thay cho `agy -p` khi giao việc cho agy (xem skill `agy`, mục "Account pool"). Nó chạy agy với `--dangerously-skip-permissions --output-format stream-json`; gặp `Individual quota reached` thì kill ngay (không chờ agy retry), ghi cooldown theo `Resets in …`, chuyển sang account kế tiếp và resume đúng conversation bằng `--conversation <id>`.

Exit code: `0` xong, `1` agy lỗi khác, `2` sai tham số, `4` lỗi đăng nhập hoặc chưa có account active, `5` cả pool hết quota, `6` đổi account quá `AGY_RUN_MAX_SWITCH` (mặc định 6) lần.

## Biến môi trường

| Biến | Mặc định | Dùng cho |
|---|---|---|
| `AGY_HOME` | `~/.gemini/antigravity-cli` | thư mục dữ liệu của agy (test trỏ vào thư mục tạm) |
| `AGY_BIN` | `agy` | binary agy |
| `AGY_TZ` | `UTC-7` | múi giờ hiển thị |
| `AGY_NOW` | giờ hiện tại | chỉ để test: giả lập "bây giờ" |
| `AGY_RUN_MAX_SWITCH` | `6` | số lần đổi account tối đa của `agy-run` |
| `AGY_RUN_POLL` | `1` | giây giữa hai lần `agy-run` soi log |

## Test

```bash
bash test/run.sh
```

124 kiểm tra, dùng token giả và `test/fake-agy` (mô phỏng init, 429, `/quota` đúng định dạng thật); không đụng token thật.

## Giới hạn đã biết

- Chưa kiểm chứng với nhiều account thật: giả định "chỉ cần đổi file `antigravity-oauth-token` là đổi được account" mới được test bằng agy giả. Sau khi setup, hãy thử `use` + `agy models` cho từng slot. Refresh token có thể bị thu hồi (đổi mật khẩu Google, Google tự thu hồi); slot nào chết thì login lại và `save` lại.
- Process agy đang chạy giữ token cũ; `agy-run` luôn kill rồi resume, không đổi token "nóng".
- `agy-run` nhận diện lỗi bằng text trong log. Nếu prompt của task chứa nguyên văn `Individual quota reached` mà agy echo lại ra log, có thể báo nhầm.
- Chưa xử lý 503 "No capacity" (chuyển sang `gemini-3.7-flash-high` vẫn làm tay theo skill agy).
- Chạy nhiều `agy-run` song song dùng chung một pool theo kiểu best-effort.
- State (cooldown, active, snapshot quota) nằm ở `~/.gemini/antigravity-cli/accounts/state.json`; token backup trước mỗi lần `use` ở `accounts/.last-token.bak`.
