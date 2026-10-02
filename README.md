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

## Quan trọng: agy từ bản 1.2.14 dùng kho mật khẩu của hệ điều hành

Từ bản **1.2.14** (tự cập nhật ngày 02/10/2026), `agy` lưu đăng nhập trong **kho mật khẩu của GNOME** (libsecret, qua D-Bus; mục `Password for 'antigravity' on 'gemini'`) và **bỏ qua file token** miễn là kho đó còn truy cập được. Hậu quả: `agyr use` đổi file token nhưng `agy` chạy bình thường vẫn dùng account nằm trong kho (banner không đổi), và mọi lần đo quota đều ra cùng một account.

Cách `agyr` xử lý: mọi `agy` do `agyr` hoặc `agy-run` khởi động đều được chạy với địa chỉ D-Bus không tồn tại, nên agy không với tới kho mật khẩu và quay về dùng file token. `agyr list` và `agy-run` tự làm vậy. Khi bạn tự mở agy, hãy dùng **`agyr run`** thay cho `agy` (nhận mọi tham số của agy, ví dụ `agyr run -c`); có thể đặt alias `alias agy='agyr run'` trong `~/.zshrc` (alias không ảnh hưởng các script của `agyr`). `agy` chạy trần vẫn dùng account trong kho mật khẩu, bỏ qua `agyr use`.

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
agyr list                     # đo quota thật của mọi account, in bảng; * = account đang chọn
agyr list -c                  # chỉ in số liệu đã lưu, không gọi agy (nhanh)
agyr use <tên>                # đổi account
agyr rotate                   # dùng agy tay mà hết quota: cooldown account hiện tại + đổi sang account kế tiếp
agyr cooldown <tên> 4h13m     # đánh dấu hết quota thủ công (nhận cả "… Resets in 4h13m27s")
agyr clear <tên>              # bỏ cooldown
agyr next                     # account sẵn sàng kế tiếp (exit 3 nếu cả pool cooldown)
agyr active                   # tên account đang dùng
agyr save <tên>               # lưu token hiện tại thành slot
agyr run [tham số agy]        # mở agy bằng account đang chọn (thay cho `agy`, xem mục trên)
agyr help [lệnh]              # tổng quan, hoặc chi tiết một lệnh (agyr <lệnh> --help cũng được)
```

Help của chương trình viết bằng tiếng Anh: `agyr help` có danh sách lệnh, ví dụ, exit code, biến môi trường và file dữ liệu; `agyr help list` (hoặc `agyr list --help`) cho chi tiết từng lệnh; `agy-run --help` cho lệnh chạy task.

## Khi đang dùng agy tay mà hết quota

Thoát agy (process đang chạy giữ token cũ), rồi:

```bash
agyr rotate    # cooldown account hiện tại (đọc "Resets in …" từ log agy) + đổi sang account kế tiếp
agyr run -c        # mở lại bằng account mới, tiếp tục conversation gần nhất
```

`rotate [thời gian]` nhận thời gian nhập tay (ví dụ `rotate 4h13m`) nếu log không có lỗi quota trong 1 giờ gần đây (khi đó mặc định 5h). Cả pool đang cooldown thì exit 3 và không đổi token.

## agyr list: xem quota

```
  ACCOUNT        GEMINI 5H                   GEMINI WEEK                 STATUS
  acct3          100%  01/10/2026 07:14 PM   100%  08/10/2026 02:02 PM   ready
  acct2            1%  01/10/2026 03:03 PM    75%  07/10/2026 11:46 AM   low
  acct1            1%  01/10/2026 04:02 PM    67%  07/10/2026 09:24 AM   low
