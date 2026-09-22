# BNote — tài liệu bàn giao (đọc trước khi tiếp tục ở chat mới)

Cập nhật: 2026-09-23 (lần 2). Người dùng: Hoàng Sơn (GitHub **OhMySaint**, gõ tiếng Việt bằng **OpenKey**).

## 1. Dự án là gì, đang ở đâu

- **BNote**: app ghi chú/soạn thảo macOS native (SwiftUI + AppKit + SwiftData), phong cách **Notion** (cây trang, `/` chèn khối, bìa, thẻ) nhưng có lõi văn bản kiểu Google Docs (định dạng đầy đủ, xuất PDF/DOCX/RTF/HTML/MD, có chế độ phân trang theo khổ giấy).
- Mã nguồn: `~/bnote`, repo công khai https://github.com/OhMySaint/bnote (main, push bằng `gh` đã đăng nhập).
- Bản cho người khác dùng thử: `scripts/package.sh` → `dist/BNote-0.2.0.dmg` (ký Apple Development, chưa notarize → người nhận chuột phải ▸ Open). Release đã đăng: https://github.com/OhMySaint/bnote/releases/tag/v0.2.0 (tải file mới lên bằng `gh release upload v0.2.0 dist/*.dmg --clobber` hoặc tạo tag mới).
- **Hai phiên bản song song, dữ liệu tách hẳn** (từ 2026-09-22):
  | | Bản ổn định | Bản thử nghiệm |
  | --- | --- | --- |
  | App | `/Applications/BNote.app` | `/Applications/BNote Dev.app` |
  | Bundle id | `com.hoangson.BNote` | `com.hoangson.BNote.dev` |
  | Store | `~/Library/Containers/com.hoangson.BNote/…` | `~/Library/Containers/com.hoangson.BNote.dev/…` |
  | Dấu hiệu nhận biết | — | nhãn cam **DEV 0.2.0** ở trang Tổng quan, tên cửa sổ "BNote Dev" |
  | Build | `scripts/package.sh stable --install` | `scripts/package.sh dev --install` |
  Khác bundle id → macOS cấp container riêng nên trang/cài đặt không đụng nhau. **Sửa bug thì cài vào bản Dev; chỉ đụng bản ổn định khi user yêu cầu** (họ dùng nó hằng ngày). Chép dữ liệu qua lại để thử: `scripts/copy-data.sh stable dev` (tự sao lưu store đích, phải thoát cả hai app).
- Dữ liệu: `~/Library/Containers/com.hoangson.BNote/Data/Library/Application Support/default.store` (SwiftData). Có 2 trang test tôi sinh: "[Test] Luận văn 35 trang" và cây "[Test] Screenplay — The Last Train" (1 gốc + 3 hồi + 26 cảnh).

## 2. Kiến trúc (file quan trọng)

