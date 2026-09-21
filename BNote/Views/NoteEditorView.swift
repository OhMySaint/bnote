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

    var body: some View {
        VStack(spacing: 0) {
            FormatToolbar(controller: controller)
            Divider()
            HStack(spacing: 0) {
                PagedEditor(
                    controller: controller,
                    header: AnyView(PageHeaderView(note: note, layout: controller.headerLayout)),
                    headerHeight: { width in PageHeaderView.height(for: note, width: width) }
                )
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

    // MARK: - Status bar

    private var statusBar: some View {
        HStack(spacing: 12) {
            saveIndicator
            Divider().frame(height: 12)
            Text("\(controller.pageCount) trang · \(controller.wordCount) từ · \(controller.characterCount) ký tự")
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
                controller.setZoom((controller.effectiveZoom - 0.1).rounded(toPlaces: 1))
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .buttonStyle(.borderless)
            .help("Thu nhỏ")

            Menu {
                Button("Vừa chiều rộng") { controller.zoomToFitWidth() }
                    .disabled(controller.canvasOptions.fitWidth)
                Divider()
                ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { value in
                    Button("\(Int(value * 100))%") { controller.setZoom(CGFloat(value)) }
                }
            } label: {
                Text(controller.canvasOptions.fitWidth
                    ? "Vừa · \(Int((controller.effectiveZoom * 100).rounded()))%"
                    : "\(Int((controller.effectiveZoom * 100).rounded()))%")
                    .monospacedDigit()
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Thu phóng — Vừa chiều rộng tự co giãn theo cửa sổ (⌘9)")

            Button {
                controller.setZoom((controller.effectiveZoom + 0.1).rounded(toPlaces: 1))
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