* work            46%  01/10/2026 05:53 PM    74%  07/10/2026 02:02 PM   ready
Measured at 01/10/2026 02:58 PM   (* = selected account)
```

`agyr list` chạy `agy -p /quota` (không gọi model, tốn 0 token) cho **từng account song song** (mất khoảng 10–20 giây) và lưu kết quả. Mỗi lần đo chạy trong một thư mục HOME tạm chứa bản sao token, nên **không đụng file token thật**: không ảnh hưởng `agy` đang mở hay `agy-run` đang chạy. Mỗi `agy` đo chạy tách khỏi terminal (`setsid`, stdin rỗng): nếu không, nhiều `agy` chạy song song cùng đổi và khôi phục chế độ terminal của bạn và để lại terminal bị vỡ (dòng thụt lệch, mất echo). Cột Gemini là nhóm model mà `agy-run` dùng; quota Claude/GPT không hiển thị (xem trong `agy` bằng `/quota`).

- **Dấu `*`** đánh dấu account mà file token thật đang thuộc về (so `refresh_token` với từng slot), không phải tên đã ghi trong state. Nhờ đó nếu bạn tự login sang account khác bằng `agy`, bảng vẫn đánh dấu đúng, và `use` không ghi đè nhầm slot. Nếu token đang dùng không khớp slot nào (vừa login account chưa lưu) thì bảng cảnh báo và không đánh dấu `*`; chạy `agyr save <tên>`.
- **Màu** (chỉ khi in ra terminal): phần trăm còn lại **xanh** khi trên 40%, **vàng** từ 11% đến 40%, **đỏ** từ 10% trở xuống. Cột trạng thái: `ready` xanh; `not measured` và `stale` vàng; `low`, `cooldown` và `measure failed` đỏ. Tắt màu bằng `NO_COLOR=1` hoặc `AGYR_COLOR=never`; ép bật khi chuyển hướng ra file/pipe bằng `AGYR_COLOR=always`.
- **Đo thấy 0%** thì tự đặt cooldown tới đúng giờ reset; **đo thấy còn quota** thì xóa cooldown cũ (ví dụ cooldown mặc định 5 giờ). Nhờ vậy `next`, `rotate` và `agy-run` luôn dựa trên số liệu thật.
- **Trạng thái** (chữ tiếng Anh trong bảng): `ready`; `low` (còn ≤10%); `cooldown, 15m left`; `not measured`; `stale, past reset time` (chỉ với `-c`: đã qua giờ reset, cần đo lại); `measure failed` (token hết hạn hoặc agy lỗi; khi đó exit code là 1).

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
| `AGYR_COLOR` | `auto` | `auto` (có màu khi in ra terminal và không đặt `NO_COLOR`), `always`, `never` |
| `AGY_RUN_MAX_SWITCH` | `6` | số lần đổi account tối đa của `agy-run` |
| `AGY_RUN_POLL` | `1` | giây giữa hai lần `agy-run` soi log |

## Test

```bash
bash test/run.sh
```

263 kiểm tra, dùng token giả và `test/fake-agy` (mô phỏng init, 429, `/quota` đúng định dạng thật); không đụng token thật.

## Giới hạn đã biết

- Chưa kiểm chứng với nhiều account thật: giả định "chỉ cần đổi file `antigravity-oauth-token` là đổi được account" mới được test bằng agy giả. Sau khi setup, hãy thử `use` + `agy models` cho từng slot. Refresh token có thể bị thu hồi (đổi mật khẩu Google, Google tự thu hồi); slot nào chết thì login lại và `save` lại.
- Process agy đang chạy giữ token cũ; `agy-run` luôn kill rồi resume, không đổi token "nóng".
- `agy-run` chỉ tính là hết quota khi log có dòng chữ thường `error: Individual quota reached …` hoặc `AGY_ERROR: … RESOURCE_EXHAUSTED (code 429)`. Khi chạy tiếp một conversation, agy có thể lặp lại lỗi quota cũ ngay trong dòng JSON `result` cuối dù lần chạy đó làm việc bình thường (thấy ngày 01/10: 4 lần "429" giả trong một session, giá trị `Resets in` không đổi); dòng JSON bị bỏ qua nên không còn đổi account oan. Khi đó `agy-run` thoát với exit 1 và ghi rõ lý do, đọc log để biết task đã xong chưa.
- Chưa xử lý 503 "No capacity" (chuyển sang `gemini-3.7-flash-high` vẫn làm tay theo skill agy).
- Chạy nhiều `agy-run` song song dùng chung một pool theo kiểu best-effort: mỗi lần một lệnh đổi account thì file token thật đổi theo, nên dấu `*` trong `agyr list` nhảy qua lại trong lúc chúng đang chạy. Các process đang chạy vẫn giữ token riêng của mình.
- `agyr list` đo bằng bản sao token trong HOME tạm. Token đã bị thu hồi thì báo `measure failed` thay vì đoán.
- State (cooldown, active, snapshot quota) nằm ở `~/.gemini/antigravity-cli/accounts/state.json`; token backup trước mỗi lần `use` ở `accounts/.last-token.bak`.