| File | Vai trò |
| --- | --- |
| `Editor/DocumentController.swift` | Singleton. Sở hữu `NSTextStorage` + `NSLayoutManager` dùng chung; mọi lệnh định dạng; menu `/`; danh sách; khối; Enter/Tab/Backspace; media; slash panel; lưu (debounce 0,4s) |
| `Editor/PagedDocumentView.swift` | `PageTextView` (subclass NSTextView), `PageView`, `PagedDocumentView` (canvas), `EditorCanvasView` (host + scroll), `PagedEditor` (NSViewRepresentable). Hai bố cục: **Liên tục** (1 container, cột theo cửa sổ) và **Trang giấy rời** (nhiều container = nhiều trang) |
| `Editor/DocumentStorage.swift` | Lưu tài liệu = **NSKeyedArchiver không secure coding**; sửa chữa dữ liệu RTFD cũ; làm phẳng khối khi xuất |
| `Editor/DocumentIO.swift` | Nhập/xuất/in; `ExportHeader` (bìa + tiêu đề trước nội dung) |
| `Editor/SlashCommand.swift`, `SlashMenuPanel.swift` | Danh mục `/` và panel nổi (NSPanel **không được thành key**) |
| `Editor/FindInPage.swift`, `Views/FindBar.swift` | Tìm/thay thế trong trang (⌘F, ⌥⌘F, ⌘G, ⇧⌘G, ⌘E): `FindModel` + extension controller; tô sáng bằng **temporary attributes** của layout manager (không đụng tài liệu); menu Tìm thay thế nhóm `.textEditing` của SwiftUI |
| `Editor/CodeHighlighter.swift` | Tô màu mã regex; `NSTextBlock.isDecoration` |
| `Editor/EditorGlyphs.swift` | `NSLayoutManagerDelegate` dùng chung: ký tự ☐ ☑ ▸ ▾ thành **control glyph** rỗng (tự vẽ trong `PageTextView.drawMarkers`), chữ mang `.bnHidden` sinh glyph `.null` nên biến mất khỏi layout |
| `Editor/ToggleSections.swift` | Toggle kiểu Notion: mũi tên trong text là nguồn sự thật (▸ đóng / ▾ mở), `.bnHidden` được suy lại sau mỗi lần sửa (`refreshCollapsedRanges`), `expandToggles(containing:)` mở giúp khi ⌘F nhảy vào vùng đang gập |
| `Models/StoreBackup.swift` | Chép `default.store` sang `Backups/<ngày>` trước khi mở store (giữ 5 bản, tối đa 6 giờ/lần) |
| `Editor/MediaSupport.swift`, `MediaToolbar.swift` | YouTube/ảnh/link, cửa sổ xem trong app (WKWebView), thanh nổi khi chọn ảnh |
| `Editor/AppActions.swift` | Cầu nối menu → ContentView (closure) |
| `Views/ContentView.swift` | NavigationSplitView; sidebar / dashboard / editor; PageActions; export; link nội bộ |
| `Views/PageHeaderView.swift` | Đầu trang kiểu Notion (bìa, icon đè mép, tiêu đề, thẻ) — **overlay SwiftUI ngoài scroll view**, đồng bộ cuộn qua `HeaderLayout` |
| `Views/NoteEditorView.swift` | Toolbar + thanh tìm + editor + inspector + thanh trạng thái; overlay đầu trang dịch theo cuộn |
| `Views/DashboardView.swift`, `SidebarView.swift`, `TagViews.swift`, `PageInspector.swift`, `SettingsView.swift`, `FormatToolbar.swift`, `ColorPalette.swift`, `CoverControls.swift`, `CoverStyle.swift` | UI |
| `Models/Note.swift`, `Tag.swift`, `PageConfig.swift` | SwiftData + `Defaults` (UserDefaults) + đơn vị đo |
| `AppFlavor.swift` | Biết đang chạy bản nào (`isDev`, `name`, `version`) — đọc từ Info.plist, dùng cho tên cửa sổ và nhãn DEV |

Luồng lưu: gõ → `textDidChange` → `documentDidChangeFromTyping` (nhẹ) → 30 ms sau: phân trang/đánh số/mục lục/đếm → `onSave` (debounce 0,4 s) ghi `note.rtfData` (archive) + `note.content` (plain).

## 3. Quyết định thiết kế & bẫy đã dẫm phải (đừng làm lại)

