import AppKit
import SwiftUI

/// The popup must never become key, or the text view stops receiving keys.
/// SwiftUI hosting inside a panel can otherwise request it.
private final class NonKeyPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Floating list shown next to the caret while the "/" menu is active. It never
/// takes key focus, so typing keeps filtering the list in the text view.
final class SlashMenuPanel {
    private enum Metrics {
        static let width: CGFloat = 300
        static let row: CGFloat = 40
        static let header: CGFloat = 22
        static let padding: CGFloat = 12
        static let maxHeight: CGFloat = 340
    }

    private var panel: NSPanel?
    private let model: SlashMenuModel

    init(model: SlashMenuModel) {
        self.model = model
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    func show(near caretScreenRect: NSRect, parent: NSWindow?) {
        let panel = existingPanel()
        let size = preferredSize()
        panel.setContentSize(size)

        var origin = NSPoint(x: caretScreenRect.minX, y: caretScreenRect.minY - size.height - 6)
        if let screen = parent?.screen ?? NSScreen.main {
            let frame = screen.visibleFrame
            origin.x = min(max(frame.minX + 8, origin.x), frame.maxX - size.width - 8)
            if origin.y < frame.minY + 8 {
                origin.y = caretScreenRect.maxY + 6
            }
        }
        panel.setFrameOrigin(origin)

        if panel.parent == nil, let parent {
            parent.addChildWindow(panel, ordered: .above)
        }
        panel.orderFront(nil)
    }

    func resize() {
        guard let panel, panel.isVisible else { return }
        let origin = panel.frame.origin
        let previousHeight = panel.frame.height
        let size = preferredSize()
        panel.setContentSize(size)
        panel.setFrameOrigin(NSPoint(x: origin.x, y: origin.y + (previousHeight - size.height)))
    }

    func hide() {
        guard let panel else { return }
        panel.parent?.removeChildWindow(panel)
        panel.orderOut(nil)
    }

    private func preferredSize() -> NSSize {
        let rows = max(model.commands.count, 1)
        let headers = Set(model.commands.map(\.section)).count
        let height = CGFloat(rows) * Metrics.row + CGFloat(headers) * Metrics.header + Metrics.padding
        return NSSize(width: Metrics.width, height: min(height, Metrics.maxHeight))
    }

    private func existingPanel() -> NSPanel {
        if let panel { return panel }
        let panel = NonKeyPanel(
            contentRect: NSRect(x: 0, y: 0, width: Metrics.width, height: 300),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = true
        panel.contentView = NSHostingView(rootView: SlashMenuView(model: model))
        self.panel = panel
        return panel
    }
}

struct SlashMenuView: View {
    @ObservedObject var model: SlashMenuModel

    private var grouped: [(section: String, items: [(index: Int, command: SlashCommand)])] {
        var result: [(String, [(Int, SlashCommand)])] = []
        for (index, command) in model.commands.enumerated() {
            if let last = result.indices.last, result[last].0 == command.section {
                result[last].1.append((index, command))
            } else {
                result.append((command.section, [(index, command)]))
            }
        }
        return result.map { (section: $0.0, items: $0.1.map { (index: $0.0, command: $0.1) }) }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(grouped, id: \.section) { group in
                        Text(group.section)
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 9)
                            .padding(.top, 6)
                            .padding(.bottom, 2)
                        ForEach(group.items, id: \.command.id) { item in
                            row(item.command, isSelected: item.index == model.selection)
                                .id(item.command.id)
                                .onTapGesture { model.onPick?(item.command) }
                        }
                    }
                }
                .padding(6)
            }
            .onChange(of: model.selection) { _, index in
                guard model.commands.indices.contains(index) else { return }
                withAnimation(.easeOut(duration: 0.12)) {
                    proxy.scrollTo(model.commands[index].id)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial, in: .rect(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.separator, lineWidth: 0.5))
    }

    private func row(_ command: SlashCommand, isSelected: Bool) -> some View {
        HStack(spacing: 9) {
            Image(systemName: command.symbol)
                .font(.system(size: 13))
                .frame(width: 26, height: 26)
                .background(
                    isSelected ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.06),
                    in: .rect(cornerRadius: 6)
                )
            VStack(alignment: .leading, spacing: 1) {
                Text(command.title)
                    .font(.system(size: 12.5, weight: .medium))
                Text(command.subtitle)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if isSelected {
                Text("↩")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .frame(height: 38)
        .background(isSelected ? Color.accentColor.opacity(0.16) : .clear, in: .rect(cornerRadius: 6))
        .contentShape(.rect)
    }
}
