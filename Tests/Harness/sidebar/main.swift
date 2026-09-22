import AppKit
import SwiftUI
import SwiftData

let app = NSApplication.shared
app.setActivationPolicy(.regular)
func pump(_ s: TimeInterval = 0.1) { RunLoop.main.run(until: Date().addingTimeInterval(s)) }
var failures: [String] = []
func check(_ label: String, _ ok: Bool, _ detail: String = "") {
    print(ok ? "  ok   \(label)" : "  FAIL \(label) \(detail)")
    if !ok { failures.append(label) }
}

let container = try! ModelContainer(for: Note.self, Tag.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
let (roots, all, selected): ([Note], [Note], PersistentIdentifier) = MainActor.assumeIsolated {
    let parent = Note(title: "Thesis with a fairly long name", sortIndex: 0)
    parent.icon = "📘"; parent.isExpanded = true
    let child = Note(title: "Chapter one", parent: parent, sortIndex: 1)
    child.icon = "📄"
    let other = Note(title: "Meeting notes", sortIndex: 2)
    other.icon = "🗒️"; other.tags = ["work"]
    for note in [parent, child, other] { container.mainContext.insert(note) }
    let tag = Tag(name: "work"); container.mainContext.insert(tag)
    return ([parent, other], [parent, child, other], parent.persistentModelID)
}
let tags: [Tag] = MainActor.assumeIsolated { (try? container.mainContext.fetch(FetchDescriptor<Tag>())) ?? [] }
let actions = PageActions(add: { _ in }, delete: { _ in }, duplicate: { _ in }, move: { _, _ in }, rename: { _ in })

/// Renders the sidebar with a given selection and reports where each row's
/// icon sits, so "same left edge" is measured rather than eyeballed.
func shoot(name: String, selection: PersistentIdentifier?) {
    let view = SidebarView(
        roots: roots, allNotes: all, tags: tags,
        selection: .constant(selection), search: .constant(""), activeTag: .constant(nil),
        renamingID: .constant(nil), actions: actions, onManageTags: {}, onShowDashboard: {}
    )
    .modelContainer(container)
    .frame(width: 280, height: 420)

    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 280, height: 420),
                          styleMask: [.titled, .resizable], backing: .buffered, defer: false)
    window.contentView = NSHostingView(rootView: view)
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
    pump(1.2)
    window.contentView?.layoutSubtreeIfNeeded()
    pump(0.5)

    // Every row's leading content must start at the same x.
    var lefts: [(String, CGFloat)] = []
    func walk(_ view: NSView) {
        if let field = view as? NSTextField, !field.stringValue.isEmpty {
            let frame = field.convert(field.bounds, to: window.contentView!)
            lefts.append((field.stringValue, frame.minX))
        }
        view.subviews.forEach(walk)
    }
    window.contentView.map(walk)
    for (text, x) in lefts { print(String(format: "  %-34@ x=%6.1f", String(text.prefix(32)) as NSString, x)) }

    if let cv = window.contentView, let rep = cv.bitmapImageRepForCachingDisplay(in: cv.bounds) {
        cv.cacheDisplay(in: cv.bounds, to: rep)
        if let png = rep.representation(using: .png, properties: [:]) {
            let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(name)
            try? png.write(to: url)
            print("  ảnh: \(url.path)")
        }
    }
    window.orderOut(nil)
}

print("== sidebar: chọn một trang ==")
shoot(name: "bnote-sidebar-page.png", selection: selected)
print("== sidebar: đang ở Overview ==")
shoot(name: "bnote-sidebar-overview.png", selection: nil)
exit(0)
