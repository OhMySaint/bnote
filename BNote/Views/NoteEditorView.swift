import SwiftData
import SwiftUI

struct NoteEditorView: View {
    @Bindable var note: Note
    @ObservedObject var controller: DocumentController
    @Binding var showInspector: Bool
    @Binding var inspectorTab: InspectorTab

    @State private var tagsText = ""

    private static let icons = ["📄", "📝", "📘", "🗒️", "📊", "🧩", "🚀", "💡", "🗓️", "✅", "🔖", "🧪"]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            FormatToolbar(controller: controller)
            Divider()
            HStack(spacing: 0) {
                PagedEditor(controller: controller)
                if showInspector {
                    Divider()
                    InspectorPanel(controller: controller, tab: $inspectorTab)
                }
            }
            Divider()
            statusBar
        }
        .toolbar {
            ToolbarItem {
                Button {
                    showInspector.toggle()
                } label: {
                    Label("Bảng điều khiển", systemImage: "sidebar.right")
                }
                .help("Ẩn/hiện bảng bên phải (⌃⌘O)")
            }
        }
        .task(id: note.persistentModelID) {
            tagsText = note.tags.joined(separator: ", ")
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Menu {
                ForEach(Self.icons, id: \.self) { icon in
                    Button(icon) { note.icon = icon }
                }
            } label: {
                Text(note.icon).font(.title3)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()

            TextField("Tên trang", text: $note.title)
                .textFieldStyle(.plain)
                .font(.title3.weight(.semibold))
                .onChange(of: note.title) { _, _ in note.touch() }

            HStack(spacing: 4) {
                Image(systemName: "tag")
                    .foregroundStyle(.secondary)
                TextField("Thẻ, cách nhau bằng dấu phẩy", text: $tagsText)
                    .textFieldStyle(.plain)
                    .frame(width: 190)
                    .onSubmit(commitTags)
            }
            .font(.callout)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var statusBar: some View {
        HStack(spacing: 14) {
            Label("\(controller.pageCount) trang", systemImage: "doc.on.doc")
            Label("\(controller.wordCount) từ", systemImage: "textformat.abc")
            Text("\(controller.characterCount) ký tự")

            Divider().frame(height: 12)
            Text("\(controller.config.paper.label) · \(controller.config.orientation.label) · lề \(Unit.centimeters(controller.config.margins.left)) cm")

            Spacer()

            Text("Gõ / để chèn khối")
                .foregroundStyle(.tertiary)

            Divider().frame(height: 12)
            statusToggle("Thước", icon: "ruler", keyPath: \.showRuler)
            statusToggle("Lưới", icon: "grid", keyPath: \.showGrid)

            Divider().frame(height: 12)
            zoomControls
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 5)
    }

    private func statusToggle(_ label: String, icon: String, keyPath: WritableKeyPath<CanvasOptions, Bool>) -> some View {
        let isOn = controller.canvasOptions[keyPath: keyPath]
        return Button {
            controller.canvasOptions[keyPath: keyPath].toggle()
        } label: {
            Label(label, systemImage: icon)
                .foregroundStyle(isOn ? Color.accentColor : .secondary)
        }
        .buttonStyle(.borderless)
        .help("Ẩn/hiện \(label.lowercased())")
    }

    private var zoomControls: some View {
        HStack(spacing: 4) {
            Button {
                controller.canvasOptions.zoom = max(0.5, controller.canvasOptions.zoom - 0.1)
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .buttonStyle(.borderless)

            Button("\(Int(controller.canvasOptions.zoom * 100))%") {
                controller.canvasOptions.zoom = 1
            }
            .buttonStyle(.borderless)
            .monospacedDigit()
            .help("Về 100%")

            Button {
                controller.canvasOptions.zoom = min(2.5, controller.canvasOptions.zoom + 0.1)
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .buttonStyle(.borderless)
        }
    }

    private func commitTags() {
        let parsed = Note.parseTags(tagsText)
        guard parsed != note.tags else { return }
        note.tags = parsed
        note.touch()
    }
}
