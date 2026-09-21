import SwiftData
import SwiftUI

struct NoteEditorView: View {
    @Bindable var note: Note
    @ObservedObject var controller: DocumentController
    @Binding var showInspector: Bool
    @Binding var inspectorTab: InspectorTab

    @State private var newTag = ""
    @State private var showIconPicker = false
    @FocusState private var tagFieldFocused: Bool

    private static let icons = [
        "📄", "📝", "📘", "🗒️", "📊", "🧩", "🚀", "💡", "🗓️", "✅", "🔖", "🧪",
        "🎯", "🏗️", "📚", "🧠", "💬", "🗂️", "⭐️", "🔥",
    ]

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
                        .transition(.move(edge: .trailing))
                }
            }
            .animation(.easeInOut(duration: 0.18), value: showInspector)
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
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                showIconPicker.toggle()
            } label: {
                Text(note.icon)
                    .font(.system(size: 22))
                    .frame(width: 34, height: 34)
                    .background(Color.primary.opacity(0.05), in: .rect(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .help("Đổi biểu tượng trang")
            .popover(isPresented: $showIconPicker, arrowEdge: .bottom) {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(34)), count: 5), spacing: 4) {
                    ForEach(Self.icons, id: \.self) { icon in
                        Button {
                            note.icon = icon
                            note.touch()
                            showIconPicker = false
                        } label: {
                            Text(icon)
                                .font(.system(size: 20))
                                .frame(width: 32, height: 32)
                                .background(
                                    note.icon == icon ? Color.accentColor.opacity(0.18) : .clear,
                                    in: .rect(cornerRadius: 6)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(10)
            }

            TextField("Trang không tên", text: $note.title)
                .textFieldStyle(.plain)
                .font(.title2.weight(.semibold))
                .onChange(of: note.title) { _, _ in note.touch() }

            tagsEditor
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var tagsEditor: some View {
        HStack(spacing: 6) {
            ForEach(note.tags, id: \.self) { tag in
                HStack(spacing: 3) {
                    Text(tag)
                    Button {
                        note.tags.removeAll { $0 == tag }
                        note.touch()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.14), in: .capsule)
            }

            HStack(spacing: 4) {
                Image(systemName: "tag")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
                TextField(note.tags.isEmpty ? "Thêm thẻ" : "Thêm", text: $newTag)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .frame(width: note.tags.isEmpty ? 70 : 46)
                    .focused($tagFieldFocused)
                    .onSubmit(commitTag)
                    .onChange(of: newTag) { _, value in
                        if value.hasSuffix(",") { commitTag() }
                    }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.primary.opacity(tagFieldFocused ? 0.08 : 0.04), in: .capsule)
        }
    }

    private func commitTag() {
        let parsed = Note.parseTags(newTag)
        newTag = ""
        guard !parsed.isEmpty else { return }
        var tags = note.tags
        for tag in parsed where !tags.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) {
            tags.append(tag)
        }
        guard tags != note.tags else { return }
        note.tags = tags
        note.touch()
    }

    // MARK: - Status bar

    private var statusBar: some View {
        HStack(spacing: 12) {
            saveIndicator
            Divider().frame(height: 12)
            Text("\(controller.pageCount) trang · \(controller.wordCount) từ · \(controller.characterCount) ký tự")
                .monospacedDigit()
            Divider().frame(height: 12)
            Text("\(controller.config.paper.label) \(controller.config.orientation.label.lowercased()) · lề \(Unit.centimeters(controller.config.margins.left)) cm")

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
        .background(.bar)
    }

    private var saveIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: controller.hasUnsavedChanges ? "circle.fill" : "checkmark.circle.fill")
                .font(.system(size: 8))
                .foregroundStyle(controller.hasUnsavedChanges ? Color.orange : Color.green)
            Text(controller.hasUnsavedChanges ? "Đang lưu…" : "Đã lưu \(note.updatedAt.formatted(date: .omitted, time: .shortened))")
        }
        .animation(.easeInOut(duration: 0.2), value: controller.hasUnsavedChanges)
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
        HStack(spacing: 2) {
            Button {
                controller.canvasOptions.zoom = max(0.5, (controller.canvasOptions.zoom - 0.1).rounded(toPlaces: 1))
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .buttonStyle(.borderless)
            .help("Thu nhỏ")

            Button("\(Int((controller.canvasOptions.zoom * 100).rounded()))%") {
                controller.canvasOptions.zoom = 1
            }
            .buttonStyle(.borderless)
            .monospacedDigit()
            .frame(width: 40)
            .help("Về 100% (⌘0)")

            Button {
                controller.canvasOptions.zoom = min(2.5, (controller.canvasOptions.zoom + 0.1).rounded(toPlaces: 1))
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .buttonStyle(.borderless)
            .help("Phóng to")
        }
    }
}

private extension CGFloat {
    func rounded(toPlaces places: Int) -> CGFloat {
        let factor = pow(10, CGFloat(places))
        return (self * factor).rounded() / factor
    }
}
