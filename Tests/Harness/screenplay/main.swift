import AppKit
import SwiftData

setvbuf(stdout, nil, _IOLBF, 0)
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

var failures: [String] = []
func check(_ label: String, _ ok: Bool, _ detail: String = "") {
    print(ok ? "  ok   \(label)" : "  FAIL \(label) \(detail)")
    if !ok { failures.append(label) }
}
func pump(_ s: TimeInterval = 0.05) { RunLoop.main.run(until: Date().addingTimeInterval(s)) }
func timed<T>(_ label: String, _ body: () -> T) -> T {
    let t = Date(); let r = body(); print(String(format: "  ⏱ %@: %.0f ms", label, Date().timeIntervalSince(t) * 1000)); return r
}

// MARK: - Content generator (Vietnamese screenplay)

let actions = [
    "Mưa quất vào cửa kính. Ánh đèn neon đỏ hắt lên mặt bàn ướt.",
    "Cô ngồi thẳng, hai tay ôm cốc trà đã nguội, mắt không rời cánh cửa.",
    "Tiếng còi tàu từ xa. Một con mèo nhảy khỏi thùng rác, biến vào bóng tối.",
    "Anh bước vào, áo khoác dính mưa, tay cầm chiếc phong bì nhàu nát.",
    "Chiếc đồng hồ treo tường dừng ở 11 giờ 47. Không ai để ý.",
    "Máy quay lia chậm qua những khuôn mặt trong quán: mệt mỏi, chờ đợi, giả vờ không nghe.",
    "Ngoài cửa sổ, đoàn tàu cuối ngày lướt qua, ánh đèn toa xe quét lên trần nhà.",
    "Cô bật cười, rồi im bặt như thể vừa nhớ ra điều gì.",
    "Bàn tay anh run nhẹ khi đặt phong bì xuống bàn.",
    "Một người phục vụ đi ngang, đặt hoá đơn xuống mà không nói gì.",
]
let lines = [
    "Anh đến muộn.", "Tàu dừng ở ga Bình Triệu. Anh phải đi bộ.", "Em không hỏi tàu.",
    "Có chuyện gì thế?", "Đọc đi rồi biết.", "Em không muốn đọc thứ anh không dám nói.",
    "Không phải là không dám.", "Vậy là gì?", "Là chưa tìm được cách.",
    "Cách nào cũng được, miễn là thật.", "Thật thì đau.", "Đau còn hơn là không biết.",
    "Bố em gọi hôm qua.", "Ông ấy nói gì?", "Ông ấy hỏi khi nào anh về.",
    "Anh chưa biết.", "Em biết.", "Thế thì nói cho anh.",
]
let names = ["LINH", "MINH", "BÀ HOA", "ÔNG TƯ", "NGƯỜI PHỤC VỤ", "TÀI"]
let places = ["NỘI. QUÁN CÀ PHÊ GA — ĐÊM", "NGOẠI. SÂN GA BÌNH TRIỆU — MƯA", "NỘI. CĂN HỘ CỦA LINH — SÁNG", "NGOẠI. BỜ SÔNG — HOÀNG HÔN", "NỘI. XE BUÝT — TRƯA", "NỘI. NHÀ ÔNG TƯ — TỐI", "NGOẠI. CHỢ ĐÊM — ĐÊM", "NỘI. BỆNH VIỆN, HÀNH LANG — SÁNG SỚM"]
var seed: UInt64 = 7
func rnd(_ n: Int) -> Int { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Int((seed >> 33) % UInt64(n)) }
func action(_ n: Int) -> String { (0..<n).map { _ in actions[rnd(actions.count)] }.joined(separator: " ") }

