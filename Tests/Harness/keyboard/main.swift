import AppKit

setvbuf(stdout, nil, _IOLBF, 0)
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

var failures: [String] = []
func check(_ label: String, _ condition: Bool, _ detail: String = "") {
    print(condition ? "  ok   \(label)" : "  FAIL \(label) \(detail)")
    if !condition { failures.append(label) }
}

let controller = DocumentController.shared
let host = EditorCanvasView(controller: controller)
let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 800),
                      styleMask: [.titled], backing: .buffered, defer: false)
window.contentView = host
host.frame = window.contentView!.bounds
host.layoutSubtreeIfNeeded()
window.orderFront(nil)

func pump() {
    // let deferred main-queue work (pagination, focus) run
    RunLoop.main.run(until: Date().addingTimeInterval(0.05))
}

print("== / ở đầu tài liệu trống ==")
controller.load(data: nil, plainText: "", config: PageConfig())
pump()
let tv = controller.activeTextView!
window.makeFirstResponder(tv)
tv.setSelectedRange(NSRange(location: 0, length: 0))
tv.insertText("/", replacementRange: tv.selectedRange())
pump()
check("gõ / đầu tiên mở menu", controller.slashTrigger == 0, "trigger=\(String(describing: controller.slashTrigger)) text=\(controller.textStorage.string.debugDescription)")
check("menu có lệnh", !controller.slashModel.commands.isEmpty)
check("isSlashMenuOpen", controller.isSlashMenuOpen)

print("== gõ tiếp để lọc ==")
tv.insertText("bang", replacementRange: tv.selectedRange())
pump()
check("lọc còn 'Bảng'", controller.slashModel.commands.first?.id == "table", "got \(controller.slashModel.commands.map(\.id))")

