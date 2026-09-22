import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

var failures: [String] = []
func check(_ label: String, _ condition: Bool, _ detail: String = "") {
    if condition {
        print("  ok   \(label)")
    } else {
        print("  FAIL \(label) \(detail)")
        failures.append(label)
    }
}

let controller = DocumentController.shared
// Pagination checks need the paper layout; the app defaults to the Notion column.
var paperOptions = CanvasOptions()
paperOptions.continuous = false
controller.canvasOptions = paperOptions
let canvas = PagedDocumentView(controller: controller)
canvas.frame = NSRect(x: 0, y: 0, width: 900, height: 1200)
canvas.applyConfig(controller.config, options: paperOptions)

print("== pagination ==")
controller.load(data: nil, plainText: "", config: PageConfig())
check("bắt đầu 1 trang", canvas.pageCount == 1, "got \(canvas.pageCount)")

let long = (1...400).map { "Dòng số \($0): nội dung thử nghiệm phân trang của BNote." }.joined(separator: "\n")
controller.load(data: nil, plainText: long, config: PageConfig())
canvas.updatePagination()
let manyPages = canvas.pageCount
check("văn bản dài tràn nhiều trang", manyPages > 3, "got \(manyPages)")

controller.load(data: nil, plainText: "ngắn", config: PageConfig())
canvas.updatePagination()
check("rút gọn lại còn 1 trang", canvas.pageCount == 1, "got \(canvas.pageCount)")

var a5 = PageConfig(paper: .a5, margins: PageMargins(uniform: 36))
controller.load(data: nil, plainText: long, config: PageConfig())
canvas.updatePagination()
let a4Pages = canvas.pageCount
controller.config = a5
canvas.applyConfig(a5, options: paperOptions)
check("đổi khổ giấy A5 làm tăng số trang", canvas.pageCount > a4Pages, "a4=\(a4Pages) a5=\(canvas.pageCount)")

print("== styles & outline ==")
controller.load(data: nil, plainText: "Chương một\nnội dung\nChương hai\nnội dung", config: PageConfig())
let tv = controller.activeTextView!
tv.setSelectedRange(NSRange(location: 0, length: 10))
controller.apply(style: .heading1)
tv.setSelectedRange(NSRange(location: 20, length: 10))
controller.apply(style: .heading2)
check("mục lục bắt 2 đầu mục", controller.outline.count == 2, "got \(controller.outline.map(\.text))")
check("cấp đầu mục đúng", controller.outline.map(\.level) == [1, 2], "got \(controller.outline.map(\.level))")

print("== bold / font ==")
tv.setSelectedRange(NSRange(location: 11, length: 7))
controller.toggleTrait(.boldFontMask)
let boldFont = controller.textStorage.attribute(.font, at: 11, effectiveRange: nil) as? NSFont
check("in đậm áp dụng", NSFontManager.shared.traits(of: boldFont!).contains(.boldFontMask))
controller.setFontFamily("Georgia")
let georgia = controller.textStorage.attribute(.font, at: 11, effectiveRange: nil) as? NSFont
check("đổi phông giữ nguyên đậm", georgia?.familyName == "Georgia" && NSFontManager.shared.traits(of: georgia!).contains(.boldFontMask), "got \(georgia?.familyName ?? "nil")")
controller.setFontSize(22)
let sized = controller.textStorage.attribute(.font, at: 11, effectiveRange: nil) as? NSFont
check("đổi cỡ chữ", sized?.pointSize == 22, "got \(sized?.pointSize ?? -1)")

print("== lists ==")
controller.load(data: nil, plainText: "một\nhai\nba", config: PageConfig())
let tv2 = controller.activeTextView!
tv2.setSelectedRange(NSRange(location: 0, length: controller.textStorage.length))
controller.toggleList(.numbered)
let numbered = controller.textStorage.string
check("đánh số 1..3", numbered.contains("1.\tmột") && numbered.contains("2.\thai") && numbered.contains("3.\tba"), "got \(numbered.debugDescription)")

tv2.setSelectedRange(NSRange(location: 0, length: controller.textStorage.length))
controller.toggleList(.bullet)
check("chuyển sang chấm đầu dòng", controller.textStorage.string.contains("•\tmột"), "got \(controller.textStorage.string.debugDescription)")

tv2.setSelectedRange(NSRange(location: 0, length: controller.textStorage.length))
controller.toggleList(.bullet)
check("bấm lần nữa thì bỏ danh sách", !controller.textStorage.string.contains("•\t"), "got \(controller.textStorage.string.debugDescription)")

