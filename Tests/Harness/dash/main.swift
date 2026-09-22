import AppKit
import SwiftUI
import SwiftData

let app = NSApplication.shared
app.setActivationPolicy(.regular)
func pump(_ s: TimeInterval = 0.1) { RunLoop.main.run(until: Date().addingTimeInterval(s)) }

var failures: [String] = []
func check(_ label: String, _ condition: Bool, _ detail: String = "") {
    print(condition ? "  ok   \(label)" : "  FAIL \(label) \(detail)")
    if !condition { failures.append(label) }
}

let container = try! ModelContainer(for: Note.self, Tag.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
let howMany = Int(CommandLine.arguments.dropFirst().first ?? "0") ?? 0
MainActor.assumeIsolated {
    for i in 0..<max(howMany, 0) {
        let n = Note(title: "Trang thử số \(i + 1)")
        n.content = "Nội dung thử nghiệm cho trang số \(i + 1)."
        container.mainContext.insert(n)
    }
}
let notes: [Note] = MainActor.assumeIsolated { (try? container.mainContext.fetch(FetchDescriptor<Note>())) ?? [] }
let actions = PageActions(add: { _ in }, delete: { _ in }, duplicate: { _ in }, move: { _, _ in }, rename: { _ in })
let root = DashboardView(notes: notes, tags: [], actions: actions, onOpen: { _ in }, onManageTags: {})
    .modelContainer(container)
let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
                      styleMask: [.titled, .resizable], backing: .buffered, defer: false)
let hosting = NSHostingView(rootView: root)
window.contentView = hosting
window.makeKeyAndOrderFront(nil)
pump(0.8)
window.contentView?.layoutSubtreeIfNeeded()
pump(0.4)

// The screen must fill the window. When it does not, SwiftUI shrinks the
// hosting view and the split view centres the result: a blank band above the
// title, which is the bug this harness guards.
let height = window.contentView?.bounds.height ?? 0
let fitting = hosting.fittingSize
print(String(format: "  cao nội dung: %.0f pt (cửa sổ 800), fittingSize %.0f×%.0f", height, fitting.width, fitting.height))
check("\(howMany) trang: màn hình lấp đầy cửa sổ", height > 799, String(format: "cao=%.0f", height))

if let cv = window.contentView, let rep = cv.bitmapImageRepForCachingDisplay(in: cv.bounds) {
    cv.cacheDisplay(in: cv.bounds, to: rep)
    let name = "bnote-dash-\(howMany).png"
    if let png = rep.representation(using: .png, properties: [:]) {
        try? png.write(to: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(name))
        print("  ảnh: \(NSTemporaryDirectory())\(name)")
    }
}
print(failures.isEmpty ? "TẤT CẢ ĐỀU ĐẠT" : "THẤT BẠI (\(failures.count)): \(failures.joined(separator: " | "))")
exit(failures.isEmpty ? 0 : 1)
