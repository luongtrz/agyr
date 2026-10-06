# agyr

Xoay vòng nhiều account Google cho `agy` (Antigravity CLI) khi một account hết quota (429), và xem quota thật của từng account.

Chỉ làm việc với binary `agy` chính thức: copy file `~/.gemini/antigravity-cli/antigravity-oauth-token` qua lại giữa các slot. Không proxy, không đọc hay in nội dung token.

> Rủi ro: Google từng khóa account vì dùng tool/proxy bên thứ 3 để lấy quota Antigravity. Cách này giống hệt việc login tay đổi account, nhưng không có gì đảm bảo 0 rủi ro. Dùng ở mức vừa phải.

Gồm ba lệnh trong `bin/`:

- `agyr`: quản lý slot, xem quota, đổi account. Đây là lệnh bạn tự gõ.
- `agy-run`: chạy một task agy và tự đổi account khi hết quota. Chủ yếu do Claude gọi qua skill `agy`, xem phần [agy-run](#agy-run-dành-cho-claude).
- `agy-task`: chạy trọn gói một task IMPLEMENT trong git worktree riêng, kiểm tra scope, chạy verify và dọn dẹp. Xem phần [agy-task](#agy-task-dành-cho-claude).

## Cài

```bash
ln -sf ~/tools/agy-acct/bin/agyr ~/.local/bin/agyr
ln -sf ~/tools/agy-acct/bin/agy-run  ~/.local/bin/agy-run
ln -sf ~/tools/agy-acct/bin/agy-task ~/.local/bin/agy-task
```

Cần `bash` và `jq`.

## Windows (Git Bash)

Chạy trong **Git Bash**, cần `jq` (ví dụ `winget install jqlang.jq`). Trong Git Bash `ln -sf` chỉ tạo bản copy, nên cài bằng wrapper nhỏ trỏ thẳng vào repo (`git pull` là cập nhật):

```bash
mkdir -p ~/.local/bin
for n in agyr agy-run agy-task; do
  printf '#!/usr/bin/env bash\nexec "$HOME/tools/agy-acct/bin/%s" "$@"\n' "$n" > ~/.local/bin/$n
  chmod +x ~/.local/bin/$n
done
```

Trên Windows `agy` lưu đăng nhập trong **một mục Windows Credential Manager** (target `gemini:antigravity`, loại generic, nội dung là JSON giống file token trên Linux). Không có file token, và không có cách chuyển hướng cho từng tiến trình, nên `agyr` tự chọn backend `wincred` (xem `agyr backend`) và đổi account bằng cách **ghi đè chính mục đó**:

- `agyr save <tên>`: đọc mục đó vào slot `accounts/<tên>.token` (cùng định dạng slot như bản Linux).
- `agyr use <tên>`: backup login đang dùng vào `accounts/.last-token.bak`, rồi ghi slot đè lên mục đó. Sau đó `agy` trần và `agyr` hoạt động giống hệt nhau (không cần mẹo D-Bus như trên Linux).
- `agyr list`: **đo lần lượt**, không song song (mỗi account một lần: ghi login vào, chạy `agy -p /quota`, lấy lại token mà agy đã refresh). Xong thì đặt lại login đang dùng, kể cả khi bị Ctrl+C hoặc lỗi giữa chừng. Trong lúc đo đừng mở agy hay đăng nhập tay.
- `agyr forget`: xóa login hiện tại **chỉ ở máy này** (không thu hồi gì phía Google), để `agy` hỏi đăng nhập account khác. Thay cho `rm ~/.gemini/antigravity-cli/antigravity-oauth-token` của Linux. Từ chối nếu login chưa nằm trong slot nào (trừ khi `--force`).
- Mọi thao tác ghi vào Credential Manager đều dùng khóa `accounts/.swap.lock`, để `agy-run` và `agyr list` chạy cùng lúc không giẫm lên nhau.

Setup một lần trên Windows:

```bash
agy                       # đăng nhập account 1, rồi thoát
agyr save acct1
agyr forget
agy                       # đăng nhập account 2, rồi thoát
agyr save acct2
agyr forget
agy                       # đăng nhập account 3...
agyr save acct3
agyr use acct1 # chọn account dùng hằng ngày
agyr list                 # kiểm tra từng slot còn sống
```

Slot là file thường, được bảo vệ bằng quyền của thư mục profile Windows (không có `chmod 600` trên NTFS). Các file riêng của Windows nằm trong `win/`: `cred.sh` + `cred.ps1` (đọc/ghi/xóa mục Credential Manager, không bao giờ in nội dung) và `inspect-cred.ps1` (chỉ in metadata của mục, không in giá trị, để chẩn đoán). Đổi target bằng `AGY_CRED_TARGET`, ép backend bằng `AGYR_BACKEND=file|wincred`.

## Quan trọng (Linux): agy từ bản 1.2.14 dùng kho mật khẩu của hệ điều hành

Từ bản **1.2.14** (tự cập nhật ngày 02/10/2026), `agy` lưu đăng nhập trong **kho mật khẩu của GNOME** (libsecret, qua D-Bus; mục `Password for 'antigravity' on 'gemini'`) và **bỏ qua file token** miễn là kho đó còn truy cập được. Hậu quả: `agyr use` đổi file token nhưng `agy` chạy bình thường vẫn dùng account nằm trong kho (banner không đổi), và mọi lần đo quota đều ra cùng một account.

Cách `agyr` xử lý: mọi `agy` do `agyr` hoặc `agy-run` khởi động đều được chạy với địa chỉ D-Bus không tồn tại, nên agy không với tới kho mật khẩu và quay về dùng file token. `agyr list` và `agy-run` tự làm vậy. Khi bạn tự mở agy, hãy gõ **`agyr`** thay cho `agy`: `agyr` trần mở agy, `agyr -c` tiếp tục conversation gần nhất, và mọi cờ của agy đều dùng được (ví dụ `agyr -p "..."`). Tham số đầu tiên không bắt đầu bằng `-` được hiểu là lệnh của `agyr` (ví dụ `agyr list`); muốn truyền một từ như vậy cho agy thì viết `agyr run models`. `agyr run ...` vẫn dùng được và giống hệt. Không cần alias. `agy` chạy trần vẫn dùng account trong kho mật khẩu, bỏ qua `agyr use`.

## Setup một lần

Tên slot do bạn tự đặt: chỉ gồm chữ cái không dấu, số, `-` và `_` (ví dụ `acct2`, `work`). Không dùng dấu cách, dấu chấm, `@` hay `/`.

Với từng account, đăng nhập bằng `agyr` rồi lưu slot. Làm tay vì cần đăng nhập Google. **Đừng dùng lệnh logout của agy** (chưa rõ nó có thu hồi token ở phía Google không); thay vào đó dùng `agyr forget` (xóa file token cục bộ, tương đương `rm ~/.gemini/antigravity-cli/antigravity-oauth-token`, slot đã giữ bản copy):

```bash
agyr save acct1                 # account đang đăng nhập
agyr forget                     # bỏ login hiện tại
agyr                            # đăng nhập account 2, rồi thoát
agyr save acct2
agyr forget
agyr                            # đăng nhập account 3, rồi thoát
agyr save acct3
```

Kiểm tra: `agyr list` phải hiện số quota riêng cho từng slot (slot hỏng báo `measure failed`).

`agyr forget` từ chối (exit 1, không xóa gì) khi login hiện tại chưa được lưu thành slot, để bạn không mất nó; `agyr save <tên>` trước, hoặc `agyr forget -f` nếu muốn bỏ luôn (bản sao vẫn nằm trong `accounts/.last-token.bak` đến lần `use`/`forget` kế tiếp). Nó chỉ xóa file token trên máy: không đăng xuất ở phía Google, và `agy` chạy trần vẫn dùng login trong kho mật khẩu.

Sau mỗi lần login tay một account, chạy `agyr save <tên>`. Nếu quên, `agyr list` cảnh báo token không khớp slot nào, và `agyr use` không ghi đè slot nào.

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
agyr rotate    # cooldown account hiện tại (đọc "Resets in …" từ log agy) + đổi sang account kế tiếp
agyr -c            # mở lại bằng account mới, tiếp tục conversation gần nhất
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

## agyr test: gửi "Hi" cho từng account

```
$ agyr test
Sending "Hi" to 3 account(s): one real request each, so it uses a little quota...
  ACCOUNT        HI                                             GEMINI 5H    RESETS
  acct3          ok in 11s: "Hello! How can I help yo"          16%>16%      05/10/2026 04:49 PM
  work           ok in 9s: "Hello! How can I help yo"           100%>99%     05/10/2026 07:31 PM (was 07:04 PM)
  acct1          skipped (cooldown, 45m left)
Measured at 05/10/2026 02:19 PM   (GEMINI 5H = before>after; RESETS = end of the account's current 5-hour window; "(was ...)" = it moved because of the Hi)
```

Mỗi account được đo quota (0 token), nhận một request `agy -p Hi` (model `gemini-3.8-flash-high`, không công cụ, thư mục tạm trống, không đọc gì của bạn), rồi đo lại. Bảng hiện câu trả lời hoặc lỗi, quota 5 giờ trước>sau, và giờ reset (kèm `(was ...)` nếu request làm giờ reset dịch chuyển).

- **Tốn quota thật:** một request mỗi account. Thử thật trên một account: quota 5 giờ vẫn 16% sau lần gọi (dưới 1%). Một lần chạy agy luôn có phần nền khoảng 20 nghìn token dù prompt chỉ một từ.
- **Mục đích** là bắt đầu đếm ngược 5 giờ của mọi account cùng lúc. **Giả thuyết "cửa sổ 5 giờ bắt đầu từ request đầu tiên" chưa được kiểm chứng**, agy không ghi tài liệu về việc này, và số đo thật chưa xác nhận: `work` đang 100% giữ nguyên giờ reset 07:04 PM qua hai lần đo cách nhau 15 phút (không trôi theo giờ hiện tại, cũng không rõ nó tính từ đâu). Cách kiểm chứng: chạy `agyr test <tên>` trên một account 100% chưa dùng; nếu cột RESETS có `(was ...)` thì request đã dịch giờ reset, nếu không thì "Hi" không mở cửa sổ mới.
- Không đặt tên thì bỏ qua account đang cooldown (hết quota). Đặt tên (`agyr test acct1 work`) thì account đó luôn được thử.
- Không đụng login đang dùng; cách đo giống `agyr list` (song song trên Linux, lần lượt trên Windows). Quá `AGYR_TEST_TIMEOUT` giây (mặc định 120) thì cắt agy và báo `agy gave no answer`.
- Exit code: 0 nếu mọi account được thử đều trả lời, 1 nếu có account không trả lời.

## Múi giờ

Mọi giờ hiển thị đều theo **UTC+7** và có dạng `dd/mm/yyyy hh:mm AM|PM` (ví dụ `01/10/2026 07:14 PM`), không phụ thuộc múi giờ hay ngôn ngữ của máy. Đổi bằng biến môi trường `AGY_TZ` (ví dụ `AGY_TZ=UTC`; theo quy ước POSIX thì `UTC-7` nghĩa là UTC+7, và là giá trị mặc định). Giờ trong log của agy cũng được đọc theo múi giờ này.

## agy-run (dành cho Claude)

`agy-run` không phải lệnh để gõ tay hằng ngày: Claude gọi nó thay cho `agy -p` khi giao việc cho agy (xem skill `agy`, mục "Account pool"). Nó chạy agy với `--dangerously-skip-permissions --output-format stream-json`; gặp `Individual quota reached` thì kill ngay (không chờ agy retry), ghi cooldown theo `Resets in …`, chuyển sang account kế tiếp và resume đúng conversation bằng `--conversation <id>`.

Exit code: `0` xong, `1` agy lỗi khác, `2` sai tham số, `4` lỗi đăng nhập hoặc chưa có account active, `5` cả pool hết quota, `6` đổi account quá `AGY_RUN_MAX_SWITCH` (mặc định 6) lần.

## agy-task (dành cho Claude)

`agy-task` là wrapper tất định (deterministic) để giao **trọn gói một task IMPLEMENT** cho `agy` từ đầu đến cuối mà **không dùng bất kỳ LLM nào trong wrapper**: tự tạo worktree tách biệt, chạy setup, gọi `agy-run`, kiểm tra scope, chạy các lệnh verify và xuất file summary. Đối với việc đọc code tìm hiểu (read-only exploration), Claude vẫn dùng `agy-run` trực tiếp trên repo chính.

### Luồng sử dụng điển hình

1. Claude chuẩn bị nội dung task vào một file (ví dụ `task.txt`).
2. Chạy `agy-task run --name x --task task.txt --scope 'paths' --verify web` ở background.
3. Đọc kết quả trong `.agy-sessions/x.summary.txt` và xem `git diff` trong worktree `.worktrees/agy-x`.
4. Nếu kết quả đạt, commit vào repo chính.
5. Dọn dẹp bằng `agy-task rm x -f`.

### File cấu hình

`agy-task` tìm file cấu hình tại `.agy-sessions/agy-task.conf` của repo chính (hoặc đường dẫn override qua biến môi trường `$AGY_TASK_CONF`). File này được `source` trực tiếp như một script bash của người dùng (trusted file), gồm các biến:

- `SETUP_CMDS`: mảng lệnh bash chạy trong worktree trước khi chạy agy (ví dụ cài dependency, build).
- `COPY_FILES`: mảng đường dẫn file/thư mục tương đối copy từ repo chính sang worktree (ví dụ các file sinh tự động như `routeTree.gen.ts`; không nên copy file chứa credential vào worktree).
- `VERIFY`: mảng liên kết (`declare -A VERIFY`) khai báo các preset lệnh verify đặt tên sẵn.
- `DEFAULT_VERIFY`: mảng tên preset mặc định sẽ chạy nếu không chỉ định `--verify` hay `--verify-cmd`.

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
| `--verify NAME` | Tên preset từ cấu hình `VERIFY` (lặp lại được). |
| `--verify-cmd CMD` | Lệnh shell ad-hoc chạy bằng `bash -c` từ gốc worktree (lặp lại được). |
| `--verify-timeout S` | Timeout cho từng lệnh verify tính bằng giây (mặc định: 900). |
| `--no-setup` | Bỏ qua chạy `SETUP_CMDS` và `COPY_FILES`. |
| `--reuse-worktree` | Dùng lại worktree đã tồn tại thay vì báo lỗi. |
| `--model M` | Model truyền tiếp sang `agy-run`. |

### Lệnh `rm`

```bash
agy-task rm NAME [-f] [--repo DIR]
```

Xóa worktree `<repo>/.worktrees/agy-NAME` (`git worktree remove`), nhánh `agy/NAME` (`git branch -d`), và file prompt đã ghép `.agy-sessions/NAME.prompt.txt`. Giữ lại toàn bộ audit trail: `NAME.jsonl`, `NAME.summary.txt`, `NAME.setup.log`, `NAME.verify-*.log`.

Nếu không có `-f`, lệnh từ chối (exit 2) khi: worktree có thay đổi chưa commit hoặc file untracked chưa ignore, hoặc nhánh `agy/NAME` có commit chưa merge vào HEAD của repo chính. Dùng `-f` để ép xóa (`git worktree remove --force` và `git branch -D`).

### Exit codes

- `0`: Thành công (`run`: agy-run thành công, không vi phạm scope, mọi verify đều pass; `rm`: xóa thành công).
- `1, 4, 5, 6`: Mã lỗi từ `agy-run` truyền nguyên vẹn ra ngoài.
- `2`: Tham số sai, lỗi cấu hình, hoặc `rm` bị từ chối / không có gì để xóa.
- `7`: Setup thất bại (lệnh trong `SETUP_CMDS` lỗi).
- `8`: Verify thất bại hoặc vi phạm scope/file cấm.

### Bố cục file Summary

Summary ghi vào `.agy-sessions/NAME.summary.txt` (và in ra stdout khi hoàn thành) gồm các khối:
- Dòng kết quả đầu tiên: `RESULT=OK`, `RESULT=VERIFY_FAILED`, `RESULT=SCOPE_VIOLATION`, `RESULT=SETUP_FAILED`, hoặc `RESULT=AGY_FAILED`.
- Thông tin môi trường: `worktree`, `branch`, `base`.
- Dòng `agy`: trạng thái status, số lượt (turns), token sử dụng, thời gian chạy.
- `changed files`: thống kê thay đổi theo git (`diff --stat`) và file untracked (`??`).
- `scope`: kết quả kiểm tra scope (`scope: OK` hoặc danh sách vi phạm).
- `verify`: bảng kết quả từng lệnh (`PASS`, `FAIL`, `TIMEOUT`) kèm thời gian và 40 dòng log cuối nếu lỗi.
- `agy report`: trích đoạn phản hồi từ agy (tối đa 25 dòng).
- `logs`: danh sách đường dẫn tới các file log.

### Cơ chế kiểm tra Scope và File cấm

- File cấm mặc định: `.env*`, lockfile (`pnpm-lock.yaml`, `package-lock.json`, `yarn.lock`), file tài liệu prompt AI (`CLAUDE*.md`, `AGENTS.md`, `GEMINI*.md`). Muốn cho phép phải dùng `--allow-path`.
- Khi có `--scope`, chỉ các thay đổi nằm trong pathspec mới được chấp nhận; file ngoài scope sẽ bị báo vi phạm.
- **Di chuyển HEAD (commit):** agy không được phép tự ý commit. Nếu HEAD của worktree bị dịch chuyển (`START_HEAD != NOW_HEAD`), đó được tính là một vi phạm scope (`scope: violation: agy moved HEAD (committed)...`).

### Nhật ký sử dụng (`usage.tsv`)

Ở cuối mỗi lượt `run` đến được summary (ở mọi kết quả OK, VERIFY_FAILED, SCOPE_VIOLATION, SETUP_FAILED, AGY_FAILED), một dòng dạng TSV (tab-separated) được ghi nối vào `<repo>/.agy-sessions/usage.tsv`:
- Các cột: `timestamp`, `name`, `result`, `agy_status`, `turns`, `tokens`, `agy_seconds`, `exit_code`.
- Dòng tiêu đề được tự động ghi khi file chưa tồn tại.
- File không bao giờ bị ghi đè, và lỗi ghi file (nếu có) sẽ được bỏ qua mà không làm hỏng tiến trình run. Giá trị thiếu được ghi thành `-`.

### Giới hạn đã biết

- Worktree bắt đầu từ commit `--base`, **không kế thừa các thay đổi chưa commit** của repo chính.
- Kiểm tra scope và file cấm chỉ nhìn thấy các file được git báo cáo (nếu agy tạo một file nằm trong `.gitignore`, ví dụ `.env`, git không báo nên bộ kiểm tra không thấy).
- `RESULT=OK` khi không có lệnh verify nào đồng nghĩa là chưa có bài kiểm tra nào được chạy thực tế (`RESULT=OK (no verify commands ran)`).

## Biến môi trường

| Biến | Mặc định | Dùng cho |
|---|---|---|
| `AGY_HOME` | `~/.gemini/antigravity-cli` | thư mục dữ liệu của agy (test trỏ vào thư mục tạm) |
| `AGY_BIN` | `agy` | binary agy |
| `AGY_TZ` | `UTC-7` | múi giờ hiển thị |
| `AGY_NOW` | giờ hiện tại | chỉ để test: giả lập "bây giờ" |
| `AGYR_COLOR` | `auto` | `auto` (có màu khi in ra terminal và không đặt `NO_COLOR`), `always`, `never` |
| `AGYR_TEST_TIMEOUT` | `120` | số giây tối đa cho mỗi account trong `agyr test` |
| `AGY_RUN_MAX_SWITCH` | `6` | số lần đổi account tối đa của `agy-run` |
| `AGY_RUN_POLL` | `1` | giây giữa hai lần `agy-run` soi log |

## Skill `agy` (bản sao)

`skill/agy/SKILL.md` là **bản sao** của skill Claude Code `agy` (`~/.claude/skills/agy/SKILL.md`), chụp ngày 02/10/2026: cách giao việc cho agy, quy tắc an toàn, và cách dùng `agyr`/`agy-run`. Bản đang dùng thật nằm ở `~/.claude/skills/agy/`, file trong repo không tự cập nhật theo.

```bash
cp ~/.claude/skills/agy/SKILL.md skill/agy/SKILL.md          # cập nhật bản sao trong repo
mkdir -p ~/.claude/skills/agy && cp skill/agy/SKILL.md ~/.claude/skills/agy/   # cài lên máy khác
```


## Test

```bash
bash test/run.sh
```

497 kiểm tra, dùng token giả và `test/fake-agy` (mô phỏng init, 429, `/quota` đúng định dạng thật); không đụng token thật. Mục `wincred` chạy với `test/fake-cred` (mục Credential Manager giả là một file), trên mọi hệ điều hành; cả bộ test ép dùng helper giả nên không bao giờ chạm vào Credential Manager thật. Trên Windows hai kiểm tra bị bỏ qua có chủ đích (quyền file 600/700 và `pgrep`); chạy mất khoảng 5 phút vì Git Bash khởi động tiến trình chậm.

## Giới hạn đã biết

- Chưa kiểm chứng với nhiều account thật: giả định "chỉ cần đổi file `antigravity-oauth-token` là đổi được account" mới được test bằng agy giả. Sau khi setup, hãy thử `use` + `agy models` cho từng slot. Refresh token có thể bị thu hồi (đổi mật khẩu Google, Google tự thu hồi); slot nào chết thì login lại và `save` lại.
- Process agy đang chạy giữ token cũ; `agy-run` luôn kill rồi resume, không đổi token "nóng".
- `agy-run` chỉ tính là hết quota khi log có dòng chữ thường `error: Individual quota reached …` hoặc `AGY_ERROR: … RESOURCE_EXHAUSTED (code 429)`. Khi chạy tiếp một conversation, agy có thể lặp lại lỗi quota cũ ngay trong dòng JSON `result` cuối dù lần chạy đó làm việc bình thường (thấy ngày 01/10: 4 lần "429" giả trong một session, giá trị `Resets in` không đổi); dòng JSON bị bỏ qua nên không còn đổi account oan. Khi đó `agy-run` thoát với exit 1 và ghi rõ lý do, đọc log để biết task đã xong chưa.
- Chưa xử lý 503 "No capacity" (chuyển sang `gemini-3.7-flash-high` vẫn làm tay theo skill agy).
- Chạy nhiều `agy-run` song song dùng chung một pool theo kiểu best-effort: mỗi lần một lệnh đổi account thì file token thật đổi theo, nên dấu `*` trong `agyr list` nhảy qua lại trong lúc chúng đang chạy. Các process đang chạy vẫn giữ token riêng của mình.
- `agyr list` đo bằng bản sao token trong HOME tạm. Token đã bị thu hồi thì báo `measure failed` thay vì đoán.
- State (cooldown, active, snapshot quota) nằm ở `~/.gemini/antigravity-cli/accounts/state.json`; token backup trước mỗi lần `use` ở `accounts/.last-token.bak`.
- **Windows:** backend `wincred` chỉ được test bằng helper giả (`test/fake-cred`); `win/cred.ps1` chạy thật lần đầu nên đi từng bước: `agyr save` (chỉ đọc) trước, rồi `agyr use`, rồi `agyr list`. Mỗi lần đọc/ghi Credential Manager gọi một tiến trình PowerShell (khoảng 1 giây), nên `agyr list` chậm hơn Linux: các account được đo tuần tự, không song song.
- **Windows:** vì chỉ có một mục Credential Manager chung cho cả máy, trong lúc `agyr list` hoặc `agyr use` chạy mà bạn mở/đăng nhập agy tay thì login có thể bị ghi đè lẫn nhau. Login gốc luôn còn trong `accounts/.last-token.bak` và trong slot tương ứng.
