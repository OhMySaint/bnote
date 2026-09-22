import AppKit
import SwiftUI

/// Word-processor style swatch grid: a grey ramp on top, then ten hues in
/// five shades from light to dark.
enum ColorPalette {
    static let greys: [NSColor] = [
        "000000", "434343", "666666", "999999", "B7B7B7", "CCCCCC", "D9D9D9", "EFEFEF", "F3F3F3", "FFFFFF",
    ].map(color)

    static let rows: [[NSColor]] = [
        ["980000", "FF0000", "FF9900", "FFFF00", "00FF00", "00FFFF", "4A86E8", "0000FF", "9900FF", "FF00FF"],
        ["E6B8AF", "F4CCCC", "FCE5CD", "FFF2CC", "D9EAD3", "D0E0E3", "C9DAF8", "CFE2F3", "D9D2E9", "EAD1DC"],
        ["DD7E6B", "EA9999", "F9CB9C", "FFE599", "B6D7A8", "A2C4C9", "A4C2F4", "9FC5E8", "B4A7D6", "D5A6BD"],
        ["CC4125", "E06666", "F6B26B", "FFD966", "93C47D", "76A5AF", "6D9EEB", "6FA8DC", "8E7CC3", "C27BA0"],
        ["A61C00", "CC0000", "E69138", "F1C232", "6AA84F", "45818E", "3C78D8", "3D85C6", "674EA7", "A64D79"],
        ["5B0F00", "660000", "783F04", "7F6000", "274E13", "0C343D", "1C4587", "073763", "20124D", "4C1130"],
    ].map { $0.map(color) }

    /// Highlighters read better with the light rows first.
    static let highlightRows: [[NSColor]] = [rows[1], rows[2], rows[3], rows[0]]

    private static func color(_ hex: String) -> NSColor {
        let value = UInt32(hex, radix: 16) ?? 0
        return NSColor(
            srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}

/// Popover body for picking a text or highlight colour.
struct ColorSwatchPicker: View {
    enum Kind { case text, highlight }

    let kind: Kind
    let current: NSColor?
    let onPick: (NSColor?) -> Void

    @State private var customPanelShown = false

    private var rows: [[NSColor]] {
        kind == .text ? [ColorPalette.greys] + ColorPalette.rows : ColorPalette.highlightRows
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(kind == .text ? "Text color" : "Highlight")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Button {
                onPick(nil)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: kind == .text ? "textformat" : "slash.circle")
                        .frame(width: 16)
                    Text(kind == .text ? "Automatic" : "No highlight")
                    Spacer()
                    if current == nil { Image(systemName: "checkmark").font(.caption) }
                }
                .font(.callout)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.05), in: .rect(cornerRadius: 5))
            }
            .buttonStyle(.plain)

            VStack(spacing: 3) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 3) {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, color in
                            swatch(color)
                        }
                    }
                }
            }

            Button("Customize…") {
                openSystemPanel()
            }
            .buttonStyle(.link)
            .font(.caption)
        }
        .padding(10)
        .frame(width: 10 * 21 + 20)
    }

    private func swatch(_ color: NSColor) -> some View {
        let selected = current.map { same($0, color) } ?? false
        return Button {
            onPick(color)
        } label: {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(nsColor: color))
                .frame(width: 18, height: 18)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(selected ? Color.accentColor : Color.primary.opacity(0.15), lineWidth: selected ? 2 : 0.5)
                )
                .overlay {
                    if selected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(color.isLight ? Color.black : .white)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private func same(_ a: NSColor, _ b: NSColor) -> Bool {
        guard let x = a.usingColorSpace(.sRGB), let y = b.usingColorSpace(.sRGB) else { return false }
        return abs(x.redComponent - y.redComponent) < 0.01
            && abs(x.greenComponent - y.greenComponent) < 0.01
            && abs(x.blueComponent - y.blueComponent) < 0.01
    }

    /// Advanced picking still goes through the system panel.
    private func openSystemPanel() {
        let panel = NSColorPanel.shared
        panel.showsAlpha = false
        if let current { panel.color = current }
        ColorPanelBridge.shared.onChange = onPick
        panel.setTarget(ColorPanelBridge.shared)
        panel.setAction(#selector(ColorPanelBridge.colorChanged(_:)))
        panel.makeKeyAndOrderFront(nil)
    }
}

/// Target for `NSColorPanel`, which needs an Objective-C selector.
private final class ColorPanelBridge: NSObject {
    static let shared = ColorPanelBridge()
    var onChange: ((NSColor?) -> Void)?

    @objc func colorChanged(_ sender: NSColorPanel) {
        onChange?(sender.color)
    }
}

extension NSColor {
    var isLight: Bool {
        guard let rgb = usingColorSpace(.sRGB) else { return true }
        let luminance = 0.299 * rgb.redComponent + 0.587 * rgb.greenComponent + 0.114 * rgb.blueComponent
        return luminance > 0.6
    }
}