print("== ↓ rồi Enter qua doCommand(by:) ==")
tv.insertText("", replacementRange: tv.selectedRange())
controller.load(data: nil, plainText: "", config: PageConfig()); pump()
let tv2 = controller.activeTextView!
window.makeFirstResponder(tv2)
tv2.insertText("/", replacementRange: NSRange(location: 0, length: 0)); pump()
let before = controller.slashModel.selection
tv2.doCommand(by: #selector(NSResponder.moveDown(_:)))
check("↓ đổi mục chọn, không di chuyển caret", controller.slashModel.selection == before + 1 && controller.slashTrigger == 0,
      "sel=\(controller.slashModel.selection) trigger=\(String(describing: controller.slashTrigger))")
let chosen = controller.slashModel.commands[controller.slashModel.selection].id
tv2.doCommand(by: #selector(NSResponder.insertNewline(_:)))
pump()
check("Enter chèn lệnh và xóa dấu /", !controller.textStorage.string.contains("/"), "text=\(controller.textStorage.string.debugDescription) chosen=\(chosen)")
check("Enter không chèn xuống dòng", !controller.textStorage.string.hasPrefix("\n"), "text=\(controller.textStorage.string.debugDescription)")
check("menu đóng sau khi chèn", controller.slashTrigger == nil)

print("== / sau khi đã có chữ ==")
controller.load(data: nil, plainText: "xin chào ", config: PageConfig()); pump()
let tv3 = controller.activeTextView!
window.makeFirstResponder(tv3)
tv3.setSelectedRange(NSRange(location: controller.textStorage.length, length: 0))
tv3.insertText("/", replacementRange: tv3.selectedRange()); pump()
check("/ sau khoảng trắng mở menu", controller.slashTrigger == 9, "trigger=\(String(describing: controller.slashTrigger))")
tv3.doCommand(by: #selector(NSResponder.insertNewline(_:))); pump()
check("Enter áp lệnh đầu tiên (Văn bản)", !controller.textStorage.string.contains("/"), "text=\(controller.textStorage.string.debugDescription)")

print("== / trên dòng mới sau Enter thường ==")
controller.load(data: nil, plainText: "dòng một", config: PageConfig()); pump()
let tv4 = controller.activeTextView!
window.makeFirstResponder(tv4)
tv4.setSelectedRange(NSRange(location: controller.textStorage.length, length: 0))
tv4.insertText("\n", replacementRange: tv4.selectedRange()); pump()
tv4.insertText("/", replacementRange: tv4.selectedRange()); pump()
check("/ ở đầu dòng mới mở menu", controller.slashTrigger == 9, "trigger=\(String(describing: controller.slashTrigger)) text=\(controller.textStorage.string.debugDescription)")


func key(_ code: UInt16, _ chars: String) -> NSEvent {
    NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                     windowNumber: window.windowNumber, context: nil,
                     characters: chars, charactersIgnoringModifiers: chars,
                     isARepeat: false, keyCode: code)!
}
func visiblePanel() -> NSPanel? {
    NSApp.windows.compactMap { $0 as? NSPanel }.first { $0.isVisible }
}

print("== panel hiện đúng chỗ khi tài liệu trống ==")
controller.load(data: nil, plainText: "", config: PageConfig()); pump()
let tv5 = controller.activeTextView!
window.makeFirstResponder(tv5)
tv5.insertText("/", replacementRange: NSRange(location: 0, length: 0)); pump()
let panel = visiblePanel()
check("panel hiển thị", panel != nil)
if let panel {
    let caretInWindow = tv5.convert(NSRect(x: 0, y: 0, width: 2, height: 16), to: nil)
    let caretOnScreen = window.convertToScreen(caretInWindow)
    let dx = abs(panel.frame.minX - caretOnScreen.minX)
    check("panel nằm sát con trỏ theo chiều ngang", dx < 40, "dx=\(dx) panel=\(panel.frame) caret=\(caretOnScreen)")
    check("panel ngay dưới dòng con trỏ", panel.frame.maxY <= caretOnScreen.minY + 2 && panel.frame.maxY > caretOnScreen.minY - 40, "panel.maxY=\(panel.frame.maxY) caret.minY=\(caretOnScreen.minY)")
}

print("== phím thật: Return qua keyDown ==")
tv5.keyDown(with: key(125, ""))   // ↓
check("↓ qua keyDown đổi mục", controller.slashModel.selection == 1, "sel=\(controller.slashModel.selection)")
tv5.keyDown(with: key(36, "\r"))  // Return
pump()
check("Return qua keyDown chèn lệnh", !controller.textStorage.string.contains("/") && controller.slashTrigger == nil,
      "text=\(controller.textStorage.string.debugDescription)")
check("panel đã ẩn", visiblePanel() == nil)

print("== bộ gõ: marked text rồi Return ==")
controller.load(data: nil, plainText: "", config: PageConfig()); pump()
let tv6 = controller.activeTextView!
window.makeFirstResponder(tv6)
tv6.insertText("/", replacementRange: NSRange(location: 0, length: 0)); pump()
tv6.setMarkedText("bang", selectedRange: NSRange(location: 4, length: 0), replacementRange: NSRange(location: 1, length: 0)); pump()
check("marked text vẫn lọc được menu", controller.slashModel.commands.first?.id == "table", "got \(controller.slashModel.commands.map(\.id)) text=\(controller.textStorage.string.debugDescription)")
check("đang có marked text", tv6.hasMarkedText())
tv6.keyDown(with: key(36, "\r")); pump()
check("Return khi đang gõ dở vẫn chèn lệnh", !controller.textStorage.string.contains("/bang"), "text=\(controller.textStorage.string.debugDescription)")
check("không còn marked text", !tv6.hasMarkedText())

print("== Escape ==")
controller.load(data: nil, plainText: "", config: PageConfig()); pump()
let tv7 = controller.activeTextView!
window.makeFirstResponder(tv7)
tv7.insertText("/", replacementRange: NSRange(location: 0, length: 0)); pump()
tv7.keyDown(with: key(53, "\u{1b}")); pump()
check("Escape đóng menu và giữ dấu /", controller.slashTrigger == nil && controller.textStorage.string == "/", "text=\(controller.textStorage.string.debugDescription)")
tv7.insertText("x", replacementRange: tv7.selectedRange()); pump()
check("gõ tiếp sau Escape không mở lại", controller.slashTrigger == nil)


print("== bộ gõ giữ selection trên marked text ==")
controller.load(data: nil, plainText: "", config: PageConfig()); pump()
let tv8 = controller.activeTextView!
window.makeFirstResponder(tv8)
tv8.setMarkedText("/", selectedRange: NSRange(location: 0, length: 1), replacementRange: NSRange(location: 0, length: 0)); pump()
check("/ là marked text đang được chọn vẫn mở menu", controller.slashTrigger == 0, "trigger=\(String(describing: controller.slashTrigger)) sel=\(tv8.selectedRange()) marked=\(tv8.hasMarkedText())")


print("== Esc rồi xóa / rồi gõ lại / ==")
controller.load(data: nil, plainText: "", config: PageConfig()); pump()
let tv9 = controller.activeTextView!
window.makeFirstResponder(tv9)
tv9.insertText("/", replacementRange: NSRange(location: 0, length: 0)); pump()
tv9.keyDown(with: key(53, "\u{1b}")); pump()
check("Esc đóng", controller.slashTrigger == nil)
tv9.keyDown(with: key(51, "\u{7f}")); pump()   // Backspace
check("xóa được dấu /", controller.textStorage.string.isEmpty, "text=\(controller.textStorage.string.debugDescription)")
tv9.insertText("/", replacementRange: NSRange(location: 0, length: 0)); pump()
check("gõ / lại thì menu mở lại", controller.slashTrigger == 0, "trigger=\(String(describing: controller.slashTrigger))")
tv9.keyDown(with: key(36, "\r")); pump()
check("Enter sau đó vẫn chèn được", !controller.textStorage.string.contains("/"), "text=\(controller.textStorage.string.debugDescription)")


print("== kéo đường biên lề trên trang ==")
controller.load(data: nil, plainText: "nội dung", config: PageConfig()); pump()
controller.canvasOptions.showMarginGuides = true
host.canvas.applyConfig(controller.config, options: controller.canvasOptions); pump()
let page = host.canvas.pages[0]
let m0 = controller.config.margins
func mouse(_ type: NSEvent.EventType, _ pInPage: NSPoint) -> NSEvent {
    let inWindow = page.convert(pInPage, to: nil)
    return NSEvent.mouseEvent(with: type, location: inWindow, modifierFlags: [], timestamp: 0,
                              windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
}
let leftGuide = NSPoint(x: m0.left, y: 300)
let hitOnGuide = page.hitTest(page.convert(leftGuide, to: page.superview))
check("hitTest trên đường biên trả về PageView", hitOnGuide === page, "got \(String(describing: hitOnGuide))")
let hitInside = page.hitTest(page.convert(NSPoint(x: 200, y: 300), to: page.superview))
check("hitTest trong vùng chữ trả về text view", hitInside is PageTextView, "got \(String(describing: hitInside))")

page.mouseDown(with: mouse(.leftMouseDown, leftGuide))
page.mouseDragged(with: mouse(.leftMouseDragged, NSPoint(x: 100, y: 300)))
page.mouseUp(with: mouse(.leftMouseUp, NSPoint(x: 100, y: 300)))
let step = Unit.current.snapStep
check("kéo biên trái đổi lề trái", abs(controller.config.margins.left - Unit.snap(100)) < 0.01, "left=\(controller.config.margins.left)")
check("lề bám bước đơn vị", abs((controller.config.margins.left / step).rounded() * step - controller.config.margins.left) < 0.01)
check("lề phải không đổi", controller.config.margins.right == m0.right)

let bottomGuide = NSPoint(x: 300, y: controller.config.size.height - m0.bottom)
page.mouseDown(with: mouse(.leftMouseDown, bottomGuide))
page.mouseDragged(with: mouse(.leftMouseDragged, NSPoint(x: 300, y: controller.config.size.height - 40)))
page.mouseUp(with: mouse(.leftMouseUp, NSPoint(x: 300, y: controller.config.size.height - 40)))
check("kéo biên dưới đổi lề dưới", abs(controller.config.margins.bottom - Unit.snap(40)) < 0.01, "bottom=\(controller.config.margins.bottom)")

page.mouseDown(with: mouse(.leftMouseDown, NSPoint(x: controller.config.margins.left, y: 300)))
page.mouseDragged(with: mouse(.leftMouseDragged, NSPoint(x: 900, y: 300)))
page.mouseUp(with: mouse(.leftMouseUp, NSPoint(x: 900, y: 300)))
check("kéo quá đà bị kẹp, vùng chữ còn ≥ 80pt", controller.config.contentSize.width >= 80, "content=\(controller.config.contentSize)")


print("== chọn kiểu bằng / trước rồi mới gõ chữ ==")
controller.load(data: nil, plainText: "Dòng cũ", config: PageConfig()); pump()
let tvPre = controller.activeTextView!
window.makeFirstResponder(tvPre)
tvPre.setSelectedRange(NSRange(location: controller.textStorage.length, length: 0))
tvPre.insertText("\n", replacementRange: tvPre.selectedRange()); pump()
tvPre.insertText("/", replacementRange: tvPre.selectedRange()); pump()
if let h1 = controller.slashModel.commands.first(where: { $0.id == "h1" }) {
    controller.slashModel.selection = controller.slashModel.commands.firstIndex { $0.id == "h1" } ?? 0
}
tvPre.keyDown(with: key(36, "\r")); pump()
check("dòng trống cuối tài liệu: / bị xóa", !controller.textStorage.string.contains("/"), "text=\(controller.textStorage.string.debugDescription)")
check("toolbar báo Đầu mục 1 ngay khi chưa gõ", controller.format.style == .heading1, "got \(controller.format.style)")
tvPre.insertText("Da", replacementRange: tvPre.selectedRange()); pump()
let typedFont = controller.textStorage.attribute(.font, at: controller.textStorage.length - 1, effectiveRange: nil) as? NSFont
check("chữ gõ sau đó mang cỡ đầu mục", (typedFont?.pointSize ?? 0) >= 22, "size=\(typedFont?.pointSize ?? -1)")
check("dòng cũ giữ nguyên cỡ thường", (controller.textStorage.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)?.pointSize == 13)
check("mục lục có 'Da'", controller.outline.map(\.text) == ["Da"], "got \(controller.outline.map(\.text))")

print("== dòng trống ở giữa tài liệu ==")
controller.load(data: nil, plainText: "trên\n\ndưới", config: PageConfig()); pump()
let tvMid = controller.activeTextView!
window.makeFirstResponder(tvMid)
tvMid.setSelectedRange(NSRange(location: 5, length: 0))
tvMid.insertText("/", replacementRange: tvMid.selectedRange()); pump()
controller.slashModel.selection = controller.slashModel.commands.firstIndex { $0.id == "h2" } ?? 0
tvMid.keyDown(with: key(36, "\r")); pump()
tvMid.insertText("Giữa", replacementRange: tvMid.selectedRange()); pump()
let midFont = controller.textStorage.attribute(.font, at: 6, effectiveRange: nil) as? NSFont
check("đầu mục 2 áp cho dòng giữa", (midFont?.pointSize ?? 0) >= 18, "size=\(midFont?.pointSize ?? -1) text=\(controller.textStorage.string.debugDescription)")
check("dòng 'dưới' không bị lây", (controller.textStorage.attribute(.font, at: controller.textStorage.length - 1, effectiveRange: nil) as? NSFont)?.pointSize == 13)

print("== / trên dòng trống chọn danh sách / trích dẫn ==")
controller.load(data: nil, plainText: "x\n", config: PageConfig()); pump()
let tvList = controller.activeTextView!
window.makeFirstResponder(tvList)
tvList.setSelectedRange(NSRange(location: 2, length: 0))
tvList.insertText("/", replacementRange: tvList.selectedRange()); pump()
controller.slashModel.selection = controller.slashModel.commands.firstIndex { $0.id == "bullet" } ?? 0
tvList.keyDown(with: key(36, "\r")); pump()
tvList.insertText("mục", replacementRange: tvList.selectedRange()); pump()
check("danh sách chấm trên dòng trống", controller.textStorage.string.hasSuffix("•\tmục"), "text=\(controller.textStorage.string.debugDescription)")

controller.load(data: nil, plainText: "x\n", config: PageConfig()); pump()
let tvQ = controller.activeTextView!
window.makeFirstResponder(tvQ)
tvQ.setSelectedRange(NSRange(location: 2, length: 0))
tvQ.insertText("/", replacementRange: tvQ.selectedRange()); pump()
controller.slashModel.selection = controller.slashModel.commands.firstIndex { $0.id == "quote" } ?? 0
tvQ.keyDown(with: key(36, "\r")); pump()
tvQ.insertText("câu", replacementRange: tvQ.selectedRange()); pump()
let qStyle = controller.textStorage.attribute(.paragraphStyle, at: controller.textStorage.length - 1, effectiveRange: nil) as? NSParagraphStyle
let qFont = controller.textStorage.attribute(.font, at: controller.textStorage.length - 1, effectiveRange: nil) as? NSFont
check("trích dẫn trên dòng trống: có vạch và nghiêng", (qStyle?.textBlocks.count ?? 0) == 1 && NSFontManager.shared.traits(of: qFont!).contains(.italicFontMask), "blocks=\(qStyle?.textBlocks.count ?? -1)")


print("== cột đọc kiểu Notion: không scale, giãn theo cửa sổ ==")
controller.load(data: nil, plainText: "cột", config: PageConfig()); pump()
controller.canvasOptions.continuous = true; controller.canvasOptions.fullWidth = false
host.apply(options: controller.canvasOptions)
window.setContentSize(NSSize(width: 900, height: 800)); host.frame = window.contentView!.bounds; host.layoutSubtreeIfNeeded(); pump()
check("không có magnification", abs(host.scrollView.magnification - 1) < 0.001)
check("cửa sổ 900: mép 7,5% → cột 764 canh giữa", host.canvas.contentWidth == 764 && abs(host.canvas.contentLeading - 68) < 1, "w=\(host.canvas.contentWidth) x=\(host.canvas.contentLeading)")
window.setContentSize(NSSize(width: 1800, height: 800)); host.frame = window.contentView!.bounds; host.layoutSubtreeIfNeeded(); pump()
check("cửa sổ 1800: cột 1530 canh giữa", host.canvas.contentWidth == 1530 && abs(host.canvas.contentLeading - 135) < 1, "w=\(host.canvas.contentWidth) x=\(host.canvas.contentLeading)")
window.setContentSize(NSSize(width: 600, height: 800)); host.frame = window.contentView!.bounds; host.layoutSubtreeIfNeeded(); pump()
check("cửa sổ hẹp 600: cột 510", host.canvas.contentWidth == 510, "w=\(host.canvas.contentWidth)")
controller.canvasOptions.fullWidth = true; host.apply(options: controller.canvasOptions)
window.setContentSize(NSSize(width: 1800, height: 800)); host.frame = window.contentView!.bounds; host.layoutSubtreeIfNeeded(); pump()
check("toàn chiều rộng 1800: mép 3% → cột 1692", host.canvas.contentWidth == 1692, "w=\(host.canvas.contentWidth)")
controller.canvasOptions.fullWidth = false
controller.canvasOptions.smallText = true; host.apply(options: controller.canvasOptions); host.layoutSubtreeIfNeeded(); pump()
check("chữ nhỏ: scale 0,875", abs(host.scrollView.magnification - 0.875) < 0.001, "mag=\(host.scrollView.magnification)")
check("chữ nhỏ: cột nhìn vẫn 1530, chứa nhiều chữ hơn", abs(host.canvas.contentWidth * 0.875 - 1530) < 1.5, "docW=\(host.canvas.contentWidth) visual=\(host.canvas.contentWidth * 0.875)")
controller.canvasOptions.smallText = false; host.apply(options: controller.canvasOptions); host.layoutSubtreeIfNeeded(); pump()
check("tắt chữ nhỏ về 1:1", abs(host.scrollView.magnification - 1) < 0.001)
check("chỉ một container, không phân trang", controller.layoutManager.textContainers.count == 1 && controller.pageCount == 1)
controller.canvasOptions.fullWidth = false
controller.canvasOptions.continuous = false; host.apply(options: controller.canvasOptions); host.layoutSubtreeIfNeeded(); pump()
controller.load(data: nil, plainText: (1...300).map { "Dòng \($0) thử phân trang giấy rời." }.joined(separator: "\n"), config: PageConfig()); pump()
host.canvas.updatePagination()
check("trang giấy rời vẫn phân trang", controller.pageCount > 2, "pages=\(controller.pageCount)")
controller.canvasOptions.continuous = true; host.apply(options: controller.canvasOptions); pump()
host.canvas.updatePagination()
check("về liên tục thì gộp lại một cột", controller.layoutManager.textContainers.count == 1)
window.setContentSize(NSSize(width: 900, height: 800)); host.frame = window.contentView!.bounds; host.layoutSubtreeIfNeeded(); pump()

print("== chọn ảnh, đổi kích thước, kéo thả ==")
controller.load(data: nil, plainText: "", config: PageConfig()); pump()
let tvImg = controller.activeTextView as! PageTextView
window.makeFirstResponder(tvImg)
let pic = NSImage(size: NSSize(width: 800, height: 400))
pic.lockFocus(); NSColor.systemGreen.setFill(); NSRect(x: 0, y: 0, width: 800, height: 400).fill(); pic.unlockFocus()
controller.insertImage(pic); pump()
let w0 = controller.attachment(at: 0)?.bounds.width ?? 0
check("ảnh chèn vừa vùng chữ", abs(w0 - controller.config.contentSize.width) < 1, "w=\(w0)")
// click on the picture selects it
let rect0 = controller.attachmentRect(at: 0, in: tvImg)!
tvImg.mouseDown(with: NSEvent.mouseEvent(with: .leftMouseDown, location: tvImg.convert(NSPoint(x: rect0.midX, y: rect0.midY), to: nil), modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!)
pump()
check("click chọn nguyên ảnh", tvImg.selectedRange() == NSRange(location: 0, length: 1), "sel=\(tvImg.selectedRange())")
check("thanh công cụ ảnh hiện", controller.selectedAttachmentIndex == 0)
controller.resizeSelectedAttachment(fraction: 0.5); pump()
let w1 = controller.attachment(at: 0)?.bounds.width ?? 0
check("đổi về 1/2 chiều rộng", abs(w1 - controller.config.contentSize.width * 0.5) < 1, "w=\(w1)")
check("giữ tỉ lệ ảnh", abs((controller.attachment(at: 0)?.bounds.height ?? 0) - w1 / 2) < 1)
// drag the corner handle
let rect1 = controller.attachmentRect(at: 0, in: tvImg)!
let handle = NSPoint(x: rect1.maxX, y: rect1.maxY)
func ev(_ t: NSEvent.EventType, _ p: NSPoint) -> NSEvent {
    NSEvent.mouseEvent(with: t, location: tvImg.convert(p, to: nil), modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
}
tvImg.mouseDown(with: ev(.leftMouseDown, handle))
tvImg.mouseDragged(with: ev(.leftMouseDragged, NSPoint(x: handle.x + 60, y: handle.y)))
tvImg.mouseUp(with: ev(.leftMouseUp, NSPoint(x: handle.x + 60, y: handle.y)))
pump()
let w2 = controller.attachment(at: 0)?.bounds.width ?? 0
check("kéo góc phóng to ảnh thêm 60pt", abs(w2 - (w1 + 60)) < 1.5, "w=\(w2)")
tvImg.undoManager?.undo(); pump()
check("Undo trả lại kích thước trước", abs((controller.attachment(at: 0)?.bounds.width ?? 0) - w1) < 1.5, "w=\(controller.attachment(at: 0)?.bounds.width ?? -1)")
controller.deleteSelectedAttachment(); pump()
check("xóa ảnh", !controller.textStorage.containsAttachments)

// drop an image file
let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("drop.png")
try? pic.tiffRepresentation.flatMap { NSBitmapImageRep(data: $0)?.representation(using: .png, properties: [:]) }?.write(to: tmp)
let dropPB = NSPasteboard(name: NSPasteboard.Name("bnote.drop"))
dropPB.clearContents(); dropPB.writeObjects([tmp as NSURL])
check("kéo thả file ảnh vào trang", controller.handleDrop(dropPB, at: NSPoint(x: 10, y: 10), in: tvImg) && controller.textStorage.containsAttachments)


print("== Enter sau đầu mục về Văn bản ==")
controller.load(data: nil, plainText: "", config: PageConfig()); pump()
let tvH = controller.activeTextView!
window.makeFirstResponder(tvH)
tvH.insertText("/", replacementRange: NSRange(location: 0, length: 0)); pump()
controller.slashModel.selection = controller.slashModel.commands.firstIndex { $0.id == "h1" } ?? 0
tvH.keyDown(with: key(36, "\r")); pump()
tvH.insertText("Tiêu đề", replacementRange: tvH.selectedRange()); pump()
tvH.keyDown(with: key(36, "\r")); pump()
tvH.insertText("thân bài", replacementRange: tvH.selectedRange()); pump()
let hFont = controller.textStorage.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
let bFont = controller.textStorage.attribute(.font, at: controller.textStorage.length - 1, effectiveRange: nil) as? NSFont
check("dòng đầu vẫn là đầu mục", (hFont?.pointSize ?? 0) >= 22, "size=\(hFont?.pointSize ?? -1)")
check("dòng sau Enter là văn bản thường", bFont?.pointSize == 13, "size=\(bFont?.pointSize ?? -1) text=\(controller.textStorage.string.debugDescription)")
check("toolbar báo Văn bản", controller.format.style == .body, "got \(controller.format.style)")
// Enter mid-heading keeps both halves as heading
controller.load(data: nil, plainText: "Đầu mục dài", config: PageConfig()); pump()
let tvM = controller.activeTextView!
tvM.setSelectedRange(NSRange(location: 0, length: controller.textStorage.length)); controller.apply(style: .heading2)
tvM.setSelectedRange(NSRange(location: 7, length: 0))
tvM.keyDown(with: key(36, "\r")); pump()
let secondHalf = controller.textStorage.attribute(.font, at: 9, effectiveRange: nil) as? NSFont
check("Enter giữa đầu mục giữ nửa sau là đầu mục", (secondHalf?.pointSize ?? 0) >= 18, "size=\(secondHalf?.pointSize ?? -1)")

print("== mặc định 0,75 in ==")
Defaults.register()
check("lề mặc định 54pt = 0,75 in", Defaults.pageConfig.margins == PageMargins(uniform: 54))
check("hiển thị 0,75 in", Unit.format(54) == "0,75 in", "got \(Unit.format(54))")
check("snap theo 1/8 in", Unit.snap(50) == 54, "got \(Unit.snap(50))")
check("biên lề tắt, liên tục bật mặc định", !Defaults.canvasOptions.showMarginGuides && Defaults.canvasOptions.continuous)


print("== phím tắt markdown ==")
func freshLine() -> NSTextView {
    controller.load(data: nil, plainText: "", config: PageConfig()); pump()
    let tv = controller.activeTextView!
    window.makeFirstResponder(tv)
    tv.setSelectedRange(NSRange(location: 0, length: 0))
    return tv
}
func typeText(_ tv: NSTextView, _ text: String) {
    for ch in text { tv.insertText(String(ch), replacementRange: tv.selectedRange()); pump() }
}
var tvMD = freshLine(); typeText(tvMD, "- mua sữa")
check("'- ' thành danh sách chấm", controller.textStorage.string == "•\tmua sữa", "got \(controller.textStorage.string.debugDescription)")
tvMD = freshLine(); typeText(tvMD, "1. bước một")
check("'1. ' thành danh sách số", controller.textStorage.string == "1.\tbước một", "got \(controller.textStorage.string.debugDescription)")
tvMD = freshLine(); typeText(tvMD, "[] việc")
check("'[] ' thành việc cần làm", controller.textStorage.string == "☐\tviệc", "got \(controller.textStorage.string.debugDescription)")
tvMD = freshLine(); typeText(tvMD, "# Tiêu đề")
let mdH = controller.textStorage.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
check("'# ' thành đầu mục 1", controller.textStorage.string == "Tiêu đề" && (mdH?.pointSize ?? 0) >= 22, "got \(controller.textStorage.string.debugDescription) size=\(mdH?.pointSize ?? -1)")
tvMD = freshLine(); typeText(tvMD, "## Nhỏ")
check("'## ' thành đầu mục 2", (controller.textStorage.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)?.pointSize == 19)
tvMD = freshLine(); typeText(tvMD, "> câu")
check("'> ' thành trích dẫn", ((controller.textStorage.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)?.textBlocks.count ?? 0) == 1 && controller.textStorage.string == "câu")
tvMD = freshLine(); typeText(tvMD, "``` let x")
check("'``` ' thành khối mã", controller.isCodeParagraph(at: 0) && controller.textStorage.string == "let x", "got \(controller.textStorage.string.debugDescription)")
tvMD = freshLine(); typeText(tvMD, "giá 1. rẻ")
check("'1.' giữa câu không kích hoạt", controller.textStorage.string == "giá 1. rẻ", "got \(controller.textStorage.string.debugDescription)")
tvMD = freshLine(); typeText(tvMD, "- a"); tvMD.insertText("\n", replacementRange: tvMD.selectedRange()); pump(); typeText(tvMD, "- b")
check("gõ '- ' trong mục đã là danh sách thì giữ nguyên chữ", controller.textStorage.string.hasSuffix("•\t- b"), "got \(controller.textStorage.string.debugDescription)")

print("== xóa hết chữ đầu mục thì về Văn bản ==")
tvMD = freshLine(); typeText(tvMD, "# Ab")
check("đang là đầu mục", controller.format.style == .heading1)
tvMD.doCommand(by: #selector(NSResponder.deleteBackward(_:))); pump()
tvMD.doCommand(by: #selector(NSResponder.deleteBackward(_:))); pump()
check("xóa hết thì kiểu về Văn bản", controller.format.style == .body, "got \(controller.format.style)")
typeText(tvMD, "x")
check("chữ gõ tiếp là cỡ thường", (controller.textStorage.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)?.pointSize == 13)
// heading in the middle of a document
controller.load(data: nil, plainText: "trên\nAb\ndưới", config: PageConfig()); pump()
let tvMid2 = controller.activeTextView!; window.makeFirstResponder(tvMid2)
tvMid2.setSelectedRange(NSRange(location: 5, length: 2)); controller.apply(style: .heading2)
tvMid2.setSelectedRange(NSRange(location: 7, length: 0))
tvMid2.doCommand(by: #selector(NSResponder.deleteBackward(_:))); pump()
tvMid2.doCommand(by: #selector(NSResponder.deleteBackward(_:))); pump()
let midStyle2 = TextStyle.detect(font: controller.textStorage.attribute(.font, at: 5, effectiveRange: nil) as? NSFont, paragraph: controller.textStorage.attribute(.paragraphStyle, at: 5, effectiveRange: nil) as? NSParagraphStyle)
check("đầu mục giữa tài liệu xóa hết cũng về Văn bản", midStyle2 == .body && controller.textStorage.string == "trên\n\ndưới", "style=\(midStyle2) text=\(controller.textStorage.string.debugDescription)")

print("== placeholder theo font đang chọn ==")
tvMD = freshLine(); controller.apply(style: .heading1)
check("typing font là đầu mục khi trống", ((tvMD.typingAttributes[.font] as? NSFont)?.pointSize ?? 0) >= 22)


print("== danh sách lồng cấp, Tab, Backspace ==")
var tvL = freshLine(); typeText(tvL, "- một"); tvL.insertText("\n", replacementRange: tvL.selectedRange()); pump(); typeText(tvL, "hai")
tvL.doCommand(by: #selector(NSResponder.insertTab(_:))); pump()
check("Tab lồng mục: glyph đổi thành ◦", controller.textStorage.string == "•\tmột\n◦\thai", "got \(controller.textStorage.string.debugDescription)")
let lvl1 = controller.textStorage.attribute(.paragraphStyle, at: 6, effectiveRange: nil) as? NSParagraphStyle
check("Tab tăng thụt lề", (lvl1?.firstLineHeadIndent ?? 0) >= EditorDefaults.tabIndent - 0.5, "indent=\(lvl1?.firstLineHeadIndent ?? -1)")
tvL.doCommand(by: #selector(NSResponder.insertBacktab(_:))); pump()
check("Shift-Tab về cấp 0, glyph •", controller.textStorage.string == "•\tmột\n•\thai", "got \(controller.textStorage.string.debugDescription)")
tvL.setSelectedRange(NSRange(location: 8, length: 0))   // right after "•\t" of second item
tvL.doCommand(by: #selector(NSResponder.deleteBackward(_:))); pump()
check("Backspace sau marker thì bỏ marker, giữ chữ", controller.textStorage.string == "•\tmột\nhai", "got \(controller.textStorage.string.debugDescription)")

tvL = freshLine(); typeText(tvL, "1. a"); tvL.insertText("\n", replacementRange: tvL.selectedRange()); pump()
typeText(tvL, "b"); tvL.doCommand(by: #selector(NSResponder.insertTab(_:))); pump()
tvL.insertText("\n", replacementRange: tvL.selectedRange()); pump(); typeText(tvL, "c")
tvL.insertText("\n", replacementRange: tvL.selectedRange()); pump(); typeText(tvL, "d")
tvL.doCommand(by: #selector(NSResponder.insertBacktab(_:))); pump()
check("đánh số theo cấp: 1 / 1 2 / 2", controller.textStorage.string == "1.\ta\n1.\tb\n2.\tc\n2.\td", "got \(controller.textStorage.string.debugDescription)")

print("== Tab trong đoạn thường thụt lề, trong khối mã chèn tab ==")
tvL = freshLine(); typeText(tvL, "đoạn")
tvL.doCommand(by: #selector(NSResponder.insertTab(_:))); pump()
check("Tab đoạn thường: thụt lề, không chèn ký tự", !controller.textStorage.string.contains("\t") && ((controller.textStorage.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)?.firstLineHeadIndent ?? 0) > 0)

print("== cuộn mục lục lên đầu ==")
let long = (1...400).map { "Dòng số \($0): nội dung thử nghiệm phân trang." }.joined(separator: "\n")
controller.load(data: nil, plainText: long, config: PageConfig()); pump()
let tvO = controller.activeTextView!
let target = (controller.textStorage.string as NSString).range(of: "Dòng số 300:").location
tvO.setSelectedRange(NSRange(location: target, length: 12)); controller.apply(style: .heading1); pump()
if let item = controller.outline.first(where: { $0.text.hasPrefix("Dòng số 300") }) {
    controller.scrollToOutlineItem(item); pump(); pump(); pump()
    let clipY = host.scrollView.contentView.bounds.origin.y
    let lm = controller.layoutManager
    let g = lm.glyphIndexForCharacter(at: item.location)
    let container = lm.textContainer(forGlyphAt: g, effectiveRange: nil)!
    let page = host.canvas.pages.first { $0.textView.textContainer === container }!
    let rect = page.textView.convert(lm.boundingRect(forGlyphRange: NSRange(location: g, length: 1), in: container), to: host.canvas)
    check("đầu mục nằm sát mép trên vùng nhìn", abs(rect.minY - clipY - 14) < 2, "headingY=\(rect.minY) clipY=\(clipY)")
} else { check("có mục trong mục lục", false) }

print("== export kèm bìa và tiêu đề ==")
let coverImg2 = NSImage(size: NSSize(width: 800, height: 500)); coverImg2.lockFocus(); NSColor.systemTeal.setFill(); NSRect(x: 0, y: 0, width: 800, height: 500).fill(); coverImg2.unlockFocus()
let header = ExportHeader(title: "Kịch bản", subtitle: "Bản nháp 1", cover: coverImg2, coverFocus: 0.5, icon: "🎬")
let composed = header.prepend(to: NSAttributedString(string: "Nội dung.", attributes: EditorDefaults.bodyAttributes), contentWidth: 487)
check("export bắt đầu bằng ảnh bìa", composed.containsAttachments && (composed.attribute(.attachment, at: 0, effectiveRange: nil) as? NSTextAttachment)?.bounds.width == 487)
check("export có tiêu đề + phụ đề + nội dung", composed.string.contains("🎬 Kịch bản") && composed.string.contains("Bản nháp 1") && composed.string.hasSuffix("Nội dung."))
let mdOut = MarkdownConverter.markdown(from: composed)
check("markdown export có tiêu đề dạng #", mdOut.contains("# 🎬 Kịch bản"), "got \(mdOut.prefix(60))")

print("== kiểu chữ theo font ==")
let faces = DocumentController.faces(of: "Helvetica Neue")
check("Helvetica Neue có nhiều kiểu (Light/Bold/Condensed…)", faces.count >= 6, "got \(faces.map(\.style))")
controller.load(data: nil, plainText: "chữ", config: PageConfig()); pump()
let tvF = controller.activeTextView!
tvF.setSelectedRange(NSRange(location: 0, length: 3))
if let light = faces.first(where: { $0.style.lowercased().contains("light") && !$0.style.lowercased().contains("italic") }) {
    controller.setFontFace(light.name)
    let f = controller.textStorage.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
    check("đổi sang Light giữ cỡ 13", f?.fontName == light.name && f?.pointSize == 13, "got \(f?.fontName ?? "nil") \(f?.pointSize ?? -1)")
    check("toolbar báo đúng kiểu", controller.format.fontName == light.name)
    controller.toggleTrait(.boldFontMask)
    let b = controller.textStorage.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
    check("đậm từ Light vẫn cùng họ font", b?.familyName == "Helvetica Neue" && NSFontManager.shared.traits(of: b!).contains(.boldFontMask), "got \(b?.fontName ?? "nil")")
}


print("== Enter reset định dạng ==")
var tvR = freshLine(); typeText(tvR, "đậm")
tvR.setSelectedRange(NSRange(location: 0, length: 3)); controller.toggleTrait(.boldFontMask); controller.setTextColor(.systemRed)
tvR.setSelectedRange(NSRange(location: 3, length: 0))
tvR.keyDown(with: key(36, "\r")); pump(); typeText(tvR, "x")
let rf = controller.textStorage.attribute(.font, at: 4, effectiveRange: nil) as? NSFont
let rc = controller.textStorage.attribute(.foregroundColor, at: 4, effectiveRange: nil) as? NSColor
check("sau Enter: hết đậm", !NSFontManager.shared.traits(of: rf!).contains(.boldFontMask))
check("sau Enter: hết màu", rc == nil || rc == NSColor.textColor, "got \(String(describing: rc))")
tvR = freshLine(); typeText(tvR, "- mục"); tvR.keyDown(with: key(36, "\r")); pump()
check("danh sách vẫn tiếp tục", controller.textStorage.string.hasSuffix("•\t"), "got \(controller.textStorage.string.debugDescription)")
tvR = freshLine(); typeText(tvR, "``` code"); tvR.keyDown(with: key(36, "\r")); pump()
check("khối mã vẫn tiếp tục", controller.isCodeParagraph(at: controller.textStorage.length))

print("== hai tuỳ chọn kiểu Notion: mép theo %, chữ nhỏ không cuộn ngang ==")
controller.load(data: nil, plainText: String(repeating: "chữ ", count: 400), config: PageConfig()); pump()
controller.canvasOptions = Defaults.canvasOptions
host.apply(options: controller.canvasOptions)
window.setContentSize(NSSize(width: 1000, height: 800)); host.frame = window.contentView!.bounds; host.layoutSubtreeIfNeeded(); pump()
let colW = host.canvas.contentWidth
check("mặc định: mép 7,5% (75pt) → cột 850", colW == 850 && abs(host.canvas.contentLeading - 75) < 1, "w=\(colW) x=\(host.canvas.contentLeading)")
controller.canvasOptions.fullWidth = true; host.apply(options: controller.canvasOptions); host.layoutSubtreeIfNeeded(); pump()
check("toàn rộng: mép 3% (30pt) → cột 940", host.canvas.contentWidth == 940, "w=\(host.canvas.contentWidth)")
controller.canvasOptions.fullWidth = false; host.apply(options: controller.canvasOptions); host.layoutSubtreeIfNeeded(); pump()
controller.canvasOptions.smallText = true; host.apply(options: controller.canvasOptions); host.layoutSubtreeIfNeeded(); pump()
check("chữ nhỏ: magnification 0,875", abs(host.scrollView.magnification - 0.875) < 0.001)
check("chữ nhỏ: tài liệu vừa khít cửa sổ, không cuộn ngang", abs(host.canvas.frame.width * 0.875 - 1000) < 1.5, "docW=\(host.canvas.frame.width)")
check("chữ nhỏ: cột nhìn vẫn 850", abs(host.canvas.contentWidth * 0.875 - 850) < 1.5, "docW=\(host.canvas.contentWidth)")
check("chỉ còn hai mức: 1 và 0,875", CanvasOptions.smallTextScale == 0.875 && CanvasOptions().magnification == 1)
controller.canvasOptions.smallText = false; host.apply(options: controller.canvasOptions); pump()

print(failures.isEmpty ? "\nTẤT CẢ ĐỀU ĐẠT" : "\nTHẤT BẠI (\(failures.count)): \(failures.joined(separator: " | "))")
exit(failures.isEmpty ? 0 : 1)
