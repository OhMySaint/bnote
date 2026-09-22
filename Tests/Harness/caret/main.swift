import AppKit

// Guards the class of bug where the text sits somewhere other than the caret:
// a paragraph style that inflates the line box drops the glyphs to its bottom,
// so the caret beside them looks offset.
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
func pump(_ s: TimeInterval = 0.1) { RunLoop.main.run(until: Date().addingTimeInterval(s)) }
var failures: [String] = []
func check(_ label: String, _ ok: Bool, _ detail: String = "") {
    print(ok ? "  ok   \(label)" : "  FAIL \(label) \(detail)")
    if !ok { failures.append(label) }
}

let controller = DocumentController.shared
controller.canvasOptions = CanvasOptions()
let host = EditorCanvasView(controller: controller)
let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 820, height: 560), styleMask: [.titled], backing: .buffered, defer: false)
window.contentView = host
host.frame = window.contentView!.bounds
host.layoutSubtreeIfNeeded()
window.orderFront(nil)
pump(0.3)
let lm = controller.layoutManager

/// The glyphs must start one ascender below the top of their line box; more
/// than that means the line was inflated and the text drifted from the caret.
func checkLine(_ label: String, at index: Int) {
    let container = lm.textContainers[0]
    let glyph = lm.glyphIndexForCharacter(at: index)
    let line = lm.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
    let used = lm.lineFragmentUsedRect(forGlyphAt: glyph, effectiveRange: nil)
    let baseline = lm.location(forGlyphAt: glyph).y
    let font = (controller.textStorage.attribute(.font, at: index, effectiveRange: nil) as? NSFont) ?? EditorDefaults.bodyFont
    let caret = controller.activeTextView.map { tv -> NSRect in
        tv.setSelectedRange(NSRange(location: index, length: 0))
        return lm.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: container)
    } ?? .zero
    // The first line of a paragraph also carries its space-before; anything
    // beyond that means the line box was inflated and the glyphs sank in it.
    // AppKit skips space-before on the document's very first paragraph.
    let paragraphStart = (controller.textStorage.string as NSString).paragraphRange(for: NSRange(location: index, length: 0)).location
    let spacingBefore = paragraphStart == 0 ? 0
        : ((controller.textStorage.attribute(.paragraphStyle, at: index, effectiveRange: nil) as? NSParagraphStyle)?.paragraphSpacingBefore ?? 0)
    let expected = font.ascender + spacingBefore
    print(String(format: "  %-12@ font %4.1f  baseline %5.1f (chờ %5.1f)  dòng cao %5.1f  chữ cao %5.1f",
                 label as NSString, font.pointSize, baseline, expected, line.height, used.height))
    check("\(label): chữ nằm ngay đầu dòng, không bị đẩy xuống", abs(baseline - expected) < 2.5,
          String(format: "baseline %.1f, chờ %.1f", baseline, expected))
    check("\(label): con trỏ cao bằng dòng chữ", abs(caret.height - used.height) < 2.5,
          String(format: "con trỏ %.1f, dòng %.1f", caret.height, used.height))
}

print("== chữ thẳng với con trỏ ==")
controller.load(data: nil, plainText: "Body line\nsecond line", config: PageConfig())
pump(0.2)
let tv = controller.activeTextView!
window.makeFirstResponder(tv)
checkLine("body", at: 0)

print("== chọn Heading rồi gõ ==")
tv.setSelectedRange(NSRange(location: controller.textStorage.length, length: 0))
controller.insertPlainText("\n")
controller.apply(style: .heading1)
let headingStart = controller.textStorage.length
controller.insertPlainText("Typed heading")
pump(0.2)
let headingFont = controller.textStorage.attribute(.font, at: headingStart, effectiveRange: nil) as? NSFont
check("gõ sau khi chọn Heading vẫn là Heading 1", headingFont?.pointSize == TextStyle.heading1.fontSize && (headingFont?.fontName.contains("Bold") ?? false),
      "font=\(headingFont?.fontName ?? "nil") \(headingFont?.pointSize ?? -1)")
check("chữ vừa gõ nằm trong tài liệu", controller.textStorage.string.hasSuffix("Typed heading"))
checkLine("heading", at: headingStart)

print("== gõ thật (từng phím) sau khi chọn Heading ==")
controller.load(data: nil, plainText: "first line", config: PageConfig())
pump(0.2)
let typeTV = controller.activeTextView!
window.makeFirstResponder(typeTV)
typeTV.setSelectedRange(NSRange(location: controller.textStorage.length, length: 0))
_ = controller.textView(typeTV, shouldChangeTextIn: NSRange(location: controller.textStorage.length, length: 0), replacementString: "\n")
typeTV.insertText("\n", replacementRange: NSRange(location: NSNotFound, length: 0))
controller.apply(style: .heading2)
let typedStart = controller.textStorage.length
for character in "Heading typed" {
    typeTV.insertText(String(character), replacementRange: NSRange(location: NSNotFound, length: 0))
}
pump(0.3)
let typedFont = controller.textStorage.attribute(.font, at: typedStart, effectiveRange: nil) as? NSFont
let lastFont = controller.textStorage.attribute(.font, at: controller.textStorage.length - 1, effectiveRange: nil) as? NSFont
check("ký tự đầu là Heading 2", typedFont?.pointSize == TextStyle.heading2.fontSize, "got \(typedFont?.pointSize ?? -1)")
check("ký tự cuối vẫn là Heading 2", lastFont?.pointSize == TextStyle.heading2.fontSize, "got \(lastFont?.pointSize ?? -1)")
check("chữ gõ ra đúng nội dung", controller.textStorage.string.hasSuffix("Heading typed"), controller.textStorage.string.debugDescription)
checkLine("gõ heading", at: typedStart)