enum Block { case title(String), h1(String), h2(String), h3(String), body(String), bullets([String]), numbers([String]), quote(String), callout(String), code(String), todo([String]), character(String), dialogue(String), parenthetical(String) }
var blocks: [Block] = []
blocks.append(.title("CHUYẾN TÀU CUỐI"))
blocks.append(.body("Kịch bản phim truyện · Bản nháp thứ ba · Tác giả: Hoàng Sơn"))
blocks.append(.callout("Logline: Một đêm mưa ở ga Bình Triệu, hai người từng yêu nhau có đúng chín mươi phút trước chuyến tàu cuối để quyết định có nói ra sự thật hay không."))
blocks.append(.h1("Nhân vật"))
blocks.append(.bullets(["LINH — 29 tuổi, biên tập viên, nói ít nhưng nhớ mọi thứ.", "MINH — 31 tuổi, kỹ sư đường sắt, hay đến muộn.", "BÀ HOA — chủ quán cà phê ga, biết nhiều hơn bà nói.", "ÔNG TƯ — bố của Linh, đang nằm viện.", "TÀI — bạn của Minh, xuất hiện ở hồi ba."]))
blocks.append(.h1("Ghi chú của đạo diễn"))
blocks.append(.quote("Toàn bộ phim diễn ra trong một đêm. Không nhạc nền cho đến cảnh cuối."))
blocks.append(.todo(["Chốt lại đoạn kết với nhà sản xuất", "Kiểm tra bản quyền bài hát ở cảnh 14", "Rút ngắn hồi hai 3 trang"]))
let acts = [("HỒI MỘT — CHÍN MƯƠI PHÚT", 9), ("HỒI HAI — PHONG BÌ", 11), ("HỒI BA — CHUYẾN TÀU CUỐI", 9)]
var sceneNumber = 0
for (act, sceneCount) in acts {
    blocks.append(.h1(act))
    blocks.append(.body(action(2)))
    for _ in 0..<sceneCount {
        sceneNumber += 1
        blocks.append(.h2("CẢNH \(sceneNumber) — \(places[rnd(places.count)])"))
        blocks.append(.body(action(4)))
        for _ in 0..<(7 + rnd(4)) {
            blocks.append(.character(names[rnd(2)]))
            if rnd(3) == 0 { blocks.append(.parenthetical(["(ngập ngừng)", "(không nhìn anh)", "(cười nhạt)", "(sau một lúc)"][rnd(4)])) }
            blocks.append(.dialogue(lines[rnd(lines.count)]))
        }
        blocks.append(.body(action(3)))
        if sceneNumber % 4 == 0 { blocks.append(.h3("Chuyển cảnh")); blocks.append(.body("CẮT SANG:")) }
        if sceneNumber == 7 { blocks.append(.callout("Chỉ dẫn quay: một cú máy dài, không cắt, theo Linh từ quầy ra sân ga.")) }
        if sceneNumber == 11 { blocks.append(.numbers(["Đạo cụ: phong bì nhàu, vé tàu 23:50, chiếc ô gãy", "Phục trang: Minh mặc lại áo khoác của cảnh 1", "Âm thanh: tiếng mưa giảm dần từ giữa cảnh"])) }
    }
}
blocks.append(.h1("Kết"))
blocks.append(.body(action(3)))
blocks.append(.quote("MỜ DẦN. HẾT."))

// MARK: - Build in the real editor

let controller = DocumentController.shared
let host = EditorCanvasView(controller: controller)
let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1000, height: 800), styleMask: [.titled], backing: .buffered, defer: false)
window.contentView = host; host.frame = window.contentView!.bounds; host.layoutSubtreeIfNeeded(); window.orderFront(nil)
Defaults.register()
controller.canvasOptions = Defaults.canvasOptions
controller.load(data: nil, plainText: "", config: Defaults.pageConfig); pump()
let tv = controller.activeTextView!
window.makeFirstResponder(tv)