print("== thụt lề danh sách đồng nhất ==")
controller.load(data: nil, plainText: "một\nhai\nba", config: PageConfig())
let tvIndent = controller.activeTextView!
tvIndent.setSelectedRange(NSRange(location: 0, length: controller.textStorage.length))
controller.toggleList(.bullet)
var indents: [CGFloat] = []
var tabs: [CGFloat] = []
let listString = controller.textStorage.string as NSString
var cursor = 0
while cursor < listString.length {
    let para = listString.paragraphRange(for: NSRange(location: cursor, length: 0))
    let style = controller.textStorage.attribute(.paragraphStyle, at: para.location, effectiveRange: nil) as? NSParagraphStyle
    indents.append(style?.headIndent ?? -1)
    tabs.append(style?.tabStops.first?.location ?? -1)
    cursor = para.upperBound
}
check("mọi mục có cùng headIndent", Set(indents).count == 1 && indents.first == EditorDefaults.listIndent, "got \(indents)")
check("mọi mục có cùng tab stop", Set(tabs).count == 1 && tabs.first == EditorDefaults.listIndent, "got \(tabs)")

print("== enter tiếp tục danh sách ==")
controller.load(data: nil, plainText: "", config: PageConfig())
let tv3 = controller.activeTextView!
controller.textStorage.setAttributedString(NSAttributedString(string: "1.\tviệc A", attributes: EditorDefaults.bodyAttributes))
tv3.setSelectedRange(NSRange(location: controller.textStorage.length, length: 0))
_ = controller.textView(tv3, shouldChangeTextIn: NSRange(location: controller.textStorage.length, length: 0), replacementString: "\n")
check("Enter tạo mục 2.", controller.textStorage.string.hasSuffix("2.\t"), "got \(controller.textStorage.string.debugDescription)")
let emptyItemLocation = controller.textStorage.length
_ = controller.textView(tv3, shouldChangeTextIn: NSRange(location: emptyItemLocation, length: 0), replacementString: "\n")
check("Enter trên mục rỗng thì thoát danh sách", !controller.textStorage.string.hasSuffix("2.\t"), "got \(controller.textStorage.string.debugDescription)")

print("== rtfd round-trip ==")
controller.load(data: nil, plainText: "Tiêu đề\nnội dung có dấu tiếng Việt", config: PageConfig())
let tv4 = controller.activeTextView!
tv4.setSelectedRange(NSRange(location: 0, length: 7))
controller.apply(style: .heading1)
controller.setTextColor(.systemRed)
let snap = controller.snapshot()
check("snapshot có dữ liệu", snap.data.count > 100, "got \(snap.data.count) bytes")
controller.load(data: snap.data, plainText: "", config: PageConfig())
check("nạp lại giữ nguyên chữ", controller.textStorage.string.contains("nội dung có dấu tiếng Việt"))
let reloadedFont = controller.textStorage.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
check("nạp lại giữ cỡ đầu mục", (reloadedFont?.pointSize ?? 0) >= 22, "got \(reloadedFont?.pointSize ?? -1)")
check("nạp lại giữ mục lục", controller.outline.count == 1, "got \(controller.outline.count)")
let reloadedColor = controller.textStorage.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
check("nạp lại giữ màu chữ", reloadedColor != nil)

print("== markdown ==")
let md = """
# Tiêu đề chính
Đoạn **đậm** và *nghiêng*.
## Mục nhỏ
- điểm một
- điểm hai
1. bước một
2. bước hai
"""
let fromMD = MarkdownConverter.attributedString(fromMarkdown: md)
check("markdown import giữ chữ", fromMD.string.contains("Tiêu đề chính") && fromMD.string.contains("điểm một"))
let h1Font = fromMD.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
check("markdown import dựng đầu mục", (h1Font?.pointSize ?? 0) >= 22, "got \(h1Font?.pointSize ?? -1)")
let backToMD = MarkdownConverter.markdown(from: fromMD)
check("markdown export có #", backToMD.contains("# Tiêu đề chính"), "got \(backToMD.prefix(80))")
check("markdown export có ##", backToMD.contains("## Mục nhỏ"))
check("markdown export có gạch đầu dòng", backToMD.contains("- điểm một"), "got \(backToMD)")
check("markdown export có đánh số", backToMD.contains("1. bước một"), "got \(backToMD)")
check("markdown export giữ đậm", backToMD.contains("**đậm**"), "got \(backToMD)")

print("== export files ==")
let outDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("bnote-export-test")
try? FileManager.default.removeItem(at: outDir)
try! FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
controller.load(data: nil, plainText: "Báo cáo quý 3\nNội dung chi tiết của tài liệu thử nghiệm.", config: PageConfig())
let tv5 = controller.activeTextView!
tv5.setSelectedRange(NSRange(location: 0, length: 13))
controller.apply(style: .heading1)
let doc = controller.attributedCopy
for format in DocumentFormat.allCases {
    let url = outDir.appendingPathComponent("test.\(format.fileExtension)")
    do {
        try DocumentIO.write(attributed: doc, format: format, to: url, config: PageConfig())
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        check("xuất \(format.fileExtension)", (size ?? 0) > 20, "got \(size ?? 0) bytes")
    } catch {
        check("xuất \(format.fileExtension)", false, "\(error)")
    }
}

