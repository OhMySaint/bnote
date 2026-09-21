import AppKit
import SwiftUI
import SwiftData

let app = NSApplication.shared
app.setActivationPolicy(.regular)

var failures: [String] = []
func check(_ label: String, _ condition: Bool, _ detail: String = "") {
    print(condition ? "  ok   \(label)" : "  FAIL \(label) \(detail)")
    if !condition { failures.append(label) }
}
func pump(_ s: TimeInterval = 0.1) { RunLoop.main.run(until: Date().addingTimeInterval(s)) }

let container = try! ModelContainer(for: Note.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
let note = Note(title: "Thử")
MainActor.assumeIsolated { container.mainContext.insert(note) }

let controller = DocumentController.shared
let root = NoteEditorView(note: note, controller: controller, showInspector: .constant(true), inspectorTab: .constant(.outline))
    .modelContainer(container)
let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 800),
                      styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
window.contentView = NSHostingView(rootView: root)
window.makeKeyAndOrderFront(nil)
NSApp.activate(ignoringOtherApps: true)
pump(0.6)
print("before: keyWindow=\(String(describing: NSApp.keyWindow.map { type(of: $0) })) isKey=\(window.isKeyWindow) active=\(NSApp.isActive)")

controller.load(data: nil, plainText: "", config: PageConfig())
controller.focusEditor()
pump(0.3)

func key(_ code: UInt16, _ chars: String) -> NSEvent {
    NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                     windowNumber: window.windowNumber, context: nil,
                     characters: chars, charactersIgnoringModifiers: chars,
                     isARepeat: false, keyCode: code)!
}
func send(_ e: NSEvent) { NSApp.sendEvent(e); pump(0.1) }

let fr = window.firstResponder
print("first responder: \(type(of: fr as Any))")
check("text view là first responder", fr is PageTextView)

print("== gõ / bằng sự kiện thật ==")
send(key(44, "/"))
check("dấu / vào văn bản", controller.textStorage.string == "/", "text=\(controller.textStorage.string.debugDescription)")
check("menu mở", controller.isSlashMenuOpen, "trigger=\(String(describing: controller.slashTrigger)) cmds=\(controller.slashModel.commands.count)")
let panelVisible = NSApp.windows.contains { $0 is NSPanel && $0.isVisible }
check("panel hiển thị", panelVisible)
print("after: keyWindow=\(String(describing: NSApp.keyWindow.map { type(of: $0) })) isKey=\(window.isKeyWindow) panelIsKey=\(NSApp.windows.first { $0 is NSPanel }?.isKeyWindow ?? false)")
check("cửa sổ chính vẫn là key", window.isKeyWindow, "key=\(String(describing: NSApp.keyWindow))")
check("first responder vẫn là text view", window.firstResponder is PageTextView, "fr=\(type(of: window.firstResponder as Any))")

print("== ↓ rồi Return bằng sự kiện thật ==")
send(key(125, ""))
check("↓ đổi mục", controller.slashModel.selection == 1, "sel=\(controller.slashModel.selection)")
send(key(36, "\r"))
check("Return chèn lệnh", controller.slashTrigger == nil && !controller.textStorage.string.contains("/"),
      "text=\(controller.textStorage.string.debugDescription) trigger=\(String(describing: controller.slashTrigger))")
check("không chèn xuống dòng", !controller.textStorage.string.contains("\n"), "text=\(controller.textStorage.string.debugDescription)")

print("== Tab ==")
controller.load(data: nil, plainText: "", config: PageConfig()); controller.focusEditor(); pump(0.2)
send(key(44, "/"))
send(key(48, "\t"))
check("Tab chèn lệnh", controller.slashTrigger == nil && !controller.textStorage.string.contains("/") && !controller.textStorage.string.contains("\t"),
      "text=\(controller.textStorage.string.debugDescription)")