print("== soạn luận văn ==")
timed("dựng \(blocks.count) khối") {
    for block in blocks {
        let start = controller.textStorage.length
        func put(_ text: String) {
            tv.setSelectedRange(NSRange(location: controller.textStorage.length, length: 0))
            controller.insertPlainText(text + "\n")
        }
        func select() { tv.setSelectedRange(NSRange(location: start, length: max(0, controller.textStorage.length - start - 1))) }
        switch block {
        case .title(let t): put(t); select(); controller.apply(style: .title)
        case .h1(let t): put(t); select(); controller.apply(style: .heading1)
        case .h2(let t): put(t); select(); controller.apply(style: .heading2)
        case .h3(let t): put(t); select(); controller.apply(style: .heading3)
        case .body(let t): put(t); select(); controller.apply(style: .body)
        case .bullets(let items): put(items.joined(separator: "\n")); select(); controller.apply(style: .body); controller.toggleList(.bullet)
        case .numbers(let items): put(items.joined(separator: "\n")); select(); controller.apply(style: .body); controller.toggleList(.numbered)
        case .todo(let items): put(items.joined(separator: "\n")); select(); controller.apply(style: .body); controller.toggleList(.todo)
        case .quote(let t): put(t); select(); controller.apply(style: .body); tv.setSelectedRange(NSRange(location: start, length: 0)); controller.insertQuote()
        case .callout(let t): put(t); select(); controller.apply(style: .body); tv.setSelectedRange(NSRange(location: start, length: 0)); controller.insertCallout()
        case .code(let t): put(t); select(); controller.apply(style: .code)
        case .character(let t): put(t); select(); controller.apply(style: .body); controller.toggleTrait(.boldFontMask); controller.setAlignment(.center)
        case .dialogue(let t): put(t); select(); controller.apply(style: .body); controller.changeIndent(by: EditorDefaults.tabIndent * 2)
        case .parenthetical(let t): put(t); select(); controller.apply(style: .body); controller.toggleTrait(.italicFontMask); controller.changeIndent(by: EditorDefaults.tabIndent * 3)
        }
        tv.setSelectedRange(NSRange(location: controller.textStorage.length, length: 0))
        tv.typingAttributes = EditorDefaults.bodyAttributes
    }
}
pump(0.2)
host.canvas.updatePagination()
let words = controller.wordCount
print("  từ: \(words) · ký tự: \(controller.characterCount) · trang: \(controller.pageCount) · mục lục: \(controller.outline.count)")
check("đủ ~20 trang", controller.pageCount >= 16 && controller.pageCount <= 26, "got \(controller.pageCount)")
check("mục lục có đủ hồi", controller.outline.filter { $0.level == 1 }.count >= 5)

print("== độ trễ gõ phím ở tài liệu lớn ==")
func measureTyping(at location: Int, label: String) {
    tv.setSelectedRange(NSRange(location: location, length: 0))
    var worst = 0.0, total = 0.0
    for ch in "Thêm một câu mới vào giữa tài liệu để đo độ trễ." {
        let t = Date()
        tv.insertText(String(ch), replacementRange: tv.selectedRange())
        let dt = Date().timeIntervalSince(t) * 1000
        worst = max(worst, dt); total += dt
    }
    print(String(format: "  %@: trung bình %.1f ms/phím, tệ nhất %.1f ms", label, total / 49, worst))
    check("\(label): gõ mượt (< 40 ms/phím)", total / 49 < 40, String(format: "%.1f ms", total / 49))
}
do {
    tv.setSelectedRange(NSRange(location: controller.textStorage.length / 2, length: 0))
    tv.insertText("x", replacementRange: tv.selectedRange())
    func t(_ label: String, _ body: () -> Void) { let d = Date(); body(); print(String(format: "   %@: %.1f ms", label, Date().timeIntervalSince(d) * 1000)) }
    t("updatePagination", { host.canvas.updatePagination() })
    t("renumberLists", { controller.renumberListsForProfiling() })
    t("outline+counts", { controller.refreshDerivedStateForProfiling() })
    t("highlightCode", { controller.highlightCode(around: controller.textStorage.length / 2) })
    t("updateSlashMenu", { controller.updateSlashMenu() })
}
measureTyping(at: controller.textStorage.length, label: "cuối tài liệu")
measureTyping(at: controller.textStorage.length / 2, label: "giữa tài liệu")

