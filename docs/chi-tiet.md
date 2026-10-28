# agyr: chi tiết

Trang chính và cách cài nhanh: [README](../README.md).

Xoay vòng nhiều account Google cho `agy` (Antigravity CLI) khi một account hết quota (429), và xem quota thật của từng account.

Chỉ làm việc với binary `agy` chính thức: copy file `~/.gemini/antigravity-cli/antigravity-oauth-token` qua lại giữa các slot. Không proxy, không đọc hay in nội dung token.

> Rủi ro: Google từng khóa account vì dùng tool/proxy bên thứ 3 để lấy quota Antigravity. Cách này giống hệt việc login tay đổi account, nhưng không có gì đảm bảo 0 rủi ro. Dùng ở mức vừa phải.

Gồm ba lệnh trong `bin/`:

- `agyr`: quản lý slot, xem quota, đổi account. Đây là lệnh bạn tự gõ.
- `agy-run`: chạy một task agy và tự đổi account khi hết quota. Chủ yếu do Claude gọi qua skill `agy`, xem phần [agy-run](#agy-run-dành-cho-claude).
- `agy-task`: chạy trọn gói một task IMPLEMENT trong git worktree riêng, kiểm tra scope và dọn dẹp. Xem phần [agy-task](#agy-task-dành-cho-claude).

## Cài

Nếu bạn là agent AI được nhờ cài repo này lên máy, đọc [agent.mcp.md](../agent.mcp.md): các bước cài và những việc agent không được làm (login, save, đọc file token).

Cần `bash`, `git` và `jq`. Trên Linux thêm `timeout` (coreutils) và `setsid` (util-linux), không bắt buộc. Đã thử trên Linux với agy 1.4.7.

```bash
bash linux/install.sh        # tạo symlink agyr, agy-run, agy-task trong ~/.local/bin
```

Trên Windows dùng `bash windows/install.sh` (xem mục bên dưới). Script chỉ tạo symlink hoặc wrapper, không login và không đọc file token. Sau khi cài, `agyr help` phải chạy được và `bash test/run.sh` phải báo `794 pass, 0 fail` (trên Windows hiện chưa đạt, xem [Tình trạng test trên Windows](#tình-trạng-test-trên-windows)). Việc này không cần login. Skill `agy` là bản sao riêng, xem mục [Skill `agy` (bản sao)](#skill-agy-bản-sao).

### Cấu trúc repo

- `bin/`: ba lệnh `agyr`, `agy-run`, `agy-task`. Đây là điểm vào, không chứa code riêng của từng nền tảng.
- `linux/`: `platform.sh` (cách gọi agy trên Linux: chặn keyring, setsid) và `install.sh`.
- `windows/`: `platform.sh` (Git Bash: đường dẫn, taskkill, chống chuyển đổi đối số), `cred.sh` và `cred.ps1` (đọc/ghi mục Credential Manager), `inspect-cred.ps1` (chỉ in metadata) và `install.sh`.
- `skill/agy/`, `templates/`, `test/`: bản sao skill, khối HARD RULES, bộ test.

## Windows (Git Bash)

Chạy trong **Git Bash** (đi kèm Git for Windows). Cần:

- `jq` (ví dụ `winget install jqlang.jq`);
- PowerShell (`powershell.exe` trên PATH), `cygpath` và `taskkill` (cũng đi kèm Git for Windows);
- agy chính thức, `agy.exe`, thường nằm trong `%LOCALAPPDATA%\agy\bin`. Đã thử với agy 1.4.9 trên Windows 11.

### Cài lệnh

Chạy trong thư mục clone của repo:

```bash
bash windows/install.sh
```

Git Bash không tạo symlink dùng được, nên script ghi ba wrapper nhỏ, mỗi cái gọi `bin/<tên>` trong repo (`git pull` là cập nhật). Đường dẫn repo được ghi cứng vào wrapper, nên nếu chuyển thư mục repo thì chạy lại script.

Script lưu ba lệnh vào `~/.local/bin` (tức `C:\Users\<bạn>\.local\bin`). Thư mục này phải có trong PATH của Git Bash. Script không tự sửa `~/.bashrc`; nếu thiếu, thêm dòng này:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Nếu `~/.local/bin/<tên>` đã có mà không phải wrapper của clone này (ví dụ đã cài từ một clone khác), script in `refusing to replace ...` và không ghi gì. Khi đó sao lưu các file đó, xóa, rồi chạy lại script:

```bash
mkdir -p ~/tools/wrapper-backup
for n in agyr agy-run agy-task; do [ -e ~/.local/bin/$n ] && cp -p ~/.local/bin/$n ~/tools/wrapper-backup/ && rm ~/.local/bin/$n; done
bash windows/install.sh
```

Kiểm tra:

```bash
agyr help | head -1
agy-run --help | head -1
agy-task --help | head -1
agyr backend          # phải in: wincred
```

### Đăng nhập và kiểm tra

Trên Windows `agy` lưu đăng nhập trong **một mục Windows Credential Manager** (target `gemini:antigravity`, loại generic, nội dung là JSON giống file token trên Linux). Không có file token, và không có cách chuyển hướng cho từng tiến trình, nên `agyr` tự chọn backend `wincred` (xem `agyr backend`) và đổi account bằng cách **ghi đè chính mục đó**:

- `agyr save <tên>`: đọc mục đó vào slot `accounts/<tên>.token` (cùng định dạng slot như bản Linux).
- `agyr use <tên>`: backup login đang dùng vào `accounts/.last-token.bak`, rồi ghi slot đè lên mục đó. Sau đó `agy` trần và `agyr` hoạt động giống hệt nhau (không cần mẹo D-Bus như trên Linux).
- `agyr list`: **đo lần lượt**, không song song (mỗi account một lần: ghi login vào, chạy `agy -p /quota`, lấy lại token mà agy đã refresh). Xong thì đặt lại login đang dùng, kể cả khi bị Ctrl+C hoặc lỗi giữa chừng. Trong lúc đo đừng mở agy hay đăng nhập tay.
- `agyr forget`: xóa login hiện tại **chỉ ở máy này** (không thu hồi gì phía Google), để `agy` hỏi đăng nhập account khác. Thay cho `rm ~/.gemini/antigravity-cli/antigravity-oauth-token` của Linux. Từ chối nếu login chưa nằm trong slot nào (trừ khi `--force`).
- Mọi thao tác ghi vào Credential Manager đều dùng khóa `accounts/.swap.lock`, để `agy-run` và `agyr list` chạy cùng lúc không giẫm lên nhau. Từ 09/10/2026 khóa này cũng bảo vệ backend file trên Linux (xem mục "Chạy song song" bên dưới); khóa là một file tạo độc quyền (`set -o noclobber`), **không dùng `mkdir`**, vì `mkdir` của uutils coreutils (mặc định trên Ubuntu mới) không nguyên tử.

Đăng nhập từng account, lặp lại cho mỗi account:

```bash
agyr                      # mở agy bằng slot đang chọn; đăng nhập account 1, rồi thoát agy
agyr save acc1            # lưu login vừa đăng nhập thành slot acc1
agyr forget               # xóa login cục bộ, để đăng nhập account tiếp theo
agyr                      # đăng nhập account 2, rồi thoát agy
agyr save acc2
agyr forget
agyr                      # đăng nhập account 3...
agyr save acc3
agyr use acc1             # chọn account dùng hằng ngày
agyr list                 # kiểm tra từng slot: mỗi slot phải có số quota riêng
```

Slot là file thường, được bảo vệ bằng quyền của thư mục profile Windows (không có `chmod 600` trên NTFS). Các file riêng của Windows nằm trong `windows/`: `cred.sh` + `cred.ps1` (đọc/ghi/xóa mục Credential Manager, không bao giờ in nội dung) và `inspect-cred.ps1` (chỉ in metadata của mục, không in giá trị, để chẩn đoán). Đổi target bằng `AGY_CRED_TARGET`, ép backend bằng `AGYR_BACKEND=file|wincred`.

### Skill `agy` cho Claude Code và Antigravity (toàn cục)

- **Claude Code:** chép skill vào `~/.claude/skills/agy` (tức `C:\Users\<bạn>\.claude\skills\agy`):

```bash
[ -e ~/.claude/skills/agy ] && mv ~/.claude/skills/agy ~/.claude/agy-skill-backup   # nếu tên này đã có, chọn tên khác
mkdir -p ~/.claude/skills && cp -r skill/agy ~/.claude/skills/agy
```

- **Antigravity (AGY CLI / IDE):** chép skill vào `~/.gemini/config/skills/agy` (tức `C:\Users\<bạn>\.gemini\config\skills\agy`):

```bash
[ -e ~/.gemini/config/skills/agy ] && mv ~/.gemini/config/skills/agy ~/.gemini/config/skills/agy-backup   # nếu tên này đã có, chọn tên khác
mkdir -p ~/.gemini/config/skills && cp -r skill/agy ~/.gemini/config/skills/agy
```

### Tình trạng test trên Windows

`bash test/run.sh` trên Windows **chưa đạt**. Lần chạy gần nhất ghi 207 kiểm tra OK và 48 FAIL, chủ yếu ở mục `agy-run`; sau đó chạy tới mục `concurrency` và không kết thúc được trong hơn 10 phút. Nguyên nhân: `test/run.sh` đặt `FAKE_KEYRING=1` cho mọi hệ điều hành, nhưng giả lập keyring đó chỉ khớp với Linux (ở đó `linux/platform.sh` đưa agy về file token qua D-Bus). Trên bản sao có `FAKE_KEYRING=0`, mục `agy-run` đi qua hết. Repo chưa sửa dòng này. Lệnh cài đặt và `agyr help` đã chạy được trên Windows.

## Quan trọng (Linux): agy từ bản 1.2.14 dùng kho mật khẩu của hệ điều hành

Từ bản **1.2.14** (tự cập nhật ngày 02/10/2026), `agy` lưu đăng nhập trong **kho mật khẩu của GNOME** (libsecret, qua D-Bus; mục `Password for 'antigravity' on 'gemini'`) và **bỏ qua file token** miễn là kho đó còn truy cập được. Hậu quả: `agyr use` đổi file token nhưng `agy` chạy bình thường vẫn dùng account nằm trong kho (banner không đổi), và mọi lần đo quota đều ra cùng một account.

Cách `agyr` xử lý: mọi `agy` do `agyr` hoặc `agy-run` khởi động đều được chạy với địa chỉ D-Bus không tồn tại, nên agy không với tới kho mật khẩu và quay về dùng file token. `agyr list` và `agy-run` tự làm vậy. Khi bạn tự mở agy, hãy gõ **`agyr`** thay cho `agy`: `agyr` trần mở agy, `agyr -c` tiếp tục conversation gần nhất, và mọi cờ của agy đều dùng được (ví dụ `agyr -p "..."`). Tham số đầu tiên không bắt đầu bằng `-` được hiểu là lệnh của `agyr` (ví dụ `agyr list`); muốn truyền một từ như vậy cho agy thì viết `agyr run models`. `agyr run ...` vẫn dùng được và giống hệt. Không cần alias. `agy` chạy trần vẫn dùng account trong kho mật khẩu, bỏ qua `agyr use`.

## Setup một lần

Tên slot do bạn tự đặt: chỉ gồm chữ cái không dấu, số, `-` và `_` (ví dụ `acc2`, `work`). Không dùng dấu cách, dấu chấm, `@` hay `/`.

Với từng account, đăng nhập bằng `agyr` rồi lưu slot. Làm tay vì cần đăng nhập Google. **Đừng dùng lệnh logout của agy** (chưa rõ nó có thu hồi token ở phía Google không); thay vào đó dùng `agyr forget` (xóa file token cục bộ, tương đương `rm ~/.gemini/antigravity-cli/antigravity-oauth-token`, slot đã giữ bản copy):

```bash
agyr save acc1      # account đang đăng nhập
agyr forget                     # bỏ login hiện tại
agyr                            # đăng nhập account 2, rồi thoát
agyr save acc2
agyr forget
agyr                            # đăng nhập account 3, rồi thoát
agyr save acc3
```

Kiểm tra: `agyr list` phải hiện số quota riêng cho từng slot (slot hỏng báo `measure failed`).

`agyr forget` từ chối (exit 1, không xóa gì) khi login hiện tại chưa được lưu thành slot, để bạn không mất nó; `agyr save <tên>` trước, hoặc `agyr forget -f` nếu muốn bỏ luôn (bản sao vẫn nằm trong `accounts/.last-token.bak` đến lần `use`/`forget` kế tiếp). Nó chỉ xóa file token trên máy: không đăng xuất ở phía Google, và `agy` chạy trần vẫn dùng login trong kho mật khẩu.

Sau mỗi lần login tay một account, chạy `agyr save <tên>`. Nếu quên, `agyr list` cảnh báo token không khớp slot nào, và `agyr use` không ghi đè slot nào.

## Lệnh

```bash
agyr list                     # đo quota thật của mọi account, in bảng; * = account đang chọn
agyr list -c                  # chỉ in số liệu đã lưu, không gọi agy (nhanh)
agyr use <tên>                # đổi account
agyr rotate                   # dùng agy tay mà hết quota: cooldown account hiện tại + đổi sang account sẵn sàng có giờ reset tuần sớm nhất
agyr cooldown <tên> 4h13m     # đánh dấu hết quota thủ công (nhận cả "… Resets in 4h13m27s")
agyr clear <tên>              # bỏ cooldown
agyr next [-v]                # account sẵn sàng có giờ reset TUẦN sớm nhất (exit 3 nếu cả pool cooldown); -v nói lý do trên stderr
agyr active                   # tên account đang dùng
agyr save <tên>               # lưu token hiện tại thành slot
agyr rename <cũ> <mới>        # đổi tên slot (login, cooldown và số quota đi theo); từ chối nếu tên mới đã tồn tại
agyr test [tên...]            # gửi "Hi" cho mọi account để khởi động cửa sổ 5 giờ (TỐN quota thật, xem mục bên dưới)
agyr forget                   # bỏ login hiện tại (xóa file token) để đăng nhập account khác; từ chối nếu login chưa lưu (-f để ép)
agyr                          # mở agy bằng account đang chọn (thay cho `agy`, xem mục trên); agyr -c, agyr -p "..." cũng được
agyr run [tham số agy]        # giống hệt `agyr [tham số agy]`; dùng khi tham số đầu là một từ, ví dụ `agyr run models`
agyr help [lệnh]              # tổng quan, hoặc chi tiết một lệnh (agyr <lệnh> --help cũng được)
```

Help của chương trình viết bằng tiếng Anh: `agyr help` có danh sách lệnh, ví dụ, exit code, biến môi trường và file dữ liệu; `agyr help list` (hoặc `agyr list --help`) cho chi tiết từng lệnh; `agy-run --help` cho lệnh chạy task.

## Khi đang dùng agy tay mà hết quota

Thoát agy (process đang chạy giữ token cũ), rồi:

```bash
agyr rotate    # cooldown account hiện tại (đọc "Resets in …" từ log agy) + đổi sang account sẵn sàng có giờ reset tuần sớm nhất
agyr -c            # mở lại bằng account mới, tiếp tục conversation gần nhất
```

`rotate [thời gian]` nhận thời gian nhập tay (ví dụ `rotate 4h13m`) nếu log không có lỗi quota trong 1 giờ gần đây (khi đó mặc định 5h). Cả pool đang cooldown thì exit 3 và không đổi token.

## agyr list: xem quota

```
  ACCOUNT        GEMINI 5H                   GEMINI WEEK                 STATUS
  acc2        1%  01/10/2026 04:02 PM    67%  07/10/2026 09:24 AM   low
  acc9      1%  01/10/2026 03:03 PM    75%  07/10/2026 11:46 AM   low
* acc4    46%  01/10/2026 05:53 PM    74%  07/10/2026 02:02 PM   ready
  acc3     100%  01/10/2026 07:14 PM   100%  08/10/2026 02:02 PM   ready
Measured at 01/10/2026 02:58 PM   (* = selected account)
```

`agyr list` chạy `agy -p /quota` (không gọi model, tốn 0 token) cho **từng account song song** (mất khoảng 10–20 giây) và lưu kết quả. Mỗi lần đo chạy trong một thư mục HOME tạm chứa bản sao token, nên **không đụng file token thật**: không ảnh hưởng `agy` đang mở hay `agy-run` đang chạy. Mỗi `agy` đo chạy tách khỏi terminal (`setsid`, stdin rỗng): nếu không, nhiều `agy` chạy song song cùng đổi và khôi phục chế độ terminal của bạn và để lại terminal bị vỡ (dòng thụt lệch, mất echo). Cột Gemini là nhóm model mà `agy-run` dùng; quota Claude/GPT không hiển thị (xem trong `agy` bằng `/quota`).

- **Thứ tự dòng:** theo giờ reset của giới hạn tuần, sớm nhất lên đầu (nên account có tuần sắp reset luôn ở trên cùng). Account chưa đo hoặc vừa đo lỗi nằm cuối, bằng giờ thì xếp theo tên.
- **Dấu `*`** đánh dấu account mà file token thật đang thuộc về (so `refresh_token` với từng slot), không phải tên đã ghi trong state. Nhờ đó nếu bạn tự login sang account khác bằng `agy`, bảng vẫn đánh dấu đúng, và `use` không ghi đè nhầm slot. Nếu token đang dùng không khớp slot nào (vừa login account chưa lưu) thì bảng cảnh báo và không đánh dấu `*`; chạy `agyr save <tên>`.
- **Màu** (chỉ khi in ra terminal): phần trăm còn lại **xanh** khi trên 40%, **vàng** từ 11% đến 40%, **đỏ** từ 10% trở xuống. Cột trạng thái: `ready` xanh; `not measured` và `stale` vàng; `low`, `cooldown` và `measure failed` đỏ. Tắt màu bằng `NO_COLOR=1` hoặc `AGYR_COLOR=never`; ép bật khi chuyển hướng ra file/pipe bằng `AGYR_COLOR=always`.
- **Đo thấy 0%** thì tự đặt cooldown tới đúng giờ reset; **đo thấy còn quota** thì xóa cooldown cũ (ví dụ cooldown mặc định 5 giờ). Nhờ vậy `next`, `rotate` và `agy-run` luôn dựa trên số liệu thật.
- **Trạng thái** (chữ tiếng Anh trong bảng): `ready`; `low` (còn ≤10%); `weekly limit reached, 1h36m left` (đã hết giới hạn tuần: agy khi đó ghi giới hạn 5 giờ là `disabled` và không có giờ reset, nên cột 5 giờ hiện `off`; account tự được đặt cooldown tới giờ reset tuần, và đây không phải lỗi đo); `cooldown, 15m left`; `not measured`; `stale, past reset time` (chỉ với `-c`: đã qua giờ reset, cần đo lại); `measure failed` (token hết hạn hoặc agy lỗi; khi đó exit code là 1).

## agyr test: gửi "Hi" cho từng account

```
$ agyr test
Sending "Hi" to 3 account(s): one real request each, so it uses a little quota...
  ACCOUNT        HI                                             GEMINI 5H    RESETS
  acc6        ok in 11s: "Hello! How can I help yo"          16%>16%      05/10/2026 04:49 PM
  acc8        ok in 9s: "Hello! How can I help yo"           100%>99%     05/10/2026 07:31 PM (was 07:04 PM)
  acc5        skipped (cooldown, 45m left)
Measured at 05/10/2026 02:19 PM   (GEMINI 5H = before>after; RESETS = end of the account's current 5-hour window; "(was ...)" = it moved because of the Hi)
```

Mỗi account được đo quota (0 token), nhận một request `agy -p Hi` (model `gemini-3.8-flash-high`, không công cụ, thư mục tạm trống, không đọc gì của bạn), rồi đo lại. Bảng hiện câu trả lời hoặc lỗi, quota 5 giờ trước>sau, và giờ reset (kèm `(was ...)` nếu request làm giờ reset dịch chuyển).

- **Tốn quota thật:** một request mỗi account. Thử thật trên một account: quota 5 giờ vẫn 16% sau lần gọi (dưới 1%). Một lần chạy agy luôn có phần nền khoảng 20 nghìn token dù prompt chỉ một từ.
- **Mục đích** là bắt đầu đếm ngược 5 giờ của mọi account cùng lúc. **Giả thuyết "cửa sổ 5 giờ bắt đầu từ request đầu tiên" chưa được kiểm chứng**, agy không ghi tài liệu về việc này, và số đo thật chưa xác nhận: `acc8` đang 100% giữ nguyên giờ reset 07:04 PM qua hai lần đo cách nhau 15 phút (không trôi theo giờ hiện tại, cũng không rõ nó tính từ đâu). Cách kiểm chứng: chạy `agyr test <tên>` trên một account 100% chưa dùng; nếu cột RESETS có `(was ...)` thì request đã dịch giờ reset, nếu không thì "Hi" không mở cửa sổ mới.
- Không đặt tên thì bỏ qua account đang cooldown (hết quota). Đặt tên (`agyr test acc5 acc8`) thì account đó luôn được thử.
- Không đụng login đang dùng; cách đo giống `agyr list` (song song trên Linux, lần lượt trên Windows). Quá `AGYR_TEST_TIMEOUT` giây (mặc định 120) thì cắt agy và báo `agy gave no answer`.
- Exit code: 0 nếu mọi account được thử đều trả lời, 1 nếu có account không trả lời.

## Múi giờ

Mọi giờ hiển thị đều theo **UTC+7** và có dạng `dd/mm/yyyy hh:mm AM|PM` (ví dụ `01/10/2026 07:14 PM`), không phụ thuộc múi giờ hay ngôn ngữ của máy. Đổi bằng biến môi trường `AGY_TZ` (ví dụ `AGY_TZ=UTC`; theo quy ước POSIX thì `UTC-7` nghĩa là UTC+7, và là giá trị mặc định). Giờ trong log của agy cũng được đọc theo múi giờ này.

## agy-run (dành cho Claude)

`agy-run` không phải lệnh để gõ tay hằng ngày: Claude gọi nó thay cho `agy -p` khi giao việc cho agy (xem skill `agy`, mục "Account pool"). Nó chạy agy với `--dangerously-skip-permissions --output-format stream-json`; gặp `Individual quota reached` thì kill ngay (không chờ agy retry), ghi cooldown theo `Resets in …`, chuyển sang account kế tiếp (xem bên dưới) và resume đúng conversation bằng `--conversation <id>`.

Khi cần tiếp tục một cuộc hội thoại đã có sẵn ngay từ lượt đầu tiên (thay vì mở mới), truyền tham số `--conversation ID`: lượt đầu sẽ chạy `agy --conversation ID -p ...`, và nếu gặp 429 phải đổi account thì các lượt sau vẫn tiếp tục resume đúng conversation này.

**Chọn account khi đổi** (`agyr next`, cũng là cái `agyr rotate` dùng): trong các account sẵn sàng (không đang cooldown), lấy account có **giờ reset của giới hạn tuần sớm nhất**, theo số liệu `agyr list` đã lưu, tức đúng thứ tự các dòng của `agyr list`. Ý tưởng: dùng trước phần quota sắp được làm mới. Account chưa từng đo xếp cuối, bằng giờ thì theo tên; account đang dùng chỉ được chọn lại khi không còn account nào khác. Account hết giới hạn tuần đã có cooldown tới giờ reset tuần nên tự bị bỏ qua. Lưu ý: số liệu là của lần `agyr list` gần nhất (`agy-run` không đo lại), nên nếu một account đã cạn từ lúc đó thì nó vẫn được chọn, nhận 429, bị đặt cooldown rồi `agy-run` đổi tiếp (tốn một lần đổi); chạy `agyr list` thường xuyên để số liệu mới. Account chỉ còn ít (ví dụ 1% tuần) vẫn được tính là "còn quota" và có thể được chọn trước.

Exit code: `0` xong, `1` agy lỗi khác, `2` sai tham số, `4` lỗi đăng nhập hoặc chưa có account active, `5` cả pool hết quota, `6` đổi account quá `AGY_RUN_MAX_SWITCH` (mặc định 10) lần.

### Chạy song song và an toàn của slot

Nhiều `agy-run` có thể chạy cùng lúc (cả chục tiến trình), và tất cả dùng chung **một** file token đang dùng. Ngày 09/10/2026 slot `acc7` bị ghi đè bằng login của `acc6` (hai slot cùng một login, `acc7` mất login của mình): `acc7` đang ở 1% tuần nên nhiều `agy-run` cùng dính 429 và cùng gọi `agyr use` trong tích tắc. Nguyên nhân và cách khắc phục:

- **`use` đọc file token hai lần:** lần đầu để biết file đó thuộc slot nào, lần sau để ghi nó vào slot. Nếu một `agyr use` khác chen vào giữa, token của account này bị ghi vào slot của account kia. Giờ mọi quyết định và việc ghi lại đều dựa trên **một bản chụp duy nhất** của token đang dùng, nên token chỉ có thể được ghi vào slot cùng account với nó.
- **Khóa:** `accounts/.swap.lock` giờ bảo vệ mọi thao tác đổi login, ghi slot và ghi `state.json` (trước đây chỉ có trên Windows). `state.json` trước đó cũng bị mất cập nhật khi nhiều `agyr` ghi cùng lúc (12 lệnh `cooldown` song song chỉ ghi được 10–11).
- **Khóa không dùng `mkdir`:** trên máy này `mkdir` là bản uutils coreutils (mặc định trên Ubuntu mới) và **không nguyên tử**: 12 tiến trình cùng `mkdir` một đường dẫn thì có 2–7 tiến trình cùng thành công (64/300 vòng thử). Khóa là một file tạo độc quyền (`set -o noclobber`), thử 300 vòng không sai lần nào.
- **Ghi file nguyên tử:** token và slot được ghi qua file tạm rồi đổi tên, để agy đang khởi động hoặc phép đo không đọc phải file ghi dở.
- **Đo quota chỉ ghi lại slot khi vẫn là cùng account:** nếu file token trong thư mục tạm của một phép đo bỗng chứa login khác thì slot được giữ nguyên.

Hạn chế còn lại (chưa giải quyết): các `agy-run` chạy song song vẫn dùng chung một file token, nên giữa lúc `agyr use X` và lúc agy đọc token, một `agy-run` khác có thể đổi sang account Y; khi đó `agy-run` đầu tưởng đang chạy trên X. Hậu quả chỉ là cooldown có thể đặt nhầm account (`agyr list` sửa lại ở lần đo kế tiếp), không còn làm hỏng slot.

## agy-task (dành cho Claude)

`agy-task` là wrapper tất định (deterministic) để giao **trọn gói một task IMPLEMENT** cho `agy` từ đầu đến cuối mà **không dùng bất kỳ LLM nào trong wrapper**: tự tạo worktree tách biệt, chạy setup, gọi `agy-run`, kiểm tra scope và xuất file summary. Script không chạy bất kỳ bài test hay lệnh kiểm tra nào; reviewer sẽ kiểm tra và verify sau khi chạy xong. Đối với việc đọc code tìm hiểu (read-only exploration), Claude vẫn dùng `agy-run` trực tiếp trên repo chính.

### Luồng sử dụng điển hình

1. Claude chuẩn bị nội dung task vào một file (ví dụ `task.txt`).
2. Chạy `agy-task run --name x --task task.txt --scope 'paths'` ở background.
3. Đọc kết quả trong `.agy-sessions/x.summary.txt` và xem `git diff` trong worktree `.worktrees/agy-x`.
4. Nếu reviewer yêu cầu sửa đổi (vòng sửa lỗi / correction round): tạo file task mới (ví dụ `fix.txt`), chạy `agy-task run --name x --resume --task fix.txt --scope 'paths'`. Khi đó agy nhớ lại toàn bộ phiên làm việc trước đó và tiếp tục làm trên cùng worktree `.worktrees/agy-x` mà không setup lại (ngụ ý `--reuse-worktree` và `--no-setup`).
5. Nếu kết quả đạt, commit vào repo chính.
6. Dọn dẹp bằng `agy-task rm x -f`.

### File cấu hình

`agy-task` tìm file cấu hình tại `.agy-sessions/agy-task.conf` của repo chính (hoặc đường dẫn override qua biến môi trường `$AGY_TASK_CONF`). File này được `source` trực tiếp như một script bash của người dùng (trusted file), gồm các biến:

- `SETUP_CMDS`: mảng lệnh bash chạy trong worktree trước khi chạy agy (ví dụ cài dependency, build).
- `COPY_FILES`: mảng đường dẫn file/thư mục tương đối copy từ repo chính sang worktree (ví dụ các file sinh tự động như `routeTree.gen.ts`; không nên copy file chứa credential vào worktree).

File mẫu: tham khảo `templates/agy-task.conf.example`.

### Bảng các cờ của `run`

| Cờ | Ý nghĩa |
|---|---|
| `--name NAME` | Tên task (`[a-z0-9-]+`, bắt buộc). Tạo worktree tại `<repo>/.worktrees/agy-NAME`, nhánh `agy/NAME`, file phiên làm việc `<repo>/.agy-sessions/NAME.*`. |
| `--task FILE` | File chỉ chứa phần task của prompt (bắt buộc). |
| `--repo DIR` | Repo chính (mặc định: thư mục hiện tại; tự resolve về repo chính nếu gọi từ trong linked worktree). |
| `--base REF` | Commit-ish xuất phát cho nhánh (mặc định: `HEAD`). |
| `--scope PATHSPEC` | Đường dẫn agy được phép thay đổi (tính từ gốc worktree, lặp lại được). |
| `--allow-path PATH` | Cho phép agy chạm vào một đường dẫn thông thường bị cấm (lặp lại được). |
| `--no-setup` | Bỏ qua chạy `SETUP_CMDS` và `COPY_FILES`. |
| `--reuse-worktree` | Dùng lại worktree đã tồn tại thay vì báo lỗi. |
| `--resume` | Tiếp tục conversation agy của lượt chạy trước (đọc id từ dòng `init` cuối của log `.jsonl`; ngụ ý `--reuse-worktree` và `--no-setup`). |
| `--model M` | Model truyền tiếp sang `agy-run`. |

### Lệnh `rm`

```bash
agy-task rm NAME [-f] [--repo DIR]
```

Xóa worktree `<repo>/.worktrees/agy-NAME` (`git worktree remove`), nhánh `agy/NAME` (`git branch -d`), và file prompt đã ghép `.agy-sessions/NAME.prompt.txt`. Giữ lại toàn bộ audit trail: `NAME.jsonl`, `NAME.summary.txt`, `NAME.setup.log`.

Nếu không có `-f`, lệnh từ chối (exit 2) khi: worktree có thay đổi chưa commit hoặc file untracked chưa ignore, hoặc nhánh `agy/NAME` có commit chưa merge vào HEAD của repo chính. Dùng `-f` để ép xóa (`git worktree remove --force` và `git branch -D`).

### Exit codes

- `0`: Thành công (`run`: agy-run thành công, không vi phạm scope; `rm`: xóa thành công).
- `1, 4, 5, 6`: Mã lỗi từ `agy-run` truyền nguyên vẹn ra ngoài.
- `2`: Tham số sai, lỗi cấu hình, hoặc `rm` bị từ chối / không có gì để xóa.
- `7`: Setup thất bại (lệnh trong `SETUP_CMDS` lỗi).
- `8`: Vi phạm scope hoặc file cấm.

### Bố cục file Summary

Summary ghi vào `.agy-sessions/NAME.summary.txt` (và in ra stdout khi hoàn thành) gồm các khối:
- Dòng kết quả đầu tiên: `RESULT=OK`, `RESULT=SCOPE_VIOLATION`, `RESULT=SETUP_FAILED`, hoặc `RESULT=AGY_FAILED`.
- Thông tin môi trường: `worktree`, `branch`, `base`.
- Dòng `agy`: trạng thái status, số lượt (turns), token sử dụng, thời gian chạy.
- `changed files`: thống kê thay đổi theo git (`diff --stat`) và file untracked (`??`).
- `scope`: kết quả kiểm tra scope (`scope: OK` hoặc danh sách vi phạm).
- `agy report`: trích đoạn phản hồi từ agy (tối đa 25 dòng).
- `logs`: danh sách đường dẫn tới các file log.

### Cơ chế kiểm tra Scope và File cấm

- File cấm mặc định: `.env*`, lockfile (`pnpm-lock.yaml`, `package-lock.json`, `yarn.lock`), file tài liệu prompt AI (`CLAUDE*.md`, `AGENTS.md`, `GEMINI*.md`). Muốn cho phép phải dùng `--allow-path`.
- Khi có `--scope`, chỉ các thay đổi nằm trong pathspec mới được chấp nhận; file ngoài scope sẽ bị báo vi phạm.
- **Di chuyển HEAD (commit):** agy không được phép tự ý commit. Nếu HEAD của worktree bị dịch chuyển (`START_HEAD != NOW_HEAD`), đó được tính là một vi phạm scope (`scope: violation: agy moved HEAD (committed)...`).

### Nhật ký sử dụng (`usage.tsv`)

Ở cuối mỗi lượt `run` đến được summary (ở mọi kết quả OK, SCOPE_VIOLATION, SETUP_FAILED, AGY_FAILED), một dòng dạng TSV (tab-separated) được ghi nối vào `<repo>/.agy-sessions/usage.tsv`:
- Các cột: `timestamp`, `name`, `result`, `agy_status`, `turns`, `tokens`, `agy_seconds`, `exit_code`.
- Dòng tiêu đề được tự động ghi khi file chưa tồn tại.
- File không bao giờ bị ghi đè, và lỗi ghi file (nếu có) sẽ được bỏ qua mà không làm hỏng tiến trình run. Giá trị thiếu được ghi thành `-`.

### Giới hạn đã biết

- Worktree bắt đầu từ commit `--base`, **không kế thừa các thay đổi chưa commit** của repo chính.
- Kiểm tra scope và file cấm chỉ nhìn thấy các file được git báo cáo (nếu agy tạo một file nằm trong `.gitignore`, ví dụ `.env`, git không báo nên bộ kiểm tra không thấy).

## Biến môi trường

| Biến | Mặc định | Dùng cho |
|---|---|---|
| `AGY_HOME` | `~/.gemini/antigravity-cli` | thư mục dữ liệu của agy (test trỏ vào thư mục tạm) |
| `AGY_BIN` | `agy` | binary agy |
| `AGY_TZ` | `UTC-7` | múi giờ hiển thị |
| `AGY_NOW` | giờ hiện tại | chỉ để test: giả lập "bây giờ" |
| `AGYR_COLOR` | `auto` | `auto` (có màu khi in ra terminal và không đặt `NO_COLOR`), `always`, `never` |
| `AGYR_TEST_TIMEOUT` | `120` | số giây tối đa cho mỗi account trong `agyr test` |
| `AGY_RUN_MAX_SWITCH` | `10` | số lần đổi account tối đa của `agy-run` |
| `AGY_RUN_POLL` | `1` | giây giữa hai lần `agy-run` soi log |

## Skill `agy` (bản sao)

`skill/agy/` là **bản sao** của skill `agy` dùng cho cả Claude Code (`~/.claude/skills/agy/`) và Antigravity (`~/.gemini/config/skills/agy/`), được đồng bộ với bản đang dùng tại commit gần nhất: `SKILL.md` (quy trình giao việc, quy tắc an toàn, cách dùng `agy-task`/`agy-run`) và `references/` (chi tiết chỉ đọc khi gặp đúng tình huống: quota/đăng nhập, fallback 503, chạy song song, log và chi phí, quy trình thủ công).

```bash
# Cài cho Claude Code:
mkdir -p ~/.claude/skills && cp -r skill/agy ~/.claude/skills/
# Cài cho Antigravity (AGY):
mkdir -p ~/.gemini/config/skills && cp -r skill/agy ~/.gemini/config/skills/
```

Khối HARD RULES cho task implement nằm ở `templates/hard-rules.txt` (`agy-task` tự ghép vào prompt); bản cho task chỉ-đọc nằm ở `skill/agy/references/hard-rules-explore.txt`.

Bản sao đã được làm sạch: tên tài khoản được thay bằng `acc1`, `acc2`, … và không còn tên project nội bộ.

## Test

```bash
bash test/run.sh
```

794 kiểm tra, dùng token giả và `test/fake-agy` (mô phỏng init, 429, `/quota` đúng định dạng thật); không đụng token thật. Mục `wincred` chạy với `test/fake-cred` (mục Credential Manager giả là một file), trên mọi hệ điều hành; cả bộ test ép dùng helper giả nên không bao giờ chạm vào Credential Manager thật. Trên Windows hai kiểm tra bị bỏ qua có chủ đích (quyền file 600/700 và `pgrep`); chạy mất khoảng 5 phút vì Git Bash khởi động tiến trình chậm. Trên Windows bộ test hiện chưa đạt, xem [Tình trạng test trên Windows](#tình-trạng-test-trên-windows).

## Giới hạn đã biết

- Chưa kiểm chứng với nhiều account thật: giả định "chỉ cần đổi file `antigravity-oauth-token` là đổi được account" mới được test bằng agy giả. Sau khi setup, chạy `agyr list`: mỗi slot phải hiện số quota riêng của nó (slot hỏng báo `measure failed`; `agy models` không dùng được để kiểm tra vì nó chỉ liệt kê model, không cho biết account nào). Refresh token có thể bị thu hồi (đổi mật khẩu Google, Google tự thu hồi); slot nào chết thì login lại và `save` lại.
- Process agy đang chạy giữ token cũ; `agy-run` luôn kill rồi resume, không đổi token "nóng".
- `agy-run` chỉ tính là hết quota khi log có dòng chữ thường `error: Individual quota reached …` hoặc `AGY_ERROR: … RESOURCE_EXHAUSTED (code 429)`. Khi chạy tiếp một conversation, agy có thể lặp lại lỗi quota cũ ngay trong dòng JSON `result` cuối dù lần chạy đó làm việc bình thường (thấy ngày 01/10: 4 lần "429" giả trong một session, giá trị `Resets in` không đổi); dòng JSON bị bỏ qua nên không còn đổi account oan. Khi đó `agy-run` thoát với exit 1 và ghi rõ lý do, đọc log để biết task đã xong chưa.
- Chưa xử lý 503 "No capacity" tự động (làm tay theo skill agy: `gemini-3.8-flash-medium`, chỉ dùng `gemini-3.8-flash-low` khi medium cũng không chạy được).
- Chạy nhiều `agy-run` song song dùng chung một pool theo kiểu best-effort: mỗi lần một lệnh đổi account thì file token thật đổi theo, nên dấu `*` trong `agyr list` nhảy qua lại trong lúc chúng đang chạy. Các process đang chạy vẫn giữ token riêng của mình.
- `agyr list` đo bằng bản sao token trong HOME tạm. Token đã bị thu hồi thì báo `measure failed` thay vì đoán.
- State (cooldown, active, snapshot quota) nằm ở `~/.gemini/antigravity-cli/accounts/state.json`; token backup trước mỗi lần `use` ở `accounts/.last-token.bak`.
- **Windows:** backend `wincred` chỉ được test bằng helper giả (`test/fake-cred`); `windows/cred.ps1` chạy thật lần đầu nên đi từng bước: `agyr save` (chỉ đọc) trước, rồi `agyr use`, rồi `agyr list`. Mỗi lần đọc/ghi Credential Manager gọi một tiến trình PowerShell (khoảng 1 giây), nên `agyr list` chậm hơn Linux: các account được đo tuần tự, không song song.
- **Windows:** vì chỉ có một mục Credential Manager chung cho cả máy, trong lúc `agyr list` hoặc `agyr use` chạy mà bạn mở/đăng nhập agy tay thì login có thể bị ghi đè lẫn nhau. Login gốc luôn còn trong `accounts/.last-token.bak` và trong slot tương ứng.
