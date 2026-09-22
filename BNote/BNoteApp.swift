import AppKit
import SwiftData
import SwiftUI

@main
struct BNoteApp: App {
    init() {
        // Before the store opens, so a failed migration still has a way back.
        StoreBackup.run()
        Defaults.register()
        DocumentController.shared.canvasOptions = Defaults.canvasOptions
    }

    var body: some Scene {
        Window(AppFlavor.name, id: "main") {
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
            Button("New page") { actions.newPage?() }
                .keyboardShortcut("n", modifiers: .command)
            Button("New subpage") { actions.newSubpage?() }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            Divider()
            Button("Import documents…") { actions.importDocuments?() }
                .keyboardShortcut("i", modifiers: [.command, .shift])
            Menu("Export") {
                ForEach(DocumentFormat.allCases) { format in
                    Button(format.label) { actions.export?(format) }
                }
            }
        }

        CommandMenu("Page") {
            Button("Cover: choose picture…") { actions.setCoverFromFile?() }
            Button("Cover: paste from clipboard") { actions.setCoverFromClipboard?() }
            Button("Remove cover") { actions.removeCover?() }
            Divider()
            Button("Page setup…") { actions.showPageSetup?() }
                .keyboardShortcut("p", modifiers: [.command, .shift])
        }

        // Replaces the stock Find submenu so ⌘F / ⌘G drive the in-page bar
        // whatever has focus.
        CommandGroup(replacing: .textEditing) {
            Menu("Find") {
                Button("Find in page…") { controller.showFind() }
                    .keyboardShortcut("f", modifiers: .command)
                Button("Find and Replace…") { controller.showFind(replace: true) }
                    .keyboardShortcut("f", modifiers: [.command, .option])
                Divider()
                Button("Next match") { controller.findNext() }
                    .keyboardShortcut("g", modifiers: .command)
                Button("Previous match") { controller.findPrevious() }
                    .keyboardShortcut("g", modifiers: [.command, .shift])
                Button("Use Selection for Find") { controller.useSelectionForFind() }
                    .keyboardShortcut("e", modifiers: .command)
            }
        }

        CommandGroup(replacing: .printItem) {
            Button("In…") { actions.printDocument?() }
                .keyboardShortcut("p", modifiers: .command)
        }

        CommandMenu("Format") {
            Button("Bold") { controller.toggleTrait(.boldFontMask) }
                .keyboardShortcut("b", modifiers: .command)
            Button("Italic") { controller.toggleTrait(.italicFontMask) }
                .keyboardShortcut("i", modifiers: .command)
            Button("Underline") { controller.toggleUnderline() }
                .keyboardShortcut("u", modifiers: .command)
            Button("Strikethrough") { controller.toggleStrikethrough() }
            Divider()

            Menu("Style") {
                ForEach(TextStyle.allCases) { style in
                    styleButton(style)
                }
            }

            Menu("Alignment") {
                Button("Left") { controller.setAlignment(.left) }
                    .keyboardShortcut("l", modifiers: [.command, .shift])
                Button("Center") { controller.setAlignment(.center) }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                Button("Right") { controller.setAlignment(.right) }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                Button("Justified") { controller.setAlignment(.justified) }
                    .keyboardShortcut("j", modifiers: [.command, .shift])
            }

            Menu("Lists") {
                Button("Bulleted list") { controller.toggleList(.bullet) }
                    .keyboardShortcut("8", modifiers: [.command, .shift])
                Button("Numbered list") { controller.toggleList(.numbered) }
                    .keyboardShortcut("7", modifiers: [.command, .shift])
                Button("To-do list") { controller.toggleList(.todo) }
                    .keyboardShortcut("9", modifiers: [.command, .shift])
            }

            Menu("Insert block") {
                ForEach(SlashCatalog.all) { command in
                    Button(command.title) { command.perform(controller) }
                }
            }

            Divider()
            Button("Increase indent") { controller.changeIndent(by: EditorDefaults.tabIndent) }
                .keyboardShortcut("]", modifiers: .command)
            Button("Decrease indent") { controller.changeIndent(by: -EditorDefaults.tabIndent) }
                .keyboardShortcut("[", modifiers: .command)
            Button("Bigger") { controller.nudgeFontSize(by: 1) }
                .keyboardShortcut(".", modifiers: [.command, .shift])
            Button("Smaller") { controller.nudgeFontSize(by: -1) }
                .keyboardShortcut(",", modifiers: [.command, .shift])
            Divider()
            Button("Clear formatting") { controller.clearFormatting() }
                .keyboardShortcut("\\", modifiers: .command)
        }

        CommandGroup(after: .sidebar) {
            Toggle("Inspector", isOn: Binding(get: { ui.showInspector }, set: { _ in actions.toggleOutline?() }))
                .keyboardShortcut("o", modifiers: [.command, .control])
            Toggle("Focus mode", isOn: Binding(get: { ui.focusMode }, set: { _ in actions.toggleFocusMode?() }))
                .keyboardShortcut("f", modifiers: [.command, .control])
            Button("Overview") { actions.showDashboard?() }
                .keyboardShortcut("h", modifiers: [.command, .shift])
            Button("Manage tags…") { actions.manageTags?() }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            Divider()
            Toggle("Grid", isOn: $controller.canvasOptions.showGrid)
                .keyboardShortcut("g", modifiers: [.command, .control])
            Toggle("Margin guides", isOn: $controller.canvasOptions.showMarginGuides)
            Toggle("Paper pages", isOn: Binding(get: { !controller.canvasOptions.continuous }, set: { controller.canvasOptions.continuous = !$0 }))
            Toggle("Full width", isOn: $controller.canvasOptions.fullWidth)
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