print("== lưu, nạp lại, xuất ==")
let snap = timed("snapshot RTFD") { controller.snapshot() }
print("  kích thước: \(snap.data.count / 1024) KB")
timed("nạp lại") { controller.load(data: snap.data, plainText: "", config: Defaults.pageConfig); pump(0.1); host.canvas.updatePagination() }
do {
    let lm = controller.layoutManager
    let last = lm.textContainers.last!
    print("  DEBUG pages=\(host.canvas.pages.count) containers=\(lm.textContainers.count) glyphs=\(lm.numberOfGlyphs) chars=\(controller.textStorage.length) lastRange=\(lm.glyphRange(for: last))")
    for (i, c) in lm.textContainers.enumerated() { print("   c\(i): \(lm.glyphRange(for: c)) size=\(c.size)") }
    var runs: [(NSRange, String)] = []
    controller.textStorage.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: controller.textStorage.length)) { v, r, _ in
        let blocks = (v as? NSParagraphStyle)?.textBlocks ?? []
        let desc = blocks.map { b -> String in
            if let t = b as? NSTextTableBlock { return "table(\(ObjectIdentifier(t.table).hashValue % 1000) cols=\(t.table.numberOfColumns) row=\(t.startingRow))" }
            return "block"
        }.joined(separator: ",")
        runs.append((r, desc))
    }
    print("  DEBUG paragraphStyle runs: \(runs.count)")
    for (r, d) in runs.prefix(12) { print("   \(r) \(d.isEmpty ? "-" : d)") }
    let tables = Set(runs.compactMap { $0.1.isEmpty ? nil : $0.1 })
    print("  DEBUG distinct block descs: \(tables.count)")
}
check("nạp lại giữ số trang", abs(controller.pageCount - 20) <= 6, "got \(controller.pageCount)")
check("nạp lại giữ mục lục", controller.outline.count >= 20, "got \(controller.outline.count)")
let outDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("bnote-screenplay")
let header = ExportHeader(title: "[Test] Kịch bản phim — Chuyến tàu cuối", subtitle: "Ba hồi, 29 cảnh", cover: CoverStyle.slate.image(size: NSSize(width: 1200, height: 400)), coverFocus: 0.5, icon: "🎬")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
for format in [DocumentFormat.pdf, .docx, .markdown] {
    let url = outDir.appendingPathComponent("kich-ban.\(format.fileExtension)")
    let ok = timed("xuất \(format.fileExtension)") { (try? DocumentIO.write(attributed: controller.attributedCopy, format: format, to: url, config: controller.config, header: header)) != nil }
    let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
    check("xuất \(format.fileExtension) (\(size / 1024) KB)", ok && size > 1000)
}
print("  thư mục: \(outDir.path)")

// MARK: - Write into the app's own database

print("== ghi vào database của app ==")
let storeURL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Containers/com.hoangson.BNote/Data/Library/Application Support/default.store")
do {
    let config = ModelConfiguration(url: storeURL)
    let container = try ModelContainer(for: Note.self, Tag.self, configurations: config)
    try MainActor.assumeIsolated {
        let context = container.mainContext
        let existing = try context.fetch(FetchDescriptor<Note>())
        for old in existing where old.title.hasPrefix("[Test] Kịch bản") { context.delete(old) }
        let note = Note(title: "[Test] Kịch bản phim — Chuyến tàu cuối", sortIndex: (existing.map(\.sortIndex).max() ?? 0) + 1)
        note.icon = "🎬"
        note.tags = ["kịch bản", "test"]
        note.coverStyle = CoverStyle.slate.rawValue
        note.subtitle = "Ba hồi, 29 cảnh — sinh tự động để kiểm tra biên tập kịch bản"
        note.pageConfig = Defaults.pageConfig
        note.rtfData = snap.data
        note.content = snap.plainText
        context.insert(note)
        TagStore.ensure("kịch bản", in: context)?.color = .red
        TagStore.ensure("test", in: context)
        try context.save()
    }
    check("đã ghi trang vào app", true)
} catch {
    check("đã ghi trang vào app", false, "\(error)")
}

print(failures.isEmpty ? "\nTẤT CẢ ĐỀU ĐẠT" : "\nTHẤT BẠI (\(failures.count)): \(failures.joined(separator: " | "))")
exit(failures.isEmpty ? 0 : 1)