print("== import files ==")
for ext in ["rtf", "html", "md", "txt", "docx"] {
    let url = outDir.appendingPathComponent("test.\(ext)")
    if let restored = DocumentIO.read(url: url) {
        check("nhập lại \(ext)", restored.string.contains("Báo cáo quý 3"), "got \(restored.string.prefix(40).debugDescription)")
    } else {
        check("nhập lại \(ext)", false, "đọc thất bại")
    }
}

print("== menu / ==")
check("gõ / hiện đủ lệnh", SlashCatalog.filter(query: "").count == SlashCatalog.all.count)
check("lọc không dấu khớp có dấu", SlashCatalog.filter(query: "dau muc").contains { $0.id == "h1" }, "got \(SlashCatalog.filter(query: "dau muc").map(\.id))")
check("lọc có dấu", SlashCatalog.filter(query: "Trích").contains { $0.id == "quote" })
check("lọc theo từ khóa tiếng Anh", SlashCatalog.filter(query: "todo").contains { $0.id == "todo" })
check("lọc không khớp trả rỗng", SlashCatalog.filter(query: "zzzz").isEmpty)

controller.load(data: nil, plainText: "", config: PageConfig())
let tvSlash = controller.activeTextView!
controller.textStorage.setAttributedString(NSAttributedString(string: "Ghi chú: /dau muc", attributes: EditorDefaults.bodyAttributes))
tvSlash.setSelectedRange(NSRange(location: controller.textStorage.length, length: 0))
controller.updateSlashMenu()
check("nhận diện / giữa câu", controller.slashTrigger == 9, "got \(String(describing: controller.slashTrigger))")
check("lệnh lọc theo chữ đã gõ", controller.slashModel.commands.first?.id == "h1", "got \(controller.slashModel.commands.first?.id ?? "nil")")

if let command = controller.slashModel.commands.first {
    controller.runSlashCommand(command)
}
check("chạy lệnh xóa hết phần /…", controller.textStorage.string == "Ghi chú: ", "got \(controller.textStorage.string.debugDescription)")
let afterSlashFont = controller.textStorage.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
check("lệnh áp kiểu đầu mục", (afterSlashFont?.pointSize ?? 0) >= 22, "got \(afterSlashFont?.pointSize ?? -1)")

controller.load(data: nil, plainText: "chỉ là text/không phải lệnh", config: PageConfig())
controller.activeTextView!.setSelectedRange(NSRange(location: 16, length: 0))
controller.updateSlashMenu()
check("/ dính liền chữ thì không mở menu", controller.slashTrigger == nil, "got \(String(describing: controller.slashTrigger))")

print("== khối việc cần làm ==")
controller.load(data: nil, plainText: "mua sữa\ngọi khách", config: PageConfig())
let tvTodo = controller.activeTextView!
tvTodo.setSelectedRange(NSRange(location: 0, length: controller.textStorage.length))
controller.toggleList(.todo)
check("chèn ô đánh dấu", controller.textStorage.string.hasPrefix("☐\tmua sữa"), "got \(controller.textStorage.string.debugDescription)")
let todoParagraph = (controller.textStorage.string as NSString).paragraphRange(for: NSRange(location: 0, length: 0))
check("đánh dấu xong gạch ngang chữ", {
    controller.handleCheckboxClick(at: NSPoint(x: 3, y: 6), in: tvTodo as! PageTextView)
    let checked = controller.textStorage.string.hasPrefix("☑")
    let struck = controller.textStorage.attribute(.strikethroughStyle, at: todoParagraph.location + 3, effectiveRange: nil) != nil
    return checked && struck
}(), "got \(controller.textStorage.string.prefix(12).debugDescription)")
check("bấm lần nữa thì bỏ đánh dấu", {
    controller.handleCheckboxClick(at: NSPoint(x: 3, y: 6), in: tvTodo as! PageTextView)
    return controller.textStorage.string.hasPrefix("☐")
}())

print("== thoát khối bằng Enter ==")
controller.load(data: nil, plainText: "trích dẫn", config: PageConfig())
let tvBlock = controller.activeTextView!
tvBlock.setSelectedRange(NSRange(location: 2, length: 0))
controller.insertQuote()
controller.textStorage.append(NSAttributedString(
    string: "\n",
    attributes: controller.textStorage.attributes(at: 0, effectiveRange: nil)
))
let emptyQuoteLine = controller.textStorage.length
tvBlock.setSelectedRange(NSRange(location: emptyQuoteLine, length: 0))
_ = controller.textView(tvBlock, shouldChangeTextIn: NSRange(location: emptyQuoteLine, length: 0), replacementString: "\n")
let exitStyle = tvBlock.typingAttributes[.paragraphStyle] as? NSParagraphStyle
check("Enter trên dòng trống thoát khối trích dẫn", (exitStyle?.textBlocks.count ?? 1) == 0, "got \(exitStyle?.textBlocks.count ?? -1)")