print("== đổi kiểu không dời chữ trong dòng ==")
controller.load(data: nil, plainText: "style switch line", config: PageConfig())
pump(0.2)
let headingStart2 = 0
controller.activeTextView?.setSelectedRange(NSRange(location: 0, length: 0))
controller.apply(style: .body)
pump(0.1)
checkLine("về body", at: headingStart2)
for style in [TextStyle.heading2, .heading3, .title, .body] {
    controller.apply(style: style)
    pump(0.05)
    let glyph = lm.glyphIndexForCharacter(at: headingStart2)
    let baseline = lm.location(forGlyphAt: glyph).y
    let font = (controller.textStorage.attribute(.font, at: headingStart2, effectiveRange: nil) as? NSFont) ?? EditorDefaults.bodyFont
    let before: CGFloat = 0   // this line is the document's first paragraph
    check("\(style.label): baseline khớp ascender", abs(baseline - font.ascender - before) < 2.5,
          String(format: "baseline %.1f, chờ %.1f", baseline, font.ascender + before))
}

print("== chọn kiểu bằng menu / ==")
controller.load(data: nil, plainText: "", config: PageConfig())
pump(0.2)
let slashTV = controller.activeTextView!
window.makeFirstResponder(slashTV)
for (id, style) in [("h1", TextStyle.heading1), ("h2", .heading2), ("quote", .body)] {
    controller.load(data: nil, plainText: "", config: PageConfig())
    pump(0.1)
    slashTV.insertText("/", replacementRange: NSRange(location: NSNotFound, length: 0))
    controller.updateSlashMenu()
    guard let command = SlashCatalog.all.first(where: { $0.id == id }) else { continue }
    controller.runSlashCommand(command)
    pump(0.2)
    let font = (slashTV.typingAttributes[.font] as? NSFont)
    let paragraph = slashTV.typingAttributes[.paragraphStyle] as? NSParagraphStyle
    let detected = TextStyle.detect(font: font, paragraph: paragraph)
    if id != "quote" {
        check("/\(id): giữ nguyên kiểu vừa chọn, không nảy về Text", detected == style,
              "đang là \(detected.label), cỡ \(font?.pointSize ?? -1)")
    }
    // Typing right after must keep it too.
    for character in "abc" { slashTV.insertText(String(character), replacementRange: NSRange(location: NSNotFound, length: 0)) }
    pump(0.2)
    let typed = controller.textStorage.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
    let typedStyle = TextStyle.detect(font: typed, paragraph: controller.textStorage.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)
    if id != "quote" {
        check("/\(id): gõ tiếp vẫn đúng kiểu", typedStyle == style, "đang là \(typedStyle.label), cỡ \(typed?.pointSize ?? -1)")
    }
    check("/\(id): chữ gõ ra đủ", controller.textStorage.string.hasSuffix("abc"), controller.textStorage.string.debugDescription)
}

print("== tài liệu cũ lưu bằng lineHeightMultiple được vá khi mở ==")
let old = NSMutableAttributedString(string: "old paragraph")
let oldStyle = NSMutableParagraphStyle()
oldStyle.lineHeightMultiple = 1.5
old.addAttributes([.font: EditorDefaults.bodyFont, .paragraphStyle: oldStyle], range: NSRange(location: 0, length: old.length))
let archived = DocumentStorage.data(from: old)
controller.load(data: archived, plainText: old.string, config: PageConfig())
pump(0.2)
let loaded = controller.textStorage.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
check("mở lên là hết lineHeightMultiple", (loaded?.lineHeightMultiple ?? 1) == 0, "multiple=\(loaded?.lineHeightMultiple ?? -1)")
check("đổi thành lineSpacing tương đương", (loaded?.lineSpacing ?? 0) > 0, "spacing=\(loaded?.lineSpacing ?? -1)")
checkLine("tài liệu cũ", at: 0)

print("== khối mã và danh sách cũng vậy ==")
controller.load(data: nil, plainText: "code line", config: PageConfig())
controller.applyCodeBlock()
pump(0.2)
checkLine("code", at: 0)
controller.load(data: nil, plainText: "list line", config: PageConfig())
controller.toggleList(.todo)
pump(0.2)
checkLine("to-do", at: 2)

print(failures.isEmpty ? "TẤT CẢ ĐỀU ĐẠT" : "THẤT BẠI (\(failures.count)): \(failures.joined(separator: " | "))")
exit(failures.isEmpty ? 0 : 1)