1. **RTF phá khối**: RTF ghi `NSTextBlock` (trích dẫn/callout/mã) thành hàng bảng không đóng → nạp lại mọi đoạn sau đó nằm trong một ô, chỉ còn 2 trang. Vì vậy lưu bằng keyed archive; RTF chỉ để xuất và phải `flattenedForExport`. Dữ liệu cũ được `repairLegacyFrames`.
2. **Secure coding**: `NSParagraphStyle` từ chối `NSTextBlock` thường, `NSURL` trong attribute lỗi giải mã → archive không secure; link lưu dạng `NSString`.
3. **Khối sau khi qua RTF thành bảng 1 cột** → phân biệt bảng thật bằng `numberOfColumns > 1` (`isDecoration`).
4. **OpenKey** phát phím tổng hợp (keyCode 0, chuỗi backspace+ký tự). Menu `/` bắt Return/Tab/↑↓/Esc ở `keyDown` **và** `doCommandBy` **và** `shouldChangeTextIn` (3 tầng); so cả ký tự lẫn keyCode; `setMarkedText` không phát `textDidChange` nên gọi `updateSlashMenu` trực tiếp.
5. **Panel nổi chứa NSHostingView có thể giành key window** → subclass `canBecomeKey = false`.
6. **NSHostingView đặt trong NSScrollView không nhận click đúng** → đầu trang là overlay ngoài scroll view, dịch theo `scrollOffset`. Hosting view tự tạo trong AppKit **không kế thừa environment SwiftUI** (truyền `.modelContainer` tường minh nếu cần).
7. **`needsLayout` trên NSView thường trong scroll view không đáng tin** → gọi `relayout()` đồng bộ khi đổi chiều cao đầu trang.
8. **Đã bỏ zoom và "Chữ nhỏ" (2026-09-21, theo yêu cầu)**: scroll view luôn magnification 1, không pinch. Chỉ còn một tuỳ chọn bố cục như Notion: "Toàn chiều rộng". Đừng thêm lại zoom. `Note.smallText` vẫn còn trong model chỉ để store cũ mở được, không dùng.
9. Mép cột: mặc định 7,5 % cửa sổ mỗi bên, toàn chiều rộng 3 %. "Toàn chiều rộng" **lưu theo từng trang** (`Note.fullWidth`), mặc định trong Cài đặt.
10. Đơn vị: mặc định **inch**, lề 0,75 in; thước kẻ đã gỡ hẳn; đường biên lề/lưới chỉ ở chế độ giấy rời.
11. Hiệu năng: không dùng `String.count` trên tài liệu lớn; công việc nặng chạy trễ sau loạt phím (0,3 ms/phím ở 35 trang).
12. `Note.uid` (UUID) cho link nội bộ `bnote://page/<uid>`; migration cho cùng một default cho mọi hàng cũ → `wireCommands` gán lại uid trùng.
13. **Giao diện tiếng Anh từ 2026-09-23**: chuỗi UI viết thẳng tiếng Anh (chưa dùng String Catalog). Nhãn trong harness vẫn tiếng Việt — đó là output cho dev, đừng dịch. Số đo format bằng dấu chấm (`Unit.format`).
14. **KHÔNG dùng `lineHeightMultiple`**: nó nở hộp dòng và dìm chữ xuống đáy hộp, trong khi con trỏ vẽ theo phần chữ → nhìn như chữ lệch khỏi con trỏ (bug 2026-09-23, user báo gắt). Giãn dòng phải đặt bằng `lineSpacing` (khoảng thêm *dưới* dòng): `EditorDefaults.lineSpacing(for:)`, dùng ở `bodyAttributes`, `apply(style:)`, `setLineHeight`, `CodeHighlighter`. `apply(style:)` trước đây còn zero hoá `lineHeightMultiple` nên đổi kiểu là chữ nhảy. Harness `caret` canh chừng: baseline phải bằng ascender (+ `paragraphSpacingBefore`, trừ đoạn đầu tài liệu vì AppKit bỏ qua).
15. **Cỡ chữ theo Notion (2026-09-23)**: body 16, H1 30, H2 24, H3 20, Title 40, giãn dòng 1.5, `listIndent` 26. `TextStyle.detect` đã chỉnh ngưỡng theo scale mới — đổi cỡ thì phải sửa cả hai chỗ, nếu không kiểu chữ nhận diện sai sau khi nạp lại RTF.
16. **"Nhảy chữ" ngang**: hộp marker rộng hơn tab stop của danh sách thì chữ bị đẩy sang tab mặc định kế tiếp → dòng nhảy ngang (thấy rõ ở to-do cỡ heading). `EditorMarkers.width` bị chặn ở `listIndent - 6`, `boxSide` chặn theo `width`. Harness `marks` kiểm tra mọi dòng danh sách bắt đầu cùng một toạ độ.
17. **Cột đọc chặn ở 900pt** (`Metrics.maximumColumn`) khi không bật Toàn chiều rộng, để full screen trên màn lớn không thành dòng 1700pt.
18. **Sidebar tự vẽ selection** (`SidebarRow`): `DisclosureGroup` trong `List(selection:)` không hiện highlight ở hàng cha, còn selection của List thì xanh đậm và không có tag cho trạng thái "đang ở Overview". Nên bỏ hẳn `List(selection:)`: danh sách phẳng (`visibleRows`), mỗi hàng dùng `SidebarRow` — cùng lề trái (ô twisty 14pt luôn được giữ chỗ, icon rộng 16pt), cùng chiều cao một dòng, nền xám `primary.opacity(0.11)` khi chọn và `0.05` khi hover. **Đánh đổi:** không còn điều hướng bằng phím ↑/↓ trong sidebar; nếu làm lại thì phải tự xử lý `onMoveCommand`.
    Kiểm chứng bằng `scripts/test.sh sidebar` → ảnh `bnote-sidebar-page.png` / `-overview.png`.
