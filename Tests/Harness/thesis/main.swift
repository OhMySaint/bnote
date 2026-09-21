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

// MARK: - Content generator (Vietnamese IT thesis)

let sentences = [
    "Trong bối cảnh chuyển đổi số diễn ra mạnh mẽ, việc xây dựng các hệ thống phần mềm có khả năng mở rộng trở thành yêu cầu cấp thiết đối với mọi tổ chức.",
    "Kiến trúc hướng dịch vụ cho phép tách rời các thành phần nghiệp vụ, từ đó giảm sự phụ thuộc lẫn nhau và tăng khả năng bảo trì của hệ thống.",
    "Kết quả thực nghiệm cho thấy phương pháp đề xuất cải thiện thời gian phản hồi trung bình khoảng 27% so với phương án cơ sở.",
    "Tuy nhiên, chi phí triển khai ban đầu và độ phức tạp vận hành là hai rào cản chính cần được cân nhắc kỹ lưỡng.",
    "Nghiên cứu này kế thừa các công trình trước đó về tối ưu hoá truy vấn và mở rộng sang bài toán xử lý dữ liệu theo luồng.",
    "Mô hình được huấn luyện trên tập dữ liệu gồm hơn hai triệu bản ghi thu thập trong vòng mười tám tháng.",
    "Việc chuẩn hoá dữ liệu đầu vào đóng vai trò quyết định đối với độ ổn định của toàn bộ quy trình.",
    "Chúng tôi đánh giá hệ thống theo ba tiêu chí: độ chính xác, độ trễ và mức tiêu thụ tài nguyên.",
    "Các phát hiện này gợi mở hướng nghiên cứu tiếp theo về cơ chế tự thích nghi của hệ thống khi tải thay đổi đột ngột.",
    "Bảng số liệu dưới đây tổng hợp kết quả của năm kịch bản thử nghiệm với cấu hình phần cứng giống nhau.",
    "Mỗi thành phần được đóng gói thành một dịch vụ độc lập, giao tiếp qua giao thức HTTP với định dạng JSON.",
    "Để đảm bảo tính tái lập, toàn bộ mã nguồn và cấu hình thí nghiệm được công bố kèm theo luận văn.",
]
var seed: UInt64 = 42
func rnd(_ n: Int) -> Int { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Int((seed >> 33) % UInt64(n)) }
func paragraph(_ count: Int) -> String { (0..<count).map { _ in sentences[rnd(sentences.count)] }.joined(separator: " ") }