// Same gesture in the middle of a document rewrites the paragraph itself.
controller.load(data: nil, plainText: "trích dẫn\n\nsau đó", config: PageConfig())
let tvMid = controller.activeTextView!
tvMid.setSelectedRange(NSRange(location: 0, length: controller.textStorage.length))
controller.insertQuote()
tvMid.setSelectedRange(NSRange(location: 10, length: 0))
_ = controller.textView(tvMid, shouldChangeTextIn: NSRange(location: 10, length: 0), replacementString: "\n")
let midStyle = controller.textStorage.attribute(.paragraphStyle, at: 10, effectiveRange: nil) as? NSParagraphStyle
check("thoát khối ở giữa tài liệu", (midStyle?.textBlocks.count ?? 1) == 0, "got \(midStyle?.textBlocks.count ?? -1)")

print("== khối trích dẫn / callout / kẻ ngang / bảng ==")
controller.load(data: nil, plainText: "một câu trích", config: PageConfig())
controller.activeTextView!.setSelectedRange(NSRange(location: 2, length: 0))
controller.insertQuote()
let quoteStyle = controller.textStorage.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
check("trích dẫn có vạch dọc", (quoteStyle?.textBlocks.count ?? 0) == 1, "got \(quoteStyle?.textBlocks.count ?? -1)")

let quoteSnap = controller.snapshot()
controller.load(data: quoteSnap.data, plainText: "", config: PageConfig())
let quoteReloaded = controller.textStorage.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
check("trích dẫn còn sau khi lưu–nạp", (quoteReloaded?.textBlocks.count ?? 0) == 1, "got \(quoteReloaded?.textBlocks.count ?? -1)")

controller.load(data: nil, plainText: "", config: PageConfig())
controller.insertTable(rows: 2, columns: 2)
let tableSnap = controller.snapshot()
controller.load(data: tableSnap.data, plainText: "", config: PageConfig())
var reloadedCells = 0
controller.textStorage.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: controller.textStorage.length)) { value, _, _ in
    if let style = value as? NSParagraphStyle, style.textBlocks.first is NSTextTableBlock { reloadedCells += 1 }
}
check("bảng còn sau khi lưu–nạp", reloadedCells == 4, "got \(reloadedCells)")

controller.load(data: nil, plainText: "cảnh báo", config: PageConfig())
controller.activeTextView!.setSelectedRange(NSRange(location: 2, length: 0))
controller.insertCallout()
check("callout thêm biểu tượng", controller.textStorage.string.hasPrefix("💡 "), "got \(controller.textStorage.string.debugDescription)")

controller.load(data: nil, plainText: "trên", config: PageConfig())
controller.activeTextView!.setSelectedRange(NSRange(location: 4, length: 0))
controller.insertDivider()
check("kẻ ngang là tệp đính kèm", controller.textStorage.containsAttachments)

controller.load(data: nil, plainText: "", config: PageConfig())
controller.insertTable(rows: 3, columns: 3)
var cellCount = 0
controller.textStorage.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: controller.textStorage.length)) { value, _, _ in
    if let style = value as? NSParagraphStyle, style.textBlocks.first is NSTextTableBlock { cellCount += 1 }
}
check("bảng dựng đủ 9 ô", cellCount == 9, "got \(cellCount)")

print("== lề bốn cạnh & hướng giấy ==")
var custom = PageConfig()
custom.margins = PageMargins(top: 40, bottom: 40, left: 120, right: 60)
check("vùng chữ trừ đúng lề", custom.contentSize.width == custom.size.width - 180, "got \(custom.contentSize.width)")
check("gốc vùng chữ theo lề trái/trên", custom.contentOrigin == NSPoint(x: 120, y: 40))
var landscape = PageConfig()
landscape.orientation = .landscape
check("giấy ngang thì xoay kích thước", landscape.size.width > landscape.size.height)
var silly = PageConfig()
silly.margins = PageMargins(uniform: 900)
silly.clampMargins()
check("lề quá lớn bị kẹp lại", silly.contentSize.width >= 80 && silly.contentSize.height >= 80, "got \(silly.contentSize)")

controller.load(data: nil, plainText: long, config: PageConfig())
canvas.updatePagination()
let normalMarginPages = canvas.pageCount
var tight = PageConfig()
tight.margins = PageMargins(uniform: 20)
controller.config = tight
canvas.applyConfig(tight, options: paperOptions)
check("lề hẹp thì ít trang hơn", canvas.pageCount < normalMarginPages, "thường=\(normalMarginPages) hẹp=\(canvas.pageCount)")


