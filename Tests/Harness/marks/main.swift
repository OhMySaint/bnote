import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
func pump(_ s: TimeInterval = 0.1) { RunLoop.main.run(until: Date().addingTimeInterval(s)) }

let controller = DocumentController.shared
var options = CanvasOptions()
controller.canvasOptions = options
let host = EditorCanvasView(controller: controller)
let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 560), styleMask: [.titled], backing: .buffered, defer: false)
window.contentView = host
host.frame = window.contentView!.bounds
host.layoutSubtreeIfNeeded()
window.orderFront(nil)
pump(0.3)

controller.load(data: nil, plainText: "", config: PageConfig())
let tv = controller.activeTextView!
window.makeFirstResponder(tv)

func type(_ text: String) { controller.insertPlainText(text) }
func newline() {
    let range = NSRange(location: controller.textStorage.length, length: 0)
    tv.setSelectedRange(range)
    if controller.textView(tv, shouldChangeTextIn: range, replacementString: "\n") {
        controller.insertPlainText("\n")
    }
}

type("Shopping")
controller.apply(style: .heading2)
newline()
type("milk and eggs")
controller.toggleList(.todo)
newline()
type("bread")
newline()
type("coffee beans")
// tick the middle one
let text = controller.textStorage.string as NSString
let breadLine = text.range(of: "bread")
if breadLine.location != NSNotFound {
    let paragraph = controller.paragraphRange(at: breadLine.location)
    _ = controller.handleCheckboxClick(
        at: controller.layoutManager.boundingRect(
            forGlyphRange: NSRange(location: controller.layoutManager.glyphIndexForCharacter(at: paragraph.location), length: 1),
            in: controller.layoutManager.textContainers[0]
        ).offsetBy(dx: tv.textContainerOrigin.x, dy: tv.textContainerOrigin.y).insetBy(dx: 1, dy: 1).origin.applying(.init(translationX: 4, y: 6)),
        in: tv
    )
}
tv.setSelectedRange(NSRange(location: controller.textStorage.length, length: 0))
newline()
controller.toggleList(.todo)   // leave the to-do list
type("Notes")
controller.toggleList(.toggle)
newline()
type("hidden line one")
newline()
type("hidden line two")

pump(0.3)
host.layoutSubtreeIfNeeded()
func shoot(_ name: String) {
    pump(0.35)
    host.layoutSubtreeIfNeeded()
    guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
    host.cacheDisplay(in: host.bounds, to: rep)
    if let png = rep.representation(using: .png, properties: [:]) {
        try? png.write(to: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(name))
        print("  ảnh: \(NSTemporaryDirectory())\(name)")
    }
}
shoot("bnote-marks-open.png")
controller.toggleSection(at: controller.paragraphRange(at: (controller.textStorage.string as NSString).range(of: "Notes").location))
shoot("bnote-marks-closed.png")
exit(0)
