import AppKit
import SwiftData
import SwiftUI

/// Bridges menu commands to the single document window.
final class AppActions {
    static let shared = AppActions()

    var newPage: (() -> Void)?
    var newSubpage: (() -> Void)?
    var deleteCurrent: (() -> Void)?
    var importDocuments: (() -> Void)?
    var export: ((DocumentFormat) -> Void)?
    var toggleOutline: (() -> Void)?
    var printDocument: (() -> Void)?
}

@main
struct BNoteApp: App {
    var body: some Scene {
        Window("BNote", id: "main") {
            ContentView()
        }
        .modelContainer(for: Note.self)
        .defaultSize(width: 1180, height: 820)
        .commands { BNoteCommands() }
    }
}

struct BNoteCommands: Commands {
    private var controller: DocumentController { .shared }
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
            Button("Ẩn/hiện mục lục") { actions.toggleOutline?() }
                .keyboardShortcut("o", modifiers: [.command, .control])
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
