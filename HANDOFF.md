# BNote — tài liệu bàn giao (đọc trước khi tiếp tục ở chat mới)

Cập nhật: 2026-09-21. Người dùng: Hoàng Sơn (GitHub **OhMySaint**, gõ tiếng Việt bằng **OpenKey**).

## 1. Dự án là gì, đang ở đâu

- **BNote**: app ghi chú/soạn thảo macOS native (SwiftUI + AppKit + SwiftData), phong cách **Notion** (cây trang, `/` chèn khối, bìa, thẻ) nhưng có lõi văn bản kiểu Google Docs (định dạng đầy đủ, xuất PDF/DOCX/RTF/HTML/MD, có chế độ phân trang theo khổ giấy).
- Mã nguồn: `~/bnote`, repo công khai https://github.com/OhMySaint/bnote (main, push bằng `gh` đã đăng nhập).
- Bản cho người khác dùng thử: `scripts/package.sh` → `dist/BNote-0.2.0.dmg` (ký Apple Development, chưa notarize → người nhận chuột phải ▸ Open). Release đã đăng: https://github.com/OhMySaint/bnote/releases/tag/v0.2.0 (tải file mới lên bằng `gh release upload v0.2.0 dist/*.dmg --clobber` hoặc tạo tag mới).
- Bản user dùng hằng ngày: `/Applications/BNote.app` (copy từ `dist/staging/` sau mỗi lần package: `rm -rf /Applications/BNote.app && ditto dist/staging/BNote.app /Applications/BNote.app`).
- Dữ liệu: `~/Library/Containers/com.hoangson.BNote/Data/Library/Application Support/default.store` (SwiftData). Có 2 trang test tôi sinh: "[Test] Luận văn 35 trang" và cây "[Test] Screenplay — The Last Train" (1 gốc + 3 hồi + 26 cảnh).

## 2. Kiến trúc (file quan trọng)

| File | Vai trò |
| --- | --- |
| `Editor/DocumentController.swift` | Singleton. Sở hữu `NSTextStorage` + `NSLayoutManager` dùng chung; mọi lệnh định dạng; menu `/`; danh sách; khối; Enter/Tab/Backspace; media; slash panel; lưu (debounce 0,4s) |
| `Editor/PagedDocumentView.swift` | `PageTextView` (subclass NSTextView), `PageView`, `PagedDocumentView` (canvas), `EditorCanvasView` (host + scroll + zoom), `PagedEditor` (NSViewRepresentable). Hai bố cục: **Liên tục** (1 container, cột theo cửa sổ) và **Trang giấy rời** (nhiều container = nhiều trang) |
| `Editor/DocumentStorage.swift` | Lưu tài liệu = **NSKeyedArchiver không secure coding**; sửa chữa dữ liệu RTFD cũ; làm phẳng khối khi xuất |
| `Editor/DocumentIO.swift` | Nhập/xuất/in; `ExportHeader` (bìa + tiêu đề trước nội dung) |
| `Editor/SlashCommand.swift`, `SlashMenuPanel.swift` | Danh mục `/` và panel nổi (NSPanel **không được thành key**) |
| `Editor/CodeHighlighter.swift` | Tô màu mã regex; `NSTextBlock.isDecoration` |
| `Editor/MediaSupport.swift`, `MediaToolbar.swift` | YouTube/ảnh/link, cửa sổ xem trong app (WKWebView), thanh nổi khi chọn ảnh |
| `Editor/AppActions.swift` | Cầu nối menu → ContentView (closure) |
| `Views/ContentView.swift` | NavigationSplitView; sidebar / dashboard / editor; PageActions; export; link nội bộ |
| `Views/PageHeaderView.swift` | Đầu trang kiểu Notion (bìa, icon đè mép, tiêu đề, thẻ) — **overlay SwiftUI ngoài scroll view**, đồng bộ cuộn qua `HeaderLayout` |
| `Views/NoteEditorView.swift` | Toolbar + editor + inspector + thanh trạng thái; overlay đầu trang scale theo zoom |
| `Views/DashboardView.swift`, `SidebarView.swift`, `TagViews.swift`, `PageInspector.swift`, `SettingsView.swift`, `FormatToolbar.swift`, `ColorPalette.swift`, `CoverControls.swift`, `CoverStyle.swift` | UI |
| `Models/Note.swift`, `Tag.swift`, `PageConfig.swift` | SwiftData + `Defaults` (UserDefaults) + đơn vị đo |

Luồng lưu: gõ → `textDidChange` → `documentDidChangeFromTyping` (nhẹ) → 30 ms sau: phân trang/đánh số/mục lục/đếm → `onSave` (debounce 0,4 s) ghi `note.rtfData` (archive) + `note.content` (plain).

## 3. Quyết định thiết kế & bẫy đã dẫm phải (đừng làm lại)

