import AppKit
import SwiftUI

struct FormatToolbar: View {
    @ObservedObject var controller: DocumentController
    @State private var sizeText = "13"
    @State private var showTextPalette = false
    @State private var showHighlightPalette = false

    private static let commonFonts = [
        "Helvetica Neue", "Arial", "Times New Roman", "Georgia", "Verdana",
        "Courier New", "Menlo", "Avenir Next", "Palatino",
    ]
    private static let allFamilies = NSFontManager.shared.availableFontFamilies
    private static let sizes: [CGFloat] = [8, 9, 10, 11, 12, 13, 14, 16, 18, 20, 24, 28, 32, 36, 48, 60, 72]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ToolGroup { styleMenu }
                ToolGroup {
                    fontMenu
                    faceMenu
                    sizeControls
                }
                ToolGroup { traitButtons }
                ToolGroup { colorControls }
                ToolGroup { alignmentButtons }
                ToolGroup {
                    listButtons
                    Divider().frame(height: 14)
                    indentButtons
                    lineSpacingMenu
                }
                ToolGroup { insertMenu }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .frame(height: 42)
        .background(.bar)
        .onChange(of: controller.format.fontSize) { _, size in
            sizeText = size == size.rounded() ? "\(Int(size))" : String(format: "%.1f", size)
        }
        .onAppear { sizeText = "\(Int(controller.format.fontSize))" }
    }

    // MARK: - Controls

    private var styleMenu: some View {
        Menu {
            ForEach(TextStyle.allCases) { style in
                Button {
                    controller.apply(style: style)
                } label: {
                    Text(style.label)
                    if controller.format.style == style { Image(systemName: "checkmark") }
                }
            }
        } label: {
            Text(controller.format.style.label)
                .frame(width: 84, alignment: .leading)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Paragraph style")
    }

    private var fontMenu: some View {
        Menu {
            Section("Recent") {
                ForEach(Self.commonFonts, id: \.self) { family in
                    Button(family) { controller.setFontFamily(family) }
                }
            }
            Section("All fonts") {
                ForEach(Self.allFamilies, id: \.self) { family in
                    Button(family) { controller.setFontFamily(family) }
                }
            }
        } label: {
            Text(controller.format.fontFamily)
                .lineLimit(1)
                .frame(width: 108, alignment: .leading)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Font")
    }

    /// Every face the current family offers, so "heavy", "light" or "condensed"
    /// cuts are one click away instead of hiding behind the font panel.
    private var faceMenu: some View {
        let faces = DocumentController.faces(of: controller.format.fontFamily)
        let currentStyle = faces.first { $0.name == controller.format.fontName }?.style ?? "Regular"
        return Menu {
            ForEach(faces, id: \.name) { face in
                Button {
                    controller.setFontFace(face.name)
                } label: {
                    Text(face.style)
                    if face.name == controller.format.fontName { Image(systemName: "checkmark") }
                }
            }
        } label: {
            Text(currentStyle)
                .lineLimit(1)
                .frame(width: 74, alignment: .leading)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .disabled(faces.count <= 1)
        .help("Typeface and weight of the current font")
    }

    private var sizeControls: some View {
        HStack(spacing: 0) {
            ToolButton(icon: "minus", isOn: false, help: "Smaller (⇧⌘,)") {
                controller.nudgeFontSize(by: -1)
            }
            TextField("", text: $sizeText)
                .textFieldStyle(.plain)
                .font(.system(size: 12).monospacedDigit())
                .multilineTextAlignment(.center)
                .frame(width: 30)
                .onSubmit {
                    if let value = Double(sizeText.replacingOccurrences(of: ",", with: ".")) {
                        controller.setFontSize(CGFloat(value))
                    }
                }
            Menu {
                ForEach(Self.sizes, id: \.self) { size in
                    Button("\(Int(size))") { controller.setFontSize(size) }
                }
            } label: {
                Image(systemName: "chevron.down").font(.system(size: 8, weight: .semibold))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            ToolButton(icon: "plus", isOn: false, help: "Bigger (⇧⌘.)") {
                controller.nudgeFontSize(by: 1)
            }
        }
    }

    private var traitButtons: some View {
        HStack(spacing: 1) {
            ToolButton(icon: "bold", isOn: controller.format.bold, help: "Bold (⌘B)") {
                controller.toggleTrait(.boldFontMask)
            }
            ToolButton(icon: "italic", isOn: controller.format.italic, help: "Italic (⌘I)") {
                controller.toggleTrait(.italicFontMask)
            }
            ToolButton(icon: "underline", isOn: controller.format.underline, help: "Underline (⌘U)") {
                controller.toggleUnderline()
            }
            ToolButton(icon: "strikethrough", isOn: controller.format.strikethrough, help: "Strikethrough") {
                controller.toggleStrikethrough()
            }
            ToolButton(icon: "eraser", isOn: false, help: "Clear formatting (⌘\\)") {
                controller.clearFormatting()
            }
        }
    }

    private var colorControls: some View {
        HStack(spacing: 2) {
            ColorWell(icon: "character", color: controller.format.textColor, help: "Text color") {
                showTextPalette.toggle()
            }
            .popover(isPresented: $showTextPalette, arrowEdge: .bottom) {
                ColorSwatchPicker(kind: .text, current: controller.format.textColor) { color in
                    controller.setTextColor(color ?? .textColor)
                    showTextPalette = false
                }
            }

            ColorWell(icon: "highlighter", color: controller.format.highlight, help: "Highlight") {
                showHighlightPalette.toggle()
            }
            .popover(isPresented: $showHighlightPalette, arrowEdge: .bottom) {
                ColorSwatchPicker(kind: .highlight, current: controller.format.highlight) { color in
                    controller.setHighlight(color)
                    showHighlightPalette = false
                }
            }
        }
    }

    private var alignmentButtons: some View {
        HStack(spacing: 1) {
            ToolButton(icon: "text.alignleft", isOn: controller.format.alignment == .left, help: "Left (⇧⌘L)") {
                controller.setAlignment(.left)
            }
            ToolButton(icon: "text.aligncenter", isOn: controller.format.alignment == .center, help: "Center (⇧⌘E)") {
                controller.setAlignment(.center)
            }
            ToolButton(icon: "text.alignright", isOn: controller.format.alignment == .right, help: "Right (⇧⌘R)") {
                controller.setAlignment(.right)
            }
            ToolButton(icon: "text.justify", isOn: controller.format.alignment == .justified, help: "Justify (⇧⌘J)") {
                controller.setAlignment(.justified)
            }
        }
    }

    private var listButtons: some View {
        HStack(spacing: 1) {
            ToolButton(icon: "list.bullet", isOn: controller.format.list == .bullet, help: "Bulleted list (⇧⌘8)") {
                controller.toggleList(.bullet)
            }
            ToolButton(icon: "list.number", isOn: controller.format.list == .numbered, help: "Numbered list (⇧⌘7)") {
                controller.toggleList(.numbered)
            }
            ToolButton(icon: "checklist", isOn: controller.format.list == .todo, help: "To-do list (⇧⌘9)") {
                controller.toggleList(.todo)
            }
        }
    }

    private var indentButtons: some View {
        HStack(spacing: 1) {
            ToolButton(icon: "decrease.indent", isOn: false, help: "Decrease indent (⌘[)") {
                controller.changeIndent(by: -EditorDefaults.tabIndent)
            }
            ToolButton(icon: "increase.indent", isOn: false, help: "Increase indent (⌘])") {
                controller.changeIndent(by: EditorDefaults.tabIndent)
            }
        }
    }

    private var lineSpacingMenu: some View {
        Menu {
            ForEach([1.0, 1.15, 1.5, 2.0], id: \.self) { value in
                Button {
                    controller.setLineHeight(CGFloat(value))
                } label: {
                    Text(String(format: "%.2g", value))
                    if abs(controller.format.lineHeight - value) < 0.01 { Image(systemName: "checkmark") }
                }
            }
        } label: {
            Image(systemName: "arrow.up.and.down.text.horizontal")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Line spacing")
    }

    private var insertMenu: some View {
        Menu {
            ForEach(SlashCatalog.all) { command in
                Button {
                    command.perform(controller)
                } label: {
                    Label(command.title, systemImage: command.symbol)
                }
            }
        } label: {
            Label("Insert", systemImage: "plus")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Insert a block — or press / in the page")
    }
}

/// A cluster of related controls on a soft rounded backdrop.
private struct ToolGroup<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 2) { content() }
            .padding(.horizontal, 5)
            .frame(height: 28)
            .background(Color.primary.opacity(0.045), in: .rect(cornerRadius: 7))
    }
}

/// Icon with a colour bar underneath, like the A / highlighter buttons in Docs.
private struct ColorWell: View {
    let icon: String
    let color: NSColor?
    let help: String
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                RoundedRectangle(cornerRadius: 1)
                    .fill(color.map { Color(nsColor: $0) } ?? Color.primary.opacity(0.35))
                    .frame(width: 14, height: 3)
            }
            .frame(width: 24, height: 22)
            .background(hovering ? Color.primary.opacity(0.08) : .clear, in: .rect(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
    }
}

private struct ToolButton: View {
    let icon: String
    let isOn: Bool
    let help: String
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 24, height: 22)
                .foregroundStyle(isOn ? Color.accentColor : .primary)
                .background(background, in: .rect(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
    }

    private var background: Color {
        if isOn { return Color.accentColor.opacity(0.18) }
        if hovering { return Color.primary.opacity(0.08) }
        return .clear
    }
}
