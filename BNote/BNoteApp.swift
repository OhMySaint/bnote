import AppKit
import SwiftData
import SwiftUI

@main
struct BNoteApp: App {
    init() {
        Defaults.register()
        DocumentController.shared.canvasOptions = Defaults.canvasOptions
    }

    var body: some Scene {
        Window("BNote", id: "main") {
            ContentView()
        }
        .modelContainer(for: [Note.self, Tag.self])
        .defaultSize(width: 1180, height: 820)
        .windowToolbarStyle(.unified)
        .commands { BNoteCommands() }

        Settings {
            SettingsView()
        }
    }
}

struct BNoteCommands: Commands {
    @ObservedObject private var controller = DocumentController.shared
    @ObservedObject private var ui = AppUIState.shared
    private var actions: AppActions { .shared }

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Trang mới") { actions.newPage?() }
                .keyboardShortcut("n", modifiers: .command)
            Button("Trang con mới") { actions.newSubpage?() }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            Divider()
            Button("Nhập tài liệu…") { actions.importDocuments?() }
                .keyboardShortcut("i", modifiers: [.command, .shift])
            Menu("Xuất") {
                ForEach(DocumentFormat.allCases) { format in
                    Button(format.label) { actions.export?(format) }
                }
            }
        }

        CommandMenu("Trang") {
            Button("Ảnh bìa: chọn ảnh…") { actions.setCoverFromFile?() }
            Button("Ảnh bìa: dán từ clipboard") { actions.setCoverFromClipboard?() }
            Button("Bỏ ảnh bìa") { actions.removeCover?() }
            Divider()
            Button("Thiết lập trang…") { actions.showPageSetup?() }
                .keyboardShortcut("p", modifiers: [.command, .shift])
        }

        CommandGroup(replacing: .printItem) {
            Button("In…") { actions.printDocument?() }
                .keyboardShortcut("p", modifiers: .command)
        }

        CommandMenu("Định dạng") {
            Button("Đậm") { controller.toggleTrait(.boldFontMask) }
                .keyboardShortcut("b", modifiers: .command)
            Button("Nghiêng") { controller.toggleTrait(.italicFontMask) }
                .keyboardShortcut("i", modifiers: .command)
            Button("Gạch chân") { controller.toggleUnderline() }
                .keyboardShortcut("u", modifiers: .command)
            Button("Gạch ngang") { controller.toggleStrikethrough() }
            Divider()

            Menu("Kiểu") {
                ForEach(TextStyle.allCases) { style in
                    styleButton(style)
                }
            }

            Menu("Canh lề") {
                Button("Trái") { controller.setAlignment(.left) }
                    .keyboardShortcut("l", modifiers: [.command, .shift])
                Button("Giữa") { controller.setAlignment(.center) }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                Button("Phải") { controller.setAlignment(.right) }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                Button("Đều hai bên") { controller.setAlignment(.justified) }
                    .keyboardShortcut("j", modifiers: [.command, .shift])
            }

            Menu("Danh sách") {
                Button("Danh sách chấm") { controller.toggleList(.bullet) }
                    .keyboardShortcut("8", modifiers: [.command, .shift])
                Button("Danh sách số") { controller.toggleList(.numbered) }
                    .keyboardShortcut("7", modifiers: [.command, .shift])
                Button("Việc cần làm") { controller.toggleList(.todo) }
                    .keyboardShortcut("9", modifiers: [.command, .shift])
            }

            Menu("Chèn khối") {
                ForEach(SlashCatalog.all) { command in
                    Button(command.title) { command.perform(controller) }
                }
            }

            Divider()
            Button("Tăng thụt lề") { controller.changeIndent(by: EditorDefaults.tabIndent) }
                .keyboardShortcut("]", modifiers: .command)
            Button("Giảm thụt lề") { controller.changeIndent(by: -EditorDefaults.tabIndent) }
                .keyboardShortcut("[", modifiers: .command)
            Button("Tăng cỡ chữ") { controller.nudgeFontSize(by: 1) }
                .keyboardShortcut("+", modifiers: .command)
            Button("Giảm cỡ chữ") { controller.nudgeFontSize(by: -1) }
                .keyboardShortcut("-", modifiers: .command)
            Divider()
            Button("Xóa định dạng") { controller.clearFormatting() }
                .keyboardShortcut("\\", modifiers: .command)
        }

        CommandGroup(after: .sidebar) {
            Toggle("Bảng bên phải", isOn: Binding(get: { ui.showInspector }, set: { _ in actions.toggleOutline?() }))
                .keyboardShortcut("o", modifiers: [.command, .control])
            Toggle("Chế độ tập trung", isOn: Binding(get: { ui.focusMode }, set: { _ in actions.toggleFocusMode?() }))
                .keyboardShortcut("f", modifiers: [.command, .control])
            Button("Tổng quan") { actions.showDashboard?() }
                .keyboardShortcut("h", modifiers: [.command, .shift])
            Button("Quản lý thẻ…") { actions.manageTags?() }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            Divider()
            Toggle("Chữ nhỏ", isOn: $controller.canvasOptions.smallText)
                .keyboardShortcut("-", modifiers: [.command, .shift])
            Toggle("Lưới ô vuông", isOn: $controller.canvasOptions.showGrid)
                .keyboardShortcut("g", modifiers: [.command, .control])
            Toggle("Đường biên lề", isOn: $controller.canvasOptions.showMarginGuides)
            Toggle("Trang giấy rời", isOn: Binding(get: { !controller.canvasOptions.continuous }, set: { controller.canvasOptions.continuous = !$0 }))
            Toggle("Toàn chiều rộng", isOn: $controller.canvasOptions.fullWidth)
                .keyboardShortcut("\\", modifiers: [.command, .shift])
        }
    }

    @ViewBuilder
    private func styleButton(_ style: TextStyle) -> some View {
        let button = Button(style.label) { controller.apply(style: style) }
        switch style {
        case .heading1: button.keyboardShortcut("1", modifiers: [.command, .option])
        case .heading2: button.keyboardShortcut("2", modifiers: [.command, .option])
        case .heading3: button.keyboardShortcut("3", modifiers: [.command, .option])
        case .body: button.keyboardShortcut("0", modifiers: [.command, .option])
        default: button
        }
    }
}
