import AppKit
import SwiftUI

struct FormatToolbar: View {
    @ObservedObject var controller: DocumentController
    @State private var sizeText = "13"
    @State private var textColor = Color.primary
    @State private var highlightColor = Color.yellow

    private static let commonFonts = [
        "Helvetica Neue", "Arial", "Times New Roman", "Georgia", "Verdana",
        "Courier New", "Menlo", "SF Pro", "Avenir Next", "Palatino",
    ]
    private static let allFamilies = NSFontManager.shared.availableFontFamilies
    private static let sizes: [CGFloat] = [8, 9, 10, 11, 12, 13, 14, 16, 18, 20, 24, 28, 32, 36, 48, 60, 72]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                styleMenu
                separator
                fontMenu
                sizeControls
                separator
                traitButtons
                separator
                colorControls
                separator
                alignmentMenu
                listButtons
                indentButtons
                separator
                lineSpacingMenu
                insertMenu
                pageMenu
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(.bar)
        .onChange(of: controller.format.fontSize) { _, size in
            sizeText = size == size.rounded() ? "\(Int(size))" : String(format: "%.1f", size)
        }
        .onAppear {
            sizeText = "\(Int(controller.format.fontSize))"
        }
    }

    private var separator: some View {
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
                .frame(width: 88, alignment: .leading)
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
                .frame(width: 118, alignment: .leading)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Phông chữ")
    }

    private var sizeControls: some View {
        HStack(spacing: 2) {
            Button {
                controller.nudgeFontSize(by: -1)
            } label: {
                Image(systemName: "minus")
            }
            .buttonStyle(.borderless)

            TextField("", text: $sizeText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 42)
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

            Button {
                controller.nudgeFontSize(by: 1)
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)
        }
        .help("Cỡ chữ")
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
            ToolButton(icon: "eraser", isOn: false, help: "Xóa định dạng") {
                controller.clearFormatting()
            }
        }
    }

    private var colorControls: some View {
        HStack(spacing: 6) {
            ColorPicker(selection: $textColor, supportsOpacity: false) {
                Image(systemName: "character")
            }
            .labelsHidden()
            .frame(width: 34)
            .onChange(of: textColor) { _, color in
                controller.setTextColor(NSColor(color))
            }
            .help("Màu chữ")

            ColorPicker(selection: $highlightColor, supportsOpacity: false) {
                Image(systemName: "highlighter")
            }
            .labelsHidden()
            .frame(width: 34)
            .onChange(of: highlightColor) { _, color in
                controller.setHighlight(NSColor(color))
            }
            .help("Màu nền chữ")

            Button {
                controller.setHighlight(nil)
            } label: {
                Image(systemName: "highlighter")
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "xmark")
                            .font(.system(size: 7, weight: .bold))
                    }
            }
            .buttonStyle(.borderless)
            .help("Bỏ màu nền")
        }
    }

    private var alignmentMenu: some View {
        HStack(spacing: 2) {
            ToolButton(icon: "text.alignleft", isOn: controller.format.alignment == .left, help: "Canh trái (⌘⇧L)") {
                controller.setAlignment(.left)
            }
            ToolButton(icon: "text.aligncenter", isOn: controller.format.alignment == .center, help: "Canh giữa (⌘⇧E)") {
                controller.setAlignment(.center)
            }
            ToolButton(icon: "text.alignright", isOn: controller.format.alignment == .right, help: "Canh phải (⌘⇧R)") {
                controller.setAlignment(.right)
            }
            ToolButton(icon: "text.justify", isOn: controller.format.alignment == .justified, help: "Canh đều (⌘⇧J)") {
                controller.setAlignment(.justified)
            }
        }
    }

    private var listButtons: some View {
        HStack(spacing: 2) {
            ToolButton(icon: "list.bullet", isOn: controller.format.list == .bullet, help: "Danh sách chấm") {
                controller.toggleList(.bullet)
            }
            ToolButton(icon: "list.number", isOn: controller.format.list == .numbered, help: "Danh sách số") {
                controller.toggleList(.numbered)
            }
        }
    }

    private var indentButtons: some View {
        HStack(spacing: 2) {
            ToolButton(icon: "decrease.indent", isOn: false, help: "Giảm thụt lề") {
                controller.changeIndent(by: -EditorDefaults.tabIndent)
            }
            ToolButton(icon: "increase.indent", isOn: false, help: "Tăng thụt lề") {
                controller.changeIndent(by: EditorDefaults.tabIndent)
            }
        }
    }

    private var lineSpacingMenu: some View {
        Menu {
            ForEach([1.0, 1.15, 1.5, 2.0], id: \.self) { value in
                Button(String(format: "%.2g", value)) {
                    controller.setLineHeight(CGFloat(value))
                }
            }
        } label: {
            Image(systemName: "arrow.up.and.down.text.horizontal")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Giãn dòng")
    }

    private var insertMenu: some View {
        Menu {
            Button("Chèn ảnh…") { insertImage() }
            Button("Chèn liên kết…") { insertLink() }
            Button("Ngắt trang") { controller.insertPageBreak() }
        } label: {
            Image(systemName: "plus.square.on.square")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Chèn")
    }

    private var pageMenu: some View {
        Menu {
            Section("Khổ giấy") {
                ForEach(Paper.allCases) { paper in
                    Button(paper.label) { controller.config.paper = paper }
                }
            }
            Section("Lề") {
                ForEach(MarginPreset.all) { preset in
                    Button(preset.label) { controller.config.margin = preset.value }
                }
            }
        } label: {
            Label(controller.config.paper.label, systemImage: "doc.plaintext")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Thiết lập trang")
    }

    // MARK: - Actions

    private func insertImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.prompt = "Chèn"
        guard panel.runModal() == .OK, let url = panel.url, let image = NSImage(contentsOf: url) else { return }
        controller.insertImage(image)
    }

    private func insertLink() {
        let alert = NSAlert()
        alert.messageText = "Chèn liên kết"
        alert.informativeText = "Nhập địa chỉ cho phần văn bản đang chọn."
        alert.addButton(withTitle: "Chèn")
        alert.addButton(withTitle: "Hủy")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        field.placeholderString = "https://"
        alert.accessoryView = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        controller.setLink(field.stringValue)
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