print("== panel không thể thành key ==")
controller.load(data: nil, plainText: "", config: PageConfig()); controller.focusEditor(); pump(0.2)
send(key(44, "/"))
if let panel = NSApp.windows.first(where: { $0 is NSPanel && $0.isVisible }) {
    panel.makeKey()
    check("makeKey trên panel bị từ chối", !panel.canBecomeKey && !panel.isKeyWindow)
} else { check("có panel để thử", false) }

print("== bộ gõ đưa Return thành văn bản ==")
controller.load(data: nil, plainText: "", config: PageConfig()); controller.focusEditor(); pump(0.2)
send(key(44, "/"))
let tvIME = controller.activeTextView!
tvIME.insertText("\n", replacementRange: tvIME.selectedRange()); pump(0.1)
check("\\n dạng văn bản vẫn chèn lệnh, không xuống dòng", controller.slashTrigger == nil && !controller.textStorage.string.contains("\n") && !controller.textStorage.string.contains("/"),
      "text=\(controller.textStorage.string.debugDescription)")


print("== render đầu trang kiểu Notion ==")
let coverImg = NSImage(size: NSSize(width: 1600, height: 900))
coverImg.lockFocus()
NSGradient(colors: [NSColor(red: 0.1, green: 0.35, blue: 0.6, alpha: 1), NSColor(red: 0.9, green: 0.6, blue: 0.3, alpha: 1)])!.draw(in: NSRect(x: 0, y: 0, width: 1600, height: 900), angle: 20)
NSColor.white.withAlphaComponent(0.5).setFill()
for i in 0..<12 { NSBezierPath(ovalIn: NSRect(x: CGFloat(i) * 140, y: 300 + CGFloat(i % 3) * 120, width: 90, height: 90)).fill() }
coverImg.unlockFocus()
func shoot(_ name: String) {
    pump(0.6)
    window.contentView?.layoutSubtreeIfNeeded()
    pump(0.3)
    if let cv = window.contentView, let rep = cv.bitmapImageRepForCachingDisplay(in: cv.bounds) {
        cv.cacheDisplay(in: cv.bounds, to: rep)
        if let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(name))
            print("  ảnh: \(NSTemporaryDirectory())\(name)")
        }
    }
}
controller.canvasOptions = Defaults.canvasOptions
MainActor.assumeIsolated {
    note.title = "Note chắc chắn là đẹp hơn notion"
    note.icon = "📄"
    note.tags = []
}
controller.load(data: nil, plainText: "Mục1\nNguyên lí cơ bản mac lenin", config: PageConfig())
pump(0.3)
controller.activeTextView?.setSelectedRange(NSRange(location: 0, length: 4)); controller.apply(style: .heading1)
shoot("bnote-editor-plain.png")
MainActor.assumeIsolated {
    note.title = "Gantt Chart (Project Schedule)"
    note.icon = "🗓️"
    note.coverData = coverImg.coverData()
    note.tags = ["dự án", "quý 4"]
}
shoot("bnote-editor.png")
check("bìa nằm trong canvas cuộn", controller.documentView != nil)


print("== thanh tìm kiếm ⌘F ==")
controller.load(data: nil, plainText: "Hà Nội mùa thu, hà nội mùa đông. Sài Gòn nắng quanh năm.", config: PageConfig()); pump(0.3)
controller.showFind(replace: true); pump(0.3)
controller.find.query = "hà nội"; controller.findQueryChanged(); pump(0.3)
shoot("bnote-find.png")
check("thanh tìm: 2 kết quả", controller.find.matches.count == 2, "got \(controller.find.matches.count)")
func findTextField() -> NSTextField? {
    func find(_ v: NSView) -> NSTextField? {
        if let f = v as? NSTextField, f.placeholderString == "Tìm trong trang" { return f }
        for sub in v.subviews { if let f = find(sub) { return f } }
        return nil
    }
    return window.contentView.flatMap(find)
}
check("ô tìm hiển thị với chuỗi", findTextField()?.stringValue == "hà nội", "field=\(String(describing: findTextField()?.stringValue))")
controller.hideFind(); pump(0.3)
check("đóng thanh: ô tìm biến mất", findTextField() == nil)

