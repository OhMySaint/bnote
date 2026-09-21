import AppKit
import SwiftUI

struct FormatToolbar: View {
    @ObservedObject var controller: DocumentController
    @State private var sizeText = "13"
    @State private var textColor = Color.primary
    @State private var highlightColor = Color.yellow

    private static let commonFonts = [
        "Helvetica Neue", "Arial", "Times New Roman", "Georgia", "Verdana",
        "Courier New", "Menlo", "Avenir Next", "Palatino",
    ]
    private static let allFamilies = NSFontManager.shared.availableFontFamilies
    private static let sizes: [CGFloat] = [8, 9, 10, 11, 12, 13, 14, 16, 18, 20, 24, 28, 32, 36, 48, 60, 72]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                group { styleMenu }
                group {
                    fontMenu
                    sizeControls
                }
                group { traitButtons }
                group { colorControls }
                group { alignmentButtons }
                group {
                    listButtons
                    indentButtons
                    lineSpacingMenu
                }
                group { insertMenu }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(.bar)
        .onChange(of: controller.format.fontSize) { _, size in
            sizeText = size == size.rounded() ? "\(Int(size))" : String(format: "%.1f", size)
        }
        .onAppear { sizeText = "\(Int(controller.format.fontSize))" }
    }

    /// One cluster of related controls, separated by a hairline.
    @ViewBuilder
    private func group(@ViewBuilder content: () -> some View) -> some View {
        HStack(spacing: 4) { content() }
        Divider().frame(height: 18)
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
                .frame(width: 86, alignment: .leading)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Kiểu đoạn văn")
    }

    private var fontMenu: some View {
        Menu {
            Section("Thường dùng") {
                ForEach(Self.commonFonts, id: \.self) { family in
                    Button(family) { controller.setFontFamily(family) }
                }
            }
            Section("Tất cả phông") {
                ForEach(Self.allFamilies, id: \.self) { family in
                    Button(family) { controller.setFontFamily(family) }
                }
            }
        } label: {
            Text(controller.format.fontFamily)
                .lineLimit(1)
                .frame(width: 112, alignment: .leading)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Phông chữ")
    }

    private var sizeControls: some View {
        HStack(spacing: 1) {
            Button { controller.nudgeFontSize(by: -1) } label: { Image(systemName: "minus") }
                .buttonStyle(.borderless)
                .help("Giảm cỡ chữ (⌘−)")

            TextField("", text: $sizeText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 40)
                .multilineTextAlignment(.center)
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
                Image(systemName: "chevron.down").font(.system(size: 8))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()

            Button { controller.nudgeFontSize(by: 1) } label: { Image(systemName: "plus") }
                .buttonStyle(.borderless)
                .help("Tăng cỡ chữ (⌘+)")
        }
    }

    private var traitButtons: some View {
        HStack(spacing: 2) {
            ToolButton(icon: "bold", isOn: controller.format.bold, help: "Đậm (⌘B)") {
                controller.toggleTrait(.boldFontMask)
            }
            ToolButton(icon: "italic", isOn: controller.format.italic, help: "Nghiêng (⌘I)") {
                controller.toggleTrait(.italicFontMask)
            }
            ToolButton(icon: "underline", isOn: controller.format.underline, help: "Gạch chân (⌘U)") {
                controller.toggleUnderline()
            }
            ToolButton(icon: "strikethrough", isOn: controller.format.strikethrough, help: "Gạch ngang") {
                controller.toggleStrikethrough()
            }
            ToolButton(icon: "eraser", isOn: false, help: "Xóa định dạng (⌘\\)") {
                controller.clearFormatting()
            }
        }
    }

    private var colorControls: some View {
        HStack(spacing: 4) {
            ColorPicker(selection: $textColor, supportsOpacity: false) { EmptyView() }
                .labelsHidden()
                .onChange(of: textColor) { _, color in controller.setTextColor(NSColor(color)) }
                .help("Màu chữ")

            ColorPicker(selection: $highlightColor, supportsOpacity: false) { EmptyView() }
                .labelsHidden()
                .onChange(of: highlightColor) { _, color in controller.setHighlight(NSColor(color)) }
                .help("Màu nền chữ")

            ToolButton(icon: "paintbrush", isOn: false, help: "Bỏ màu nền") {
                controller.setHighlight(nil)
            }
        }
    }

    private var alignmentButtons: some View {
        HStack(spacing: 2) {
            ToolButton(icon: "text.alignleft", isOn: controller.format.alignment == .left, help: "Canh trái (⇧⌘L)") {
                controller.setAlignment(.left)
            }
            ToolButton(icon: "text.aligncenter", isOn: controller.format.alignment == .center, help: "Canh giữa (⇧⌘E)") {
                controller.setAlignment(.center)
            }
            ToolButton(icon: "text.alignright", isOn: controller.format.alignment == .right, help: "Canh phải (⇧⌘R)") {
                controller.setAlignment(.right)
            }
            ToolButton(icon: "text.justify", isOn: controller.format.alignment == .justified, help: "Canh đều (⇧⌘J)") {
                controller.setAlignment(.justified)
            }
        }
    }

    private var listButtons: some View {
        HStack(spacing: 2) {
            ToolButton(icon: "list.bullet", isOn: controller.format.list == .bullet, help: "Danh sách chấm (⇧⌘8)") {
                controller.toggleList(.bullet)
            }
            ToolButton(icon: "list.number", isOn: controller.format.list == .numbered, help: "Danh sách số (⇧⌘7)") {
                controller.toggleList(.numbered)
            }
            ToolButton(icon: "checklist", isOn: controller.format.list == .todo, help: "Việc cần làm (⇧⌘9)") {
                controller.toggleList(.todo)
            }
        }
    }

    private var indentButtons: some View {
        HStack(spacing: 2) {
            ToolButton(icon: "decrease.indent", isOn: false, help: "Giảm thụt lề (⌘[)") {
                controller.changeIndent(by: -EditorDefaults.tabIndent)
            }
            ToolButton(icon: "increase.indent", isOn: false, help: "Tăng thụt lề (⌘])") {
                controller.changeIndent(by: EditorDefaults.tabIndent)
            }
        }
    }

    private var lineSpacingMenu: some View {
        Menu {
            ForEach([1.0, 1.15, 1.5, 2.0], id: \.self) { value in
                Button(String(format: "%.2g", value)) { controller.setLineHeight(CGFloat(value)) }
            }
        } label: {
            Image(systemName: "arrow.up.and.down.text.horizontal")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Giãn dòng")
    }

    private var insertMenu: some View {
        Menu {
            ForEach(SlashCatalog.all) { command in
                Button(command.title) { command.perform(controller) }
            }
        } label: {
            Label("Chèn", systemImage: "plus.square.on.square")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Chèn khối — hoặc gõ / trong tài liệu")
    }
}

private struct ToolButton: View {
    let icon: String
    let isOn: Bool
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .frame(width: 22, height: 20)
                .background(isOn ? Color.accentColor.opacity(0.22) : .clear, in: .rect(cornerRadius: 4))
        }
        .buttonStyle(.borderless)
        .help(help)
    }
}
