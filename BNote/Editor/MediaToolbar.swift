import AppKit
import SwiftUI

/// State for the floating bar that appears over a selected picture or video card.
final class MediaToolbarModel: ObservableObject {
    @Published var widthFraction: CGFloat = 1
    @Published var alignment: NSTextAlignment = .left
    @Published var hasLink = false
    @Published var isVideo = false
    var onResize: ((CGFloat) -> Void)?
    var onAlign: ((NSTextAlignment) -> Void)?
    var onCopy: (() -> Void)?
    var onSave: (() -> Void)?
    var onOpen: (() -> Void)?
    var onDelete: (() -> Void)?
}

private final class NonKeyPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class MediaToolbarPanel {
    private var panel: NSPanel?
    private let model: MediaToolbarModel

    init(model: MediaToolbarModel) {
        self.model = model
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    func show(above screenRect: NSRect, parent: NSWindow?) {
        let panel = existingPanel()
        let size = NSSize(width: model.isVideo ? 372 : 340, height: 34)
        panel.setContentSize(size)
        var origin = NSPoint(x: screenRect.midX - size.width / 2, y: screenRect.maxY + 6)
        if let screen = parent?.screen ?? NSScreen.main {
            let frame = screen.visibleFrame
            origin.x = min(max(frame.minX + 8, origin.x), frame.maxX - size.width - 8)
            if origin.y + size.height > frame.maxY - 8 {
                origin.y = screenRect.minY - size.height - 6
            }
        }
        panel.setFrameOrigin(origin)
        if panel.parent == nil, let parent { parent.addChildWindow(panel, ordered: .above) }
        panel.orderFront(nil)
    }

    func hide() {
        guard let panel else { return }
        panel.parent?.removeChildWindow(panel)
        panel.orderOut(nil)
    }

    private func existingPanel() -> NSPanel {
        if let panel { return panel }
        let panel = NonKeyPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 34),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = true
        panel.contentView = NSHostingView(rootView: MediaToolbarView(model: model))
        self.panel = panel
        return panel
    }
}

struct MediaToolbarView: View {
    @ObservedObject var model: MediaToolbarModel

    var body: some View {
        HStack(spacing: 2) {
            sizeButton("S", 0.33, help: "Small — 1/3 width")
            sizeButton("M", 0.5, help: "Medium — 1/2 width")
            sizeButton("L", 0.75, help: "Large — 3/4 width")
            sizeButton("↔", 1.0, help: "Full column width")
            divider
            alignButton("text.alignleft", .left)
            alignButton("text.aligncenter", .center)
            alignButton("text.alignright", .right)
            divider
            iconButton("doc.on.doc", help: "Copy picture") { model.onCopy?() }
            iconButton("square.and.arrow.down", help: "Save picture…") { model.onSave?() }
            if model.hasLink {
                iconButton(model.isVideo ? "play.rectangle" : "arrow.up.right.square", help: model.isVideo ? "Play video" : "Open link") { model.onOpen?() }
            }
            divider
            iconButton("trash", help: "Delete") { model.onDelete?() }
        }
        .padding(.horizontal, 6)
        .frame(height: 34)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: .rect(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator, lineWidth: 0.5))
    }

    private var divider: some View {
        Divider().frame(height: 16).padding(.horizontal, 2)
    }

    private func sizeButton(_ label: String, _ fraction: CGFloat, help: String) -> some View {
        let selected = abs(model.widthFraction - fraction) < 0.04
        return Button {
            model.onResize?(fraction)
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 24, height: 22)
                .background(selected ? Color.accentColor.opacity(0.2) : .clear, in: .rect(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func alignButton(_ symbol: String, _ alignment: NSTextAlignment) -> some View {
        Button {
            model.onAlign?(alignment)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .medium))
                .frame(width: 24, height: 22)
                .background(model.alignment == alignment ? Color.accentColor.opacity(0.2) : .clear, in: .rect(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }

    private func iconButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .medium))
                .frame(width: 24, height: 22)
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