enum Block { case title(String), h1(String), h2(String), h3(String), body(String), bullets([String]), numbers([String]), quote(String), callout(String), code(String), todo([String]) }
var blocks: [Block] = []
blocks.append(.title("Xây dựng nền tảng xử lý dữ liệu theo luồng cho hệ thống thương mại điện tử"))
blocks.append(.body("Luận văn thạc sĩ · Ngành Khoa học máy tính · Học viên: Hoàng Sơn · Người hướng dẫn: PGS.TS. Nguyễn Văn A"))
blocks.append(.h1("Lời cảm ơn"))
blocks.append(.body(paragraph(6)))
blocks.append(.h1("Tóm tắt"))
blocks.append(.body(paragraph(8)))
blocks.append(.callout("Từ khoá: xử lý luồng, kiến trúc vi dịch vụ, khả năng mở rộng, độ trễ thấp."))
let chapters = ["Giới thiệu", "Cơ sở lý thuyết và các nghiên cứu liên quan", "Phân tích và thiết kế hệ thống", "Hiện thực hoá", "Thực nghiệm và đánh giá", "Kết luận và hướng phát triển"]
for (ci, ch) in chapters.enumerated() {
    blocks.append(.h1("Chương \(ci + 1). \(ch)"))
    blocks.append(.body(paragraph(5)))
    for si in 1...4 {
        blocks.append(.h2("\(ci + 1).\(si). Mục \(si) của chương \(ci + 1)"))
        blocks.append(.body(paragraph(7)))
        blocks.append(.body(paragraph(6)))
        if si % 2 == 1 { blocks.append(.bullets((1...4).map { "Luận điểm \($0): " + sentences[rnd(sentences.count)] })) }
        else { blocks.append(.numbers((1...4).map { "Bước \($0): " + sentences[rnd(sentences.count)] })) }
        for ti in 1...2 {
            blocks.append(.h3("\(ci + 1).\(si).\(ti). Tiểu mục"))
            blocks.append(.body(paragraph(6)))
        }
        if ci == 3 && si <= 2 {
            blocks.append(.code("struct Event: Codable {\n    let id: UUID\n    let timestamp: Date\n    let payload: [String: String]\n}\n\nfunc process(_ events: [Event]) -> Int {\n    // đếm sự kiện hợp lệ\n    return events.filter { !$0.payload.isEmpty }.count\n}"))
        }
        if si == 3 { blocks.append(.quote(sentences[rnd(sentences.count)])) }
    }
    if ci == 4 { blocks.append(.todo(["Chạy lại kịch bản 3 với 8 lõi", "Bổ sung biểu đồ độ trễ p99", "Kiểm tra lại số liệu bảng 5.2"])) }
}
blocks.append(.h1("Tài liệu tham khảo"))
blocks.append(.numbers((1...18).map { "Tác giả \($0), \"Tiêu đề công trình số \($0)\", Tạp chí Khoa học máy tính, 20\(10 + $0 % 15)." }))

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
        }
        tv.setSelectedRange(NSRange(location: controller.textStorage.length, length: 0))
        tv.typingAttributes = EditorDefaults.bodyAttributes
    }
}
pump(0.2)
host.canvas.updatePagination()
let words = controller.wordCount
print("  từ: \(words) · ký tự: \(controller.characterCount) · trang: \(controller.pageCount) · mục lục: \(controller.outline.count)")
check("đủ ~35 trang", controller.pageCount >= 30 && controller.pageCount <= 45, "got \(controller.pageCount)")
check("mục lục có đủ chương", controller.outline.filter { $0.level == 1 }.count >= 8)

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
check("nạp lại giữ số trang", abs(controller.pageCount - 35) <= 10, "got \(controller.pageCount)")
check("nạp lại giữ mục lục", controller.outline.count >= 40, "got \(controller.outline.count)")
let outDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("bnote-thesis")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
for format in [DocumentFormat.pdf, .docx, .markdown] {
    let url = outDir.appendingPathComponent("luan-van.\(format.fileExtension)")
    let ok = timed("xuất \(format.fileExtension)") { (try? DocumentIO.write(attributed: controller.attributedCopy, format: format, to: url, config: controller.config)) != nil }
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
        for old in existing where old.title.hasPrefix("[Test] Luận văn") { context.delete(old) }
        let note = Note(title: "[Test] Luận văn 35 trang", sortIndex: (existing.map(\.sortIndex).max() ?? 0) + 1)
        note.icon = "🎓"
        note.tags = ["luận văn", "test"]
        note.coverStyle = CoverStyle.dusk.rawValue
        note.subtitle = "Tài liệu sinh tự động để kiểm tra hiệu năng và phân trang"
        note.pageConfig = Defaults.pageConfig
        note.rtfData = snap.data
        note.content = snap.plainText
        context.insert(note)
        TagStore.ensure("luận văn", in: context)?.color = .purple
        TagStore.ensure("test", in: context)
        try context.save()
    }
    check("đã ghi trang vào app", true)
} catch {
    check("đã ghi trang vào app", false, "\(error)")
}

print(failures.isEmpty ? "\nTẤT CẢ ĐỀU ĐẠT" : "\nTHẤT BẠI (\(failures.count)): \(failures.joined(separator: " | "))")
exit(failures.isEmpty ? 0 : 1)
