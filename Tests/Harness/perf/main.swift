import AppKit
import SwiftUI
import SwiftData

let app = NSApplication.shared
app.setActivationPolicy(.regular)
func pump(_ s: TimeInterval = 0.05) { RunLoop.main.run(until: Date().addingTimeInterval(s)) }

let container = try! ModelContainer(for: Note.self, Tag.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
let note = Note(title: "Một tiêu đề khá dài để có thể xuống dòng khi cột hẹp lại như thế này đây")
MainActor.assumeIsolated { container.mainContext.insert(note) }
let controller = DocumentController.shared
controller.canvasOptions = CanvasOptions()
let root = NoteEditorView(note: note, controller: controller, showInspector: .constant(true), inspectorTab: .constant(.outline))
    .modelContainer(container)
let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 800), styleMask: [.titled, .resizable], backing: .buffered, defer: false)
window.contentView = NSHostingView(rootView: root)
window.makeKeyAndOrderFront(nil)
pump(0.6)
controller.load(data: nil, plainText: "Một trang ngắn.\nDòng hai.", config: PageConfig()); pump(0.5)
func canvasHost() -> EditorCanvasView? {
    func find(_ v: NSView) -> EditorCanvasView? {
        if let c = v as? EditorCanvasView { return c }
        for sub in v.subviews { if let f = find(sub) { return f } }
        return nil
    }
    return window.contentView.flatMap(find)
}
let host = canvasHost()!
func snapshot(_ label: String) {
    let page = host.canvas.pages[0]
    let l = controller.headerLayout
    let h = PageHeaderView.height(for: note, width: l.width)
    print(String(format: "%-12@ cột x=%5.0f w=%5.0f | header x=%5.0f w=%5.0f cao=%4.0f | text top=%5.0f", label as NSString, host.canvas.contentLeading, host.canvas.contentWidth, l.leading, l.width, h, page.frame.minY))
}
snapshot("trước")
for on in [true, false] {
    let t0 = CFAbsoluteTimeGetCurrent()
    controller.canvasOptions.fullWidth = on
    snapshot(on ? "bật +0ms" : "tắt +0ms")
    for _ in 1...6 { pump(0.016); snapshot(String(format: "+%.0fms", (CFAbsoluteTimeGetCurrent() - t0) * 1000)) }
    pump(0.3); snapshot("yên")
}
exit(0)