print("== bấm vào đầu trang ở hai bố cục ==")
MainActor.assumeIsolated { note.coverData = nil; note.coverStyle = ""; note.tags = []; note.title = "hv" }
controller.load(data: nil, plainText: "fsdfs", config: PageConfig()); pump(0.5)
func canvasHost() -> EditorCanvasView? {
    func find(_ v: NSView) -> EditorCanvasView? {
        if let c = v as? EditorCanvasView { return c }
        for sub in v.subviews { if let f = find(sub) { return f } }
        return nil
    }
    return window.contentView.flatMap(find)
}
func clickTagField(label: String) {
    guard let host = canvasHost() else { check("\(label): tìm thấy canvas", false); return }
    // The header overlay sits on top of the canvas; the tag pill is at its bottom-left.
    let layout = controller.headerLayout
    let height = PageHeaderView.height(for: note, width: layout.width)
    let p = NSPoint(x: layout.leading + 40, y: layout.top + height - 22)
    let inWindow = host.convert(p, to: nil)
    let hit = window.contentView?.hitTest(window.contentView!.convert(inWindow, from: nil))
    print("   hitTest → \(hit.map { String(describing: type(of: $0)) } ?? "nil") mag=\(host.enclosingScrollView?.magnification ?? 0)")
    window.makeFirstResponder(controller.activeTextView)
    let down = NSEvent.mouseEvent(with: .leftMouseDown, location: inWindow, modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber, context: nil, eventNumber: 1, clickCount: 1, pressure: 1)!
    let up = NSEvent.mouseEvent(with: .leftMouseUp, location: inWindow, modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber, context: nil, eventNumber: 2, clickCount: 1, pressure: 1)!
    window.sendEvent(down); window.sendEvent(up); pump(0.3)
    let fr = window.firstResponder
    check("\(label): click ô Thêm thẻ chuyển focus khỏi text view", !(fr is PageTextView), "fr=\(String(describing: fr.map { type(of: $0) }))")
}
clickTagField(label: "cột đọc")
controller.canvasOptions.fullWidth = true; pump(0.4); window.contentView?.layoutSubtreeIfNeeded(); pump(0.2)
clickTagField(label: "toàn rộng")
controller.canvasOptions.fullWidth = false; pump(0.2)


print("== cột đọc: nội dung dưới đầu trang, thẳng với tiêu đề ==")
MainActor.assumeIsolated { note.coverData = coverImg.coverData(); note.title = "Gantt Chart (Project Schedule)" }
controller.load(data: nil, plainText: "Nội dung\nDòng hai", config: PageConfig()); pump(0.5); window.contentView?.layoutSubtreeIfNeeded(); pump(0.3)
if let host = canvasHost() {
    let page = host.canvas.pages[0]
    let layout = controller.headerLayout
    let headerH = PageHeaderView.height(for: note, width: layout.width)
    let textTop = page.frame.minY + page.textView.frame.minY - host.scrollView.contentView.bounds.origin.y
    check("chữ bắt đầu ngay dưới đầu trang", abs(textTop - headerH - PagedDocumentView.Metrics.columnTop) < 1.5, "textTop=\(textTop) header=\(headerH)")
    check("cột tiêu đề thẳng với cột chữ", abs(layout.leading - host.canvas.contentLeading) < 1 && abs(layout.width - host.canvas.contentWidth) < 1, "leading=\(layout.leading) col=\(host.canvas.contentLeading)")
    check("không scale", abs(host.scrollView.magnification - 1) < 0.001)
}


print(failures.isEmpty ? "\nTẤT CẢ ĐỀU ĐẠT" : "\nTHẤT BẠI (\(failures.count)): \(failures.joined(separator: " | "))")
exit(failures.isEmpty ? 0 : 1)