1. **RTF phá khối**: RTF ghi `NSTextBlock` (trích dẫn/callout/mã) thành hàng bảng không đóng → nạp lại mọi đoạn sau đó nằm trong một ô, chỉ còn 2 trang. Vì vậy lưu bằng keyed archive; RTF chỉ để xuất và phải `flattenedForExport`. Dữ liệu cũ được `repairLegacyFrames`.
2. **Secure coding**: `NSParagraphStyle` từ chối `NSTextBlock` thường, `NSURL` trong attribute lỗi giải mã → archive không secure; link lưu dạng `NSString`.
3. **Khối sau khi qua RTF thành bảng 1 cột** → phân biệt bảng thật bằng `numberOfColumns > 1` (`isDecoration`).
4. **OpenKey** phát phím tổng hợp (keyCode 0, chuỗi backspace+ký tự). Menu `/` bắt Return/Tab/↑↓/Esc ở `keyDown` **và** `doCommandBy` **và** `shouldChangeTextIn` (3 tầng); so cả ký tự lẫn keyCode; `setMarkedText` không phát `textDidChange` nên gọi `updateSlashMenu` trực tiếp.
5. **Panel nổi chứa NSHostingView có thể giành key window** → subclass `canBecomeKey = false`.
6. **NSHostingView đặt trong NSScrollView có magnification không nhận click đúng** → đầu trang là overlay ngoài scroll view, dịch theo `scrollOffset`, scale bằng `.scaleEffect(zoom)`. Hosting view tự tạo trong AppKit **không kế thừa environment SwiftUI** (truyền `.modelContainer` tường minh nếu cần).
7. **`needsLayout` trên NSView thường trong scroll view không đáng tin** → gọi `relayout()` đồng bộ khi đổi zoom/chiều cao đầu trang.
8. **Zoom kiểu Docs**: bề rộng cột tính từ `contentView.frame` (điểm màn hình, không phụ thuộc zoom) nên zoom không reflow; `magnification = textScale(chữ nhỏ 0,875) × zoom`; doc rộng hơn cửa sổ thì cuộn ngang. Pinch xử lý ở `EditorCanvasView.magnify(with:)`, `allowsMagnification = false`.
9. Mép cột: mặc định 7,5 % cửa sổ mỗi bên, toàn chiều rộng 3 %. "Toàn chiều rộng" và "Chữ nhỏ" **lưu theo từng trang** (`Note.fullWidth/smallText`), mặc định trong Cài đặt.
10. Đơn vị: mặc định **inch**, lề 0,75 in; thước kẻ đã gỡ hẳn; đường biên lề/lưới chỉ ở chế độ giấy rời.
11. Hiệu năng: không dùng `String.count` trên tài liệu lớn; công việc nặng chạy trễ sau loạt phím (0,3 ms/phím ở 35 trang).
12. `Note.uid` (UUID) cho link nội bộ `bnote://page/<uid>`; migration cho cùng một default cho mọi hàng cũ → `wireCommands` gán lại uid trùng.
13. Log chẩn đoán Debug: `~/Library/Containers/com.hoangson.BNote/Data/Library/Application Support/bnote-input.log` (chỉ build Debug).

## 4. Kiểm thử

Không GUI-test được (osascript không có Accessibility). Dùng harness headless compile thẳng bằng `swiftc`, dựng cửa sổ thật, bơm `NSEvent`:

```bash
scripts/test.sh            # editor (~100) + keyboard (~90) + ui (~20) assertion
scripts/test.sh thesis     # sinh luận văn 35 trang vào store (thoát app trước)
scripts/test.sh tree       # sinh cây kịch bản
```

Harness `ui` in ảnh `bnote-editor*.png` trong `$TMPDIR` để nhìn tận mắt. Trong `ui` có 1 check "cửa sổ chính vẫn là key" luôn FAIL vì harness không activate được app — bỏ qua.

## 5. Quy ước

- UI tiếng Việt; commit message tiếng Việt, kết bằng `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`; email commit repo này `hoangson2758@gmail.com`.
- Xcode project dùng synchronized group: thêm file vào `BNote/` là tự vào target, **không** sửa pbxproj. `Tests/` nằm ngoài target.
- Build debug: `xcodebuild -project BNote.xcodeproj -scheme BNote -configuration Debug -derivedDataPath build build`; chạy: `open build/Build/Products/Debug/BNote.app`.
- User hay gửi ảnh chụp và nói ngắn ("sai rồi", "lỗi đây"); ưu tiên tái hiện bằng harness trước khi sửa, và **relaunch/cập nhật bản cài** sau mỗi lần sửa vì họ test ngay.

## 6. Việc còn dở / ý tưởng kế tiếp

- Notarize khi có tài khoản Developer trả phí (nối vào `scripts/package.sh`).
- Kéo thả sắp xếp trang trong sidebar; tìm kiếm trong trang (⌘F); bảng có chỉnh cột; link preview cho web thường.
- Xuất PDF chưa vẽ nền khối mã (khối chỉ hiện trong layout của app).
- Khi đổi tên trang qua menu chuột phải, ô sửa hiện tại chỗ (đã bỏ double-click vì làm hỏng click chọn).