print("== placeholder & số trang ==")
controller.load(data: nil, plainText: "", config: PageConfig())
canvas.updatePagination()
canvas.frame = NSRect(x: 0, y: 0, width: 700, height: 300)
canvas.layoutSubtreeIfNeeded()
if let rep = canvas.bitmapImageRepForCachingDisplay(in: NSRect(x: 0, y: 0, width: 700, height: 300)) {
    canvas.cacheDisplay(in: NSRect(x: 0, y: 0, width: 700, height: 300), to: rep)
    if let png = rep.representation(using: .png, properties: [:]) {
        try? png.write(to: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("bnote-empty.png"))
    }
}
check("trang trống có placeholder", (controller.activeTextView as? PageTextView)?.placeholder != nil)
controller.load(data: nil, plainText: long, config: PageConfig())
canvas.updatePagination()
canvas.frame = NSRect(x: 0, y: 0, width: 700, height: 1000)
canvas.layoutSubtreeIfNeeded()
check("nhiều trang thì vẽ số trang", canvas.pageCount > 1)
if let rep = canvas.bitmapImageRepForCachingDisplay(in: NSRect(x: 0, y: 780, width: 700, height: 220)) {
    canvas.cacheDisplay(in: NSRect(x: 0, y: 780, width: 700, height: 220), to: rep)
    if let png = rep.representation(using: .png, properties: [:]) {
        try? png.write(to: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("bnote-pagegap.png"))
    }
}


print("== khối mã ==")
controller.load(data: nil, plainText: "func hello(name: String) -> Int {\n    // chào\n    let n = 42\n    print(\"Hi \\(name)\")\n    return n\n}", config: PageConfig())
let tvCode = controller.activeTextView!
tvCode.setSelectedRange(NSRange(location: 0, length: controller.textStorage.length))
controller.apply(style: .code)
let codeFont = controller.textStorage.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
check("khối mã dùng phông đều nét", codeFont?.isFixedPitch == true)
var codeBlocks = Set<ObjectIdentifier>()
controller.textStorage.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: controller.textStorage.length)) { v, _, _ in
    if let b = (v as? NSParagraphStyle)?.textBlocks.first { codeBlocks.insert(ObjectIdentifier(b)) }
}
check("mọi dòng chung một khung", codeBlocks.count == 1, "got \(codeBlocks.count)")
let kwColor = controller.textStorage.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor   // "func"
let strLoc = (controller.textStorage.string as NSString).range(of: "\"Hi").location
let strColor = controller.textStorage.attribute(.foregroundColor, at: strLoc, effectiveRange: nil) as? NSColor
let cmLoc = (controller.textStorage.string as NSString).range(of: "// chào").location
let cmColor = controller.textStorage.attribute(.foregroundColor, at: cmLoc, effectiveRange: nil) as? NSColor
check("từ khóa tô màu", kwColor == CodeHighlighter.keywordColor, "got \(String(describing: kwColor))")
check("chuỗi tô màu", strColor == CodeHighlighter.stringColor)
check("chú thích tô màu", cmColor == CodeHighlighter.commentColor)
check("nhận diện là đoạn mã", controller.isCodeParagraph(at: 5))
let codeSnap = controller.snapshot()
controller.load(data: codeSnap.data, plainText: "", config: PageConfig())
check("khối mã còn sau lưu–nạp", controller.isCodeParagraph(at: 0))
let md2 = MarkdownConverter.markdown(from: controller.attributedCopy)
check("markdown xuất fence ```", md2.hasPrefix("```") && md2.contains("let n = 42"), "got \(md2.prefix(60))")
let back = MarkdownConverter.attributedString(fromMarkdown: "# T\n```\nprint(1)\n```\nsau")
check("markdown nhập fence thành khối", (back.attribute(.paragraphStyle, at: 3, effectiveRange: nil) as? NSParagraphStyle)?.textBlocks.isEmpty == false)

tvCode.setSelectedRange(NSRange(location: 0, length: controller.textStorage.length))
controller.apply(style: .body)
check("đổi về Văn bản thì bỏ khung", (controller.textStorage.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)?.textBlocks.isEmpty == true)

print("== dán ảnh & link ==")
controller.load(data: nil, plainText: "", config: PageConfig())
let big = NSImage(size: NSSize(width: 3000, height: 1500))
big.lockFocus(); NSColor.systemBlue.setFill(); NSRect(x: 0, y: 0, width: 3000, height: 1500).fill(); big.unlockFocus()
let pb = NSPasteboard.general
pb.clearContents(); pb.writeObjects([big])
check("dán ảnh từ clipboard", controller.pasteFromPasteboard(pb, in: controller.activeTextView!))
check("ảnh thành attachment", controller.textStorage.containsAttachments)
let att = controller.textStorage.attribute(.attachment, at: 0, effectiveRange: nil) as? NSTextAttachment
check("ảnh vừa chiều rộng vùng chữ", (att?.bounds.width ?? 0) <= controller.config.contentSize.width + 0.5, "w=\(att?.bounds.width ?? -1)")
check("ảnh lớn bị giới hạn pixel", (att?.image?.limited().size.width ?? 9999) <= 2000)