19. **Marker vẽ tay**: checkbox/toggle vẫn là **ký tự trong text** (☐ ☑ ▸ ▾ + tab) để plain-text, tìm kiếm và export không đổi; phần nhìn do `EditorMarkers` vẽ trong toạ độ **flipped** (+y hướng xuống — dấu tick từng bị vẽ ngược vì quên điều này).
20. **Đệ quy delegate**: gọi `textView.shouldChangeText(in:replacementString:)` với đúng chuỗi `"\n"` bên trong `textView(_:shouldChangeTextIn:)` sẽ gọi lại chính nó → tràn stack. Đặt cờ `isInsertingBreak` trước khi gọi (nhánh Enter của toggle từng crash vì việc này).
21. **SwiftUI co màn hình rồi canh giữa**: `DashboardView` khi không có trang chỉ cao ~334pt, NavigationSplitView canh giữa theo chiều dọc → dải trắng lớn phía trên tiêu đề (bug 2026-09-22). Màn hình toàn khung phải tự `.frame(maxWidth: .infinity, maxHeight: .infinity)`; `ContentUnavailableView` **không** tự giãn. Harness `dash` canh chừng việc này.
22. Log chẩn đoán Debug: `~/Library/Containers/com.hoangson.BNote/Data/Library/Application Support/bnote-input.log` (chỉ build Debug).

## 4. Kiểm thử

Không GUI-test được (osascript không có Accessibility). Dùng harness headless compile thẳng bằng `swiftc`, dựng cửa sổ thật, bơm `NSEvent`:

```bash
scripts/test.sh            # editor (~110) + keyboard (~95) + ui (~25) assertion
scripts/test.sh dash [n]   # Tổng quan với n trang phải lấp đầy cửa sổ (ảnh bnote-dash-n.png)
scripts/test.sh marks      # marker không đè chữ + cột theo cửa sổ (ảnh bnote-marks.png)
scripts/test.sh sidebar    # ảnh sidebar ở hai trạng thái chọn (canh lề, màu selection)
scripts/test.sh caret      # chữ phải thẳng với con trỏ ở mọi kiểu đoạn
scripts/test.sh perf       # đo độ trễ đầu trang khi bật Toàn chiều rộng (không assert)
scripts/test.sh thesis     # sinh luận văn 35 trang vào store (thoát app trước)
scripts/test.sh tree       # sinh cây kịch bản
```

Harness `ui` in ảnh `bnote-editor*.png`, `bnote-find.png` trong `$TMPDIR` để nhìn tận mắt. Trong `ui` có 1 check "cửa sổ chính vẫn là key" luôn FAIL vì harness không activate được app — bỏ qua. **`ui` chạy từ shell của Claude (không có phiên GUI) sẽ treo ở bước "bấm vào đầu trang"** (vòng tracking chuột của NSTextView chờ mouseUp thật) — chạy nó trong Terminal của app (`mcp__terminal__run_in_terminal`) hoặc chỉ đọc log tới trước bước đó. Harness `editor` không có cửa sổ nên `undoManager` nil — check undo phải đặt ở `keyboard`.

## 5. Quy ước

- UI tiếng Việt; commit message tiếng Việt, kết bằng `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`; email commit repo này `hoangson2758@gmail.com`.
- Xcode project dùng synchronized group: thêm file vào `BNote/` là tự vào target, **không** sửa pbxproj. `Tests/` nằm ngoài target.
- Build debug: `xcodebuild -project BNote.xcodeproj -scheme BNote -configuration Debug -derivedDataPath build build`; chạy: `open build/Build/Products/Debug/BNote.app`.
- User hay gửi ảnh chụp và nói ngắn ("sai rồi", "lỗi đây"); ưu tiên tái hiện bằng harness trước khi sửa, và **cập nhật bản Dev + mở lại** sau mỗi lần sửa vì họ test ngay.
- Trước khi kết luận "mất dữ liệu", hỏi lại: có lần user tự xoá hết trang rồi báo "trang tổng quan bị lỗi".

## 6. Việc còn dở / ý tưởng kế tiếp

- Notarize khi có tài khoản Developer trả phí (nối vào `scripts/package.sh`).
- Kéo thả sắp xếp trang trong sidebar; bảng có chỉnh cột; link preview cho web thường.
- ⌘F đã xong (tìm/thay thế, Aa, Enter/⇧Enter, Esc chọn kết quả hiện tại). Chưa có: tìm không dấu, tìm toàn bộ workspace.
- Toggle section đã xong (`/toggle`, bấm mũi tên, Enter tạo mục con, Tab đổi cấp, ⌘F tự mở). Chưa có: kéo thả nội dung vào toggle, và khi **xuất PDF/RTF** thì phần gập vẫn hiện đầy đủ kèm ký tự ▸/▾.
- Checkbox vẽ tay (ô bo góc, tick trắng nền accent). Có thể làm thêm: hover đổi màu, animation khi tích.
- Xuất PDF chưa vẽ nền khối mã (khối chỉ hiện trong layout của app).
- Khi đổi tên trang qua menu chuột phải, ô sửa hiện tại chỗ (đã bỏ double-click vì làm hỏng click chọn).
