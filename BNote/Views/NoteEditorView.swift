import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct NoteEditorView: View {
    @Bindable var note: Note
    @ObservedObject var controller: DocumentController
    @Binding var showInspector: Bool
    @Binding var inspectorTab: InspectorTab

    @Environment(\.modelContext) private var context
    @Query(sort: \Tag.name) private var tags: [Tag]
    @ObservedObject private var headerLayout = DocumentController.shared.headerLayout

    /// The Notion-style header is a SwiftUI overlay above the (magnified) canvas,
    /// scrolled in step with it, so it stays crisp and fully interactive.
    private var editorWithHeader: some View {
        let layout = headerLayout
        let height = PageHeaderView.height(for: note, width: layout.width)
        let visible = max(0, height - layout.scrollOffset)
        return PagedEditor(controller: controller, headerHeight: height)
            .overlay(alignment: .top) {
                PageHeaderView(note: note, layout: layout)
                    .frame(height: height)
                    .frame(height: visible, alignment: .bottom)
                    .clipped()
                    .contentShape(.rect)
                    .padding(.top, layout.top)
                    .allowsHitTesting(visible > 1)
            }
    }

    var body: some View {
        VStack(spacing: 0) {
            FormatToolbar(controller: controller)
            Divider()
            HStack(spacing: 0) {
                editorWithHeader
                if showInspector {
                    Divider()
                    InspectorPanel(controller: controller, tab: $inspectorTab, note: note)
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

    // MARK: - Status bar

    private var statusBar: some View {
        HStack(spacing: 12) {
            saveIndicator
            Divider().frame(height: 12)
            Text(controller.canvasOptions.continuous
                ? "\(controller.wordCount) từ · \(controller.characterCount) ký tự"
                : "\(controller.pageCount) trang · \(controller.wordCount) từ · \(controller.characterCount) ký tự")
                .monospacedDigit()
            Divider().frame(height: 12)
            Text("\(controller.config.paper.label) \(controller.config.orientation.label.lowercased()) · lề \(Unit.format(controller.config.margins.left))")

            Spacer()

            Text("Gõ / để chèn khối")
                .foregroundStyle(.tertiary)

            Divider().frame(height: 12)
            statusToggle("Thước", icon: "ruler", keyPath: \.showRuler)
            statusToggle("Lưới", icon: "grid", keyPath: \.showGrid)

            Divider().frame(height: 12)
            widthControls
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

    private var widthControls: some View {
        Button {
            controller.toggleFullWidth()
        } label: {
            Label(controller.canvasOptions.fullWidth ? "Toàn rộng" : "Cột đọc", systemImage: controller.canvasOptions.fullWidth ? "arrow.left.and.right" : "text.justify.leading")
                .foregroundStyle(controller.canvasOptions.fullWidth ? Color.accentColor : .secondary)
        }
        .buttonStyle(.borderless)
        .disabled(!controller.canvasOptions.continuous)
        .help("Cột đọc 720pt hoặc giãn hết cửa sổ (⇧⌘\\)")
    }
}

private extension CGFloat {
    func rounded(toPlaces places: Int) -> CGFloat {
        let factor = pow(10, CGFloat(places))
        return (self * factor).rounded() / factor
    }
}