controller.load(data: nil, plainText: "", config: PageConfig())
pb.clearContents(); pb.setString("https://www.youtube.com/watch?v=dQw4w9WgXcQ", forType: .string)
check("nhận diện ID YouTube", MediaLink.youtubeID(from: URL(string: "https://youtu.be/abc123")!) == "abc123" && MediaLink.youtubeID(from: URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=1")!) == "dQw4w9WgXcQ" && MediaLink.youtubeID(from: URL(string: "https://www.youtube.com/shorts/xyz")!) == "xyz")
check("dán link thành liên kết", controller.pasteFromPasteboard(pb, in: controller.activeTextView!))
check("liên kết có .link", controller.link(at: 0) != nil)
check("text thường không bị chặn", { pb.clearContents(); pb.setString("chỉ là chữ", forType: .string); return !controller.pasteFromPasteboard(pb, in: controller.activeTextView!) }())

print("== render ảnh canvas ==")
let sample = """
Đề xuất sản phẩm BNote
Tổng quan
BNote là trình soạn thảo dành cho macOS với khả năng định dạng đầy đủ: chọn phông chữ, cỡ chữ, màu sắc, canh lề và danh sách. Tài liệu được trình bày theo từng trang giấy thật, giống Google Docs, nên bạn luôn biết bản in sẽ trông ra sao.
Mục tiêu quý này
Hoàn thiện bộ công cụ định dạng
Xuất bản sang PDF và Word
Nhập tài liệu từ Markdown
Chi tiết kỹ thuật
Phần soạn thảo dựng trên AppKit với nhiều khung văn bản chia sẻ cùng một layout manager, nhờ vậy chữ tràn tự nhiên từ trang này sang trang kế tiếp khi bạn gõ.
"""
controller.load(data: nil, plainText: sample, config: PageConfig())
let render = controller.activeTextView!
let ns = controller.textStorage.string as NSString
func select(_ needle: String) { render.setSelectedRange(ns.range(of: needle)) }
select("Đề xuất sản phẩm BNote"); controller.apply(style: .title)
select("Tổng quan"); controller.apply(style: .heading1)
select("Mục tiêu quý này"); controller.apply(style: .heading1)
select("Chi tiết kỹ thuật"); controller.apply(style: .heading1)
let bulletStart = ns.range(of: "Hoàn thiện bộ công cụ định dạng").location
let bulletEnd = ns.range(of: "Nhập tài liệu từ Markdown")
render.setSelectedRange(NSRange(location: bulletStart, length: bulletEnd.location + bulletEnd.length - bulletStart))
controller.toggleList(.bullet)
select("định dạng đầy đủ"); controller.toggleTrait(.boldFontMask)
select("Google Docs"); controller.setTextColor(.systemBlue)
canvas.updatePagination()
check("tài liệu mẫu có mục lục", controller.outline.count == 4, "got \(controller.outline.count)")

// Notion-style blocks on a second sample page.
let blockDoc = controller.activeTextView!
blockDoc.setSelectedRange(NSRange(location: controller.textStorage.length, length: 0))
controller.insertDivider()
let checklist = "Việc cần làm\nRà soát bản thảo\nGửi cho nhóm duyệt\nChốt bản in"
let insertAt = controller.textStorage.length
controller.textStorage.append(NSAttributedString(string: checklist + "\n", attributes: EditorDefaults.bodyAttributes))
let ns2 = controller.textStorage.string as NSString
blockDoc.setSelectedRange(ns2.range(of: "Việc cần làm"))
controller.apply(style: .heading1)
let taskStart = ns2.range(of: "Rà soát bản thảo").location
let taskEnd = ns2.range(of: "Chốt bản in")
blockDoc.setSelectedRange(NSRange(location: taskStart, length: taskEnd.location + taskEnd.length - taskStart))
controller.toggleList(.todo)
_ = controller.handleCheckboxClick(at: NSPoint(x: 3, y: 3), in: blockDoc as! PageTextView)
_ = insertAt

let ns3 = controller.textStorage.string as NSString
blockDoc.setSelectedRange(NSRange(location: ns3.length, length: 0))
controller.textStorage.append(NSAttributedString(string: "\nNhớ gửi bản in thử trước thứ Sáu.", attributes: EditorDefaults.bodyAttributes))
blockDoc.setSelectedRange(NSRange(location: controller.textStorage.length, length: 0))
controller.insertCallout()
check("callout không dính vào mục danh sách", !controller.textStorage.string.contains("💡 ☐"), "got \(controller.textStorage.string.debugDescription)")

controller.textStorage.append(NSAttributedString(string: "\nMọi tài liệu đều nên đọc lại một lần trước khi gửi đi.", attributes: EditorDefaults.bodyAttributes))
blockDoc.setSelectedRange(NSRange(location: controller.textStorage.length - 5, length: 0))
controller.insertQuote()

controller.textStorage.append(NSAttributedString(string: "\n", attributes: EditorDefaults.bodyAttributes))
blockDoc.setSelectedRange(NSRange(location: controller.textStorage.length, length: 0))
controller.insertToday()
controller.textStorage.append(NSAttributedString(string: "\nstruct Greeter {\n    let name: String   // ai được chào\n    func hello() -> String { \"Xin chào, \\(name)!\" }\n}\nprint(Greeter(name: \"BNote\").hello()) // 1 dòng", attributes: EditorDefaults.bodyAttributes))
let codeStart = (controller.textStorage.string as NSString).range(of: "struct Greeter").location
blockDoc.setSelectedRange(NSRange(location: codeStart, length: controller.textStorage.length - codeStart))
controller.apply(style: .code)

canvas.frame = NSRect(x: 0, y: 0, width: 700, height: 1000)
canvas.applyConfig(controller.config, options: CanvasOptions(showGrid: false, showMarginGuides: true, continuous: false))
canvas.layoutSubtreeIfNeeded()
if let rep = canvas.bitmapImageRepForCachingDisplay(in: canvas.bounds) {
    canvas.cacheDisplay(in: canvas.bounds, to: rep)
    if let png = rep.representation(using: .png, properties: [:]) {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("bnote-canvas.png")
        try? png.write(to: url)
        print("  ảnh: \(url.path)")
    }
}

print("")
print("== tìm & thay thế trong trang ==")
controller.load(data: nil, plainText: "Hà Nội mùa thu. hà nội mùa đông.\nSài Gòn nắng.", config: PageConfig())
canvas.updatePagination()
controller.showFind()
check("thanh tìm mở", controller.find.isVisible)
controller.find.query = "hà nội"; controller.findQueryChanged()
check("không phân biệt hoa thường: 2 kết quả", controller.find.matches.count == 2, "got \(controller.find.matches.count)")
check("kết quả đầu là 'Hà Nội' ở đầu", controller.find.matches.first == NSRange(location: 0, length: 6), "got \(String(describing: controller.find.matches.first))")
check("kết quả hiện tại được tô cam", (controller.layoutManager.temporaryAttribute(.backgroundColor, atCharacterIndex: 0, effectiveRange: nil) as? NSColor) != nil)
check("đang tìm: không đổi vùng chọn (giữ màu cam)", controller.activeTextView?.selectedRange().length == 0, "sel=\(String(describing: controller.activeTextView?.selectedRange()))")
controller.findNext()
check("⌘G sang kết quả 2/2", controller.find.current == 1 && controller.find.summary == "2/2", "summary=\(controller.find.summary)")
controller.findNext()
check("⌘G quay vòng về 1/2", controller.find.current == 0)
controller.find.caseSensitive = true; controller.findQueryChanged()
check("phân biệt hoa thường: 1 kết quả", controller.find.matches.count == 1 && controller.find.matches.first?.location == 16, "got \(controller.find.matches)")
controller.find.caseSensitive = false; controller.findQueryChanged()
check("đổi tuỳ chọn: kết quả hiện tại là cái đầu tiên sau con trỏ", controller.find.current == 0)
controller.find.replacement = "Huế"
controller.replaceCurrentMatch()
check("Thay: đổi kết quả hiện tại", controller.textStorage.string.hasPrefix("Huế mùa thu. hà nội mùa đông."), "text=\(controller.textStorage.string.replacingOccurrences(of: "\n", with: "⏎"))")
check("Thay: còn 1 kết quả, chuyển tới nó", controller.find.matches.count == 1 && controller.find.current == 0)
controller.find.query = "mùa"; controller.findQueryChanged()
controller.find.replacement = "tiết"
controller.replaceAllMatches()
check("Thay tất cả", controller.textStorage.string == "Huế tiết thu. hà nội tiết đông.\nSài Gòn nắng.", "text=\(controller.textStorage.string.replacingOccurrences(of: "\n", with: "⏎"))")
check("Thay tất cả: không còn kết quả", controller.find.matches.isEmpty && controller.find.summary == "Not found")
controller.find.query = ""; controller.findQueryChanged()
check("chuỗi rỗng: không kết quả, không tóm tắt", controller.find.matches.isEmpty && controller.find.summary.isEmpty)
controller.find.query = "Sài"; controller.findQueryChanged()
controller.hideFind()
check("đóng thanh: xoá tô sáng", !controller.find.isVisible && controller.layoutManager.temporaryAttribute(.backgroundColor, atCharacterIndex: 0, effectiveRange: nil) == nil)
check("đóng thanh: chọn kết quả hiện tại", controller.activeTextView?.selectedRange() == NSRange(location: 32, length: 3), "sel=\(String(describing: controller.activeTextView?.selectedRange()))")

print("== toggle section: thu gọn thì dòng con biến mất khỏi layout ==")
controller.canvasOptions = paperOptions
controller.load(data: nil, plainText: "", config: PageConfig())
canvas.updatePagination()
let toggleTV = controller.activeTextView!
// "▾ Section" + hai dòng con thụt lề + một dòng ngoài
controller.insertPlainText("Section")
controller.toggleList(.toggle)
check("/toggle chèn mũi tên mở", controller.textStorage.string.hasPrefix("\(ToggleMarker.expanded)\tSection"), "text=\(controller.textStorage.string.prefix(12))")
toggleTV.setSelectedRange(NSRange(location: controller.textStorage.length, length: 0))
_ = controller.textView(toggleTV, shouldChangeTextIn: NSRange(location: controller.textStorage.length, length: 0), replacementString: "\n")
controller.insertPlainText("child one")
let childStart = controller.textStorage.string.range(of: "child one").map { controller.textStorage.string.distance(from: controller.textStorage.string.startIndex, to: $0.lowerBound) } ?? 0
check("Enter trong toggle tạo dòng con thụt lề", controller.paragraphIndent(at: childStart) > 0, "indent=\(controller.paragraphIndent(at: childStart))")
toggleTV.setSelectedRange(NSRange(location: controller.textStorage.length, length: 0))
controller.insertPlainText("\nchild two")
canvas.updatePagination()
let openHeight = controller.layoutManager.usedRect(for: controller.layoutManager.textContainers[0]).height

let togglePara = controller.paragraphRange(at: 0)
controller.toggleSection(at: togglePara)
canvas.updatePagination()
check("thu gọn: mũi tên thành ▸", controller.textStorage.string.hasPrefix(String(ToggleMarker.collapsed)))
check("thu gọn: dòng con bị đánh dấu ẩn", controller.isHidden(at: childStart))
let closedHeight = controller.layoutManager.usedRect(for: controller.layoutManager.textContainers[0]).height
check("thu gọn: layout thấp hẳn đi", closedHeight < openHeight - 10, "mở=\(openHeight) đóng=\(closedHeight)")
check("thu gọn: chữ vẫn còn trong tài liệu", controller.textStorage.string.contains("child two"))

controller.toggleSection(at: controller.paragraphRange(at: 0))
canvas.updatePagination()
check("mở lại: hết ẩn", !controller.isHidden(at: childStart))
check("mở lại: layout cao như cũ", abs(controller.layoutManager.usedRect(for: controller.layoutManager.textContainers[0]).height - openHeight) < 1, "h=\(controller.layoutManager.usedRect(for: controller.layoutManager.textContainers[0]).height)")

print("== toggle: tìm kiếm mở giúp phần đang thu gọn ==")
controller.toggleSection(at: controller.paragraphRange(at: 0))
controller.showFind()
controller.find.query = "child two"; controller.findQueryChanged()
check("tìm thấy chữ trong phần thu gọn", controller.find.matches.count == 1, "got \(controller.find.matches.count)")
controller.revealCurrentMatch()
check("nhảy tới kết quả thì toggle tự mở", !controller.isHidden(at: childStart))
controller.hideFind()

print("== checkbox: marker vẫn là ký tự, có ô vẽ riêng ==")
controller.load(data: nil, plainText: "mua sữa", config: PageConfig())
controller.toggleList(.todo)
canvas.updatePagination()
check("to-do bắt đầu bằng ☐", controller.textStorage.string.hasPrefix("\(Checkbox.unchecked)\t"))
let markerFont = (controller.textStorage.attribute(.font, at: 0, effectiveRange: nil) as? NSFont) ?? EditorDefaults.bodyFont
let markerRect = controller.layoutManager.boundingRect(forGlyphRange: NSRange(location: controller.layoutManager.glyphIndexForCharacter(at: 0), length: 1), in: controller.layoutManager.textContainers[0])
check("ô checkbox rộng đúng bằng hộp đã đặt", abs(markerRect.width - EditorMarkers.width(for: markerFont)) < 0.5, "w=\(markerRect.width) muốn=\(EditorMarkers.width(for: markerFont))")
let clickPoint = NSPoint(x: markerRect.midX, y: markerRect.midY)
_ = controller.handleCheckboxClick(at: clickPoint, in: canvas.pages[0].textView)
check("bấm vào ô thì tích", controller.textStorage.string.hasPrefix("\(Checkbox.checked)\t"), "text=\(controller.textStorage.string.prefix(4))")

if failures.isEmpty {
    print("TẤT CẢ ĐỀU ĐẠT")
} else {
    print("THẤT BẠI (\(failures.count)): \(failures.joined(separator: " | "))")
}
exit(failures.isEmpty ? 0 : 1)
