# agyr

Xoay vòng nhiều account Google cho `agy` (Antigravity CLI) khi một account hết quota, và xem quota thật của từng account.

- Chỉ dùng binary `agy` chính thức. Không proxy, không đọc hay in nội dung token: chỉ copy file token giữa các slot.
- Dùng nhiều account theo cách này có thể vi phạm điều khoản của Google. Dùng ở mức vừa phải.

## Cài nhanh

Cần `bash`, `git`, `jq`. Đã thử với agy 1.4.7 trên Linux.

```bash
git clone https://github.com/luongtrz/agyr.git ~/tools/agy-acct
bash ~/tools/agy-acct/linux/install.sh       # Linux: symlink vào ~/.local/bin
bash ~/tools/agy-acct/windows/install.sh     # Windows (Git Bash): wrapper vào ~/.local/bin
```

Agent AI cài repo này theo [agent.mcp.md](agent.mcp.md).

## Dùng

```bash
agyr                  # mở agy bằng account đang chọn
agyr list             # quota của mọi account, * là account đang chọn
agyr use <tên>        # đổi account
agyr save <tên>       # lưu login vừa đăng nhập bằng tay thành một slot
agyr forget           # xóa login cục bộ trước khi đăng nhập account khác
agyr help             # danh sách lệnh; agyr help <lệnh> để xem chi tiết
```

Login không tự động được: đăng nhập bằng `agyr`, rồi chạy `agyr save <tên>`.

## Tài liệu

- [docs/chi-tiet.md](docs/chi-tiet.md): cách hoạt động, lệnh đầy đủ, Windows, keyring, biến môi trường, giới hạn đã biết.
- [agent.mcp.md](agent.mcp.md): hướng dẫn cài và kiểm tra cho agent AI.
- [skill/agy](skill/agy): skill cho Claude Code và Antigravity (AGY) dùng `agy-task` và `agy-run`.

## Cấu trúc

- `bin/`: `agyr`, `agy-run`, `agy-task`
- `linux/`, `windows/`: phần riêng của từng hệ điều hành và script cài đặt
- `skill/agy/`, `templates/`, `test/`, `docs/`

## Test

```bash
bash test/run.sh      # 794 kiểm tra, dùng agy giả và token giả, không đụng login thật
```

## Giấy phép

MIT, xem [LICENSE](LICENSE).
