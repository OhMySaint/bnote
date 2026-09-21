# BNote

App ghi chú văn bản đơn giản cho macOS. SwiftUI + SwiftData, lưu cục bộ.

## Tính năng

- Tạo / sửa / xóa ghi chú (⌘N để tạo mới)
- Tìm kiếm theo tiêu đề, nội dung, thẻ
- Gắn thẻ và lọc theo thẻ ở sidebar
- Tự lưu, sắp xếp theo lần sửa gần nhất

## Chạy

Mở `BNote.xcodeproj` trong Xcode rồi nhấn Run, hoặc build từ terminal:

```bash
xcodebuild -project BNote.xcodeproj -scheme BNote -configuration Debug -derivedDataPath build build && open build/Build/Products/Debug/BNote.app
```

## Cấu trúc

```
BNote/
  BNoteApp.swift          # App entry, ModelContainer, menu ⌘N
  Models/Note.swift       # @Model Note: title, content, tags, timestamps
  Views/ContentView.swift # NavigationSplitView: sidebar tìm kiếm + lọc thẻ
  Views/NoteEditorView.swift
```

Yêu cầu: macOS 15+, Xcode 16+.
