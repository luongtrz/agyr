# agy-acct

Xoay vòng nhiều account Google cho `agy` (Antigravity CLI) khi một account hết quota (429).

Chỉ làm việc với binary `agy` chính thức: copy file `~/.gemini/antigravity-cli/antigravity-oauth-token` qua lại giữa các slot. Không proxy, không đọc hay in nội dung token.

> Rủi ro: Google từng khóa account vì dùng tool/proxy bên thứ 3 để lấy quota Antigravity. Cách này giống hệt việc login tay đổi account, nhưng không có gì đảm bảo 0 rủi ro. Dùng ở mức vừa phải.

## Cài

```bash
ln -sf ~/tools/agy-acct/bin/agy-acct ~/.local/bin/agy-acct
ln -sf ~/tools/agy-acct/bin/agy-run  ~/.local/bin/agy-run
```

Cần `bash` và `jq`.

## Setup một lần

Với từng account, login bằng `agy` rồi lưu slot (làm tay, vì cần đăng nhập Google):

```bash
agy                 # login account 1, thoát ra
agy-acct save acc1
agy                 # logout/login account 2
agy-acct save acc2
agy                 # account 3
agy-acct save acc3
```

Sau mỗi lần login tay về sau, chạy lại `agy-acct save <name>` để slot không bị lệch với account thật.

## Dùng

```bash
agy-acct list                 # slot, account đang active (*), cooldown
agy-acct use acc2             # đổi tay
agy-acct cooldown acc1 4h13m  # đánh dấu hết quota
agy-acct next                 # account sẵn sàng kế tiếp (exit 3 nếu cả pool cooldown)
agy-acct rotate               # dùng agy tay mà hết quota: cooldown account hiện tại + đổi sang account kế tiếp

agy-run --prompt task.txt --add-dir /path/to/worktree --log task.jsonl [--model M]
```

`agy-run` chạy agy với `--dangerously-skip-permissions --output-format stream-json`. Gặp `Individual quota reached` thì kill ngay (không chờ agy retry), ghi cooldown theo `Resets in …`, chuyển sang account kế tiếp và resume bằng `--conversation <id>`.

Exit code của `agy-run`: `0` xong, `1` agy lỗi khác, `2` sai tham số, `4` lỗi đăng nhập hoặc chưa có account active, `5` cả pool hết quota, `6` đổi account quá `AGY_RUN_MAX_SWITCH` (mặc định 6) lần.

## Khi đang dùng agy tay mà hết quota

Thoát agy (process đang chạy giữ token cũ), rồi:

```bash
agy-acct rotate    # cooldown account hiện tại (đọc "Resets in …" từ log agy) + đổi sang account kế tiếp
agy -c             # mở lại, tiếp tục conversation gần nhất
```

`rotate [thời gian]` nhận thời gian nhập tay (ví dụ `rotate 4h13m`) nếu log không có lỗi quota trong 1 giờ gần đây (khi đó mặc định 5h). Cả pool đang cooldown thì exit 3 và không đổi token.

## Test

```bash
bash test/run.sh
```

Dùng token giả và `test/fake-agy`; không đụng token thật.

## Giới hạn đã biết

- Process agy đang chạy giữ token cũ; `agy-run` luôn kill rồi resume, không đổi token "nóng".
- `agy-run` nhận diện lỗi bằng text trong log. Nếu prompt của task chứa nguyên văn `Individual quota reached` mà agy echo lại ra log, có thể báo nhầm.
- Chưa xử lý 503 "No capacity" (chuyển sang `gemini-3.7-flash-high` vẫn làm tay theo skill agy).
- State (cooldown, active) nằm ở `~/.gemini/antigravity-cli/accounts/state.json`; token backup trước mỗi lần `use` ở `accounts/.last-token.bak`.
