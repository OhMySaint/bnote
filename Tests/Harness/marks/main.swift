import AppKit

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
let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 560), styleMask: [.titled, .resizable], backing: .buffered, defer: false)
window.contentView = host
host.frame = window.contentView!.bounds
host.layoutSubtreeIfNeeded()
window.orderFront(nil)
pump(0.3)
controller.load(data: nil, plainText: "", config: PageConfig())
let tv = controller.activeTextView!
window.makeFirstResponder(tv)

/// Builds one paragraph: text, optional style, optional list marker.
func para(_ text: String, style: TextStyle? = nil, list: ListKind? = nil) {
    let start = controller.textStorage.length
    tv.setSelectedRange(NSRange(location: start, length: 0))
    controller.insertPlainText(text)
    tv.setSelectedRange(NSRange(location: start + (text as NSString).length, length: 0))
    if let style { controller.apply(style: style) }
    if let list { controller.toggleList(list) }
    tv.setSelectedRange(NSRange(location: controller.textStorage.length, length: 0))
    controller.insertPlainText("\n")
    tv.typingAttributes = EditorDefaults.bodyAttributes
}

para("Body to-do item", list: .todo)
para("Heading to-do", style: .heading1, list: .todo)
para("Toggle section", list: .toggle)
para("Bullet item", list: .bullet)
para("Plain body paragraph at the new default size")
para("Heading 1 sample", style: .heading1)
para("Heading 2 sample", style: .heading2)
pump(0.3); host.layoutSubtreeIfNeeded(); pump(0.3)

print("== marker không đẩy chữ đi chỗ khác ==")
let text = controller.textStorage.string as NSString
let lm = controller.layoutManager
let container = lm.textContainers[0]
var bodyStarts: [CGFloat] = []
var location = 0
while location < text.length {
    let paragraph = text.paragraphRange(for: NSRange(location: location, length: 0))
    defer { location = max(paragraph.upperBound, location + 1) }
    guard let marker = controller.textStorage.string.character(atUTF16: paragraph.location), EditorMarkers.isMarker(marker) || marker == "•" else { continue }
    // Skip a marker with nothing after it: there is no body glyph to measure.
    guard text.substring(with: paragraph).dropFirst(2).trimmingCharacters(in: .whitespacesAndNewlines).count > 0 else { continue }
    let markerRect = lm.boundingRect(forGlyphRange: NSRange(location: lm.glyphIndexForCharacter(at: paragraph.location), length: 1), in: container)
    let bodyRect = lm.boundingRect(forGlyphRange: NSRange(location: lm.glyphIndexForCharacter(at: paragraph.location + 2), length: 1), in: container)
    let font = (controller.textStorage.attribute(.font, at: paragraph.location, effectiveRange: nil) as? NSFont) ?? EditorDefaults.bodyFont
    let name = text.substring(with: paragraph).trimmingCharacters(in: .whitespacesAndNewlines)
    print(String(format: "  %-22@ font %4.1f  ô %5.1f..%5.1f  chữ %5.1f", String(name.prefix(20)) as NSString, font.pointSize, markerRect.minX, markerRect.maxX, bodyRect.minX))
    check("\(name.prefix(14)): ô không đè lên chữ", bodyRect.minX >= markerRect.maxX - 0.1, "ô hết ở \(markerRect.maxX), chữ ở \(bodyRect.minX)")
    bodyStarts.append(bodyRect.minX)
}
check("mọi dòng danh sách bắt đầu cùng một chỗ", Set(bodyStarts.map { ($0 * 2).rounded() }).count == 1, "\(bodyStarts)")

print("== bề rộng cột theo cửa sổ ==")
for width in [700.0, 1200.0, 1920.0, 2560.0] {
    window.setContentSize(NSSize(width: width, height: 700))
    host.frame = window.contentView!.bounds
    host.layoutSubtreeIfNeeded(); pump(0.15)
    let col = host.canvas.contentWidth
    print(String(format: "  cửa sổ %6.0f → cột %5.0f (mép %4.0f mỗi bên)", width, col, (width - col) / 2))
    check(String(format: "%.0f: cột trong khoảng đọc được", width), col <= PagedDocumentView.Metrics.maximumColumn + 0.5 && col >= min(width - 32, 320), "col=\(col)")
}
window.setContentSize(NSSize(width: 900, height: 560))
host.frame = window.contentView!.bounds
host.layoutSubtreeIfNeeded(); pump(0.2)

if let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
    host.cacheDisplay(in: host.bounds, to: rep)
    if let png = rep.representation(using: .png, properties: [:]) {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("bnote-marks.png")
        try? png.write(to: url)
        print("  ảnh: \(url.path)")
    }
}
print(failures.isEmpty ? "TẤT CẢ ĐỀU ĐẠT" : "THẤT BẠI (\(failures.count)): \(failures.joined(separator: " | "))")
exit(failures.isEmpty ? 0 : 1)
