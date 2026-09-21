# BNote

Trình soạn thảo tài liệu cho macOS: định dạng đầy đủ kiểu Google Docs, trang giấy thật,
cây trang kiểu Notion, nhập/xuất nhiều định dạng. SwiftUI + AppKit + SwiftData, lưu cục bộ.

## Tính năng

**Định dạng văn bản**
- Chọn phông chữ (mọi phông trong máy), cỡ chữ, màu chữ, màu nền chữ
- Đậm / nghiêng / gạch chân / gạch ngang, xóa định dạng
- Kiểu đoạn: Tiêu đề lớn, Đầu mục 1–3, Văn bản, Chú thích, Mã
- Canh trái / giữa / phải / đều, giãn dòng, tăng–giảm thụt lề
- Danh sách chấm và danh sách số (tự đánh lại số, Enter tự tạo mục kế tiếp)
- Chèn ảnh, chèn liên kết, ngắt trang

**Menu "/" kiểu Notion**
- Gõ `/` giữa tài liệu để mở bảng chèn khối, lọc ngay khi gõ (không dấu vẫn khớp: `/dau muc`)
- ↑ ↓ chọn, Enter chèn, Esc đóng
- Khối có sẵn: kiểu đoạn, danh sách, việc cần làm, trích dẫn, ghi chú nổi bật,
  khối mã, đường kẻ ngang, bảng 3×3, ảnh, liên kết, ngày hôm nay, ngắt trang
- Việc cần làm: bấm thẳng vào ô vuông để đánh dấu, chữ tự gạch ngang
- Enter trên dòng trống sẽ thoát khỏi danh sách / trích dẫn / ghi chú nổi bật

**Trang giấy**
- Phân trang thật: chữ tràn từ trang này sang trang kế tiếp khi gõ
- Khổ A4 / Letter / Legal / A5 / A3 / Tabloid, giấy dọc hoặc ngang
- Lề bốn cạnh chỉnh riêng bằng số cm, hoặc kéo tay trực tiếp trên thước kẻ
- Thước kẻ, lưới ô vuông nửa centimét, đường biên lề — bật tắt từng thứ
- Thu phóng 50–250%
- Đếm số trang, số từ, số ký tự ở thanh trạng thái

**Tổ chức nội dung**
- Cây trang lồng nhau như Notion: trang con, nhân bản, xóa cả nhánh
- Mục lục tự dựng từ các Đầu mục, bấm để nhảy tới
- Tìm kiếm xuyên suốt mọi trang, lọc theo thẻ

**Ảnh & video**
- Dán ảnh (⌘V), kéo thả file ảnh vào trang, dán link ảnh → tự tải về
- Dán link YouTube → thẻ video có nút phát; click phát ngay trong app
- Click ảnh để chọn: thanh nổi đổi cỡ S/M/L/rộng, canh trái/giữa/phải, sao chép, lưu, xóa;
  kéo góc dưới phải để đổi kích thước tự do (Undo được)
- Mọi link web mở trong cửa sổ xem của app, có nút mở bằng trình duyệt

**Khối mã cho người học IT**
- `/Khối mã`: khung riêng, phông đều nét, tô màu từ khóa / chuỗi / chú thích / số / kiểu
  (Swift, Python, JS/TS, Java, Go, Rust, SQL, shell…) — tự tô lại khi gõ
- `/Mã nội dòng` cho tên hàm, lệnh trong câu; xuất Markdown dạng ``` fence

**Tổ chức & quản lý**
- Màn **Tổng quan** (⇧⌘H): mọi trang dạng lưới/danh sách, tìm, sắp xếp, lọc thẻ, thống kê
- **Hệ thống thẻ** (⇧⌘T): thẻ có màu, đổi tên (gộp khi trùng), xóa gỡ khỏi mọi trang, gợi ý khi gõ
- Chuột phải trên trang: đổi tên tại chỗ, thêm con, nhân bản, đổi icon, di chuyển tới, xóa
- Ảnh bìa (ảnh hoặc gradient, 3 mức cao), đầu trang canh giữa / ẩn icon / mô tả ngắn

**Nhập / xuất**
- Nhập: `.rtf` `.rtfd` `.doc` `.docx` `.odt` `.html` `.md` `.txt`
- Xuất: `.rtf` `.docx` `.html` `.md` `.txt` `.pdf`, và In (⌘P)

## Phím tắt

| Phím | Việc |
| --- | --- |
| ⌘N / ⇧⌘N | Trang mới / trang con mới |
| ⌘B ⌘I ⌘U | Đậm, nghiêng, gạch chân |
| ⌥⌘1–3, ⌥⌘0 | Đầu mục 1–3, Văn bản |
| ⇧⌘L E R J | Canh trái, giữa, phải, đều |
| ⇧⌘8 ⇧⌘7 ⇧⌘9 | Danh sách chấm / số / việc cần làm |
| ⌘] ⌘[ | Tăng / giảm thụt lề |
| ⇧⌘I | Nhập tài liệu |
| ⌃⌘O | Ẩn/hiện bảng bên phải |
| ⌃⌘F | Chế độ tập trung (ẩn cả hai bên) |
| ⇧⌘P | Mở thiết lập trang |
| ⌃⌘R / ⌃⌘G | Thước kẻ / lưới ô vuông |
| ⌘0 | Về cỡ thật 100% |

## Đóng gói bản dùng thử

```bash
scripts/package.sh
```

Tạo `dist/BNote-<phiên bản>.dmg` (Release, ký bằng chứng chỉ Apple Development trong máy).
Người nhận kéo app vào Applications, lần đầu chuột phải ▸ Open vì bản này chưa công chứng
(notarize) — muốn bỏ bước đó cần tài khoản Apple Developer trả phí để ký Developer ID + notarize.

## Chạy

Mở `BNote.xcodeproj` trong Xcode rồi Run, hoặc:

```bash
xcodebuild -project BNote.xcodeproj -scheme BNote -configuration Debug -derivedDataPath build build && open build/Build/Products/Debug/BNote.app
```

## Cấu trúc

```
BNote/
  BNoteApp.swift              # Scene, menu lệnh, AppActions
  Models/Note.swift           # @Model: trang, quan hệ cha–con, thẻ, khổ giấy
  Models/PageConfig.swift     # Khổ giấy và lề
  Editor/DocumentController.swift  # Text storage dùng chung, mọi lệnh định dạng, menu /
  Editor/PagedDocumentView.swift   # Canvas nhiều trang, thước kẻ, lưới, zoom
  Editor/SlashCommand.swift        # Danh mục lệnh của menu /
  Editor/SlashMenuPanel.swift      # Bảng nổi cạnh con trỏ
  Editor/TextStyle.swift      # Kiểu đoạn, nhận diện đầu mục cho mục lục
  Editor/DocumentIO.swift     # Nhập/xuất/in
  Editor/MarkdownConverter.swift
  Views/                      # Sidebar, thanh định dạng, inspector, editor
```

Phần soạn thảo dùng nhiều `NSTextView` chia sẻ một `NSLayoutManager`; mỗi trang là một
`NSTextContainer`, nên văn bản tự tràn trang và số trang tự tăng giảm theo nội dung.

Yêu cầu: macOS 15+, Xcode 16+.
