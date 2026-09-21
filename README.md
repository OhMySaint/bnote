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

**Trang giấy**
- Phân trang thật: chữ tràn từ trang này sang trang kế tiếp khi gõ
- Khổ A4 / Letter / Legal / A5, ba mức lề
- Đếm số trang, số từ, số ký tự ở thanh trạng thái

**Tổ chức nội dung**
- Cây trang lồng nhau như Notion: trang con, nhân bản, xóa cả nhánh
- Mục lục tự dựng từ các Đầu mục, bấm để nhảy tới
- Tìm kiếm xuyên suốt mọi trang, lọc theo thẻ

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
| ⇧⌘8 / ⇧⌘7 | Danh sách chấm / số |
| ⌘] ⌘[ | Tăng / giảm thụt lề |
| ⇧⌘I | Nhập tài liệu |
| ⌃⌘O | Ẩn/hiện mục lục |

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
  Editor/DocumentController.swift  # Text storage dùng chung, mọi lệnh định dạng
  Editor/PagedDocumentView.swift   # Canvas nhiều trang, mỗi trang một NSTextView
  Editor/TextStyle.swift      # Kiểu đoạn, nhận diện đầu mục cho mục lục
  Editor/DocumentIO.swift     # Nhập/xuất/in
  Editor/MarkdownConverter.swift
  Views/                      # Sidebar, thanh định dạng, mục lục, editor
```

Phần soạn thảo dùng nhiều `NSTextView` chia sẻ một `NSLayoutManager`; mỗi trang là một
`NSTextContainer`, nên văn bản tự tràn trang và số trang tự tăng giảm theo nội dung.

Yêu cầu: macOS 15+, Xcode 16+.
