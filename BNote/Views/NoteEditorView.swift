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
        let zoom = max(layout.zoom, 0.01)
        let height = PageHeaderView.height(for: note, width: layout.width)
        let visualHeight = height * zoom
        let visible = max(0, visualHeight - layout.scrollOffset)
        return PagedEditor(controller: controller, headerHeight: visualHeight)
            .overlay(alignment: .top) {
                GeometryReader { geometry in
                    // Laid out at 100 % and scaled with the page, so zooming is uniform.
                    PageHeaderView(note: note, layout: layout)
                        .frame(width: geometry.size.width / zoom, height: height, alignment: .topLeading)
                        .scaleEffect(zoom, anchor: .topLeading)
                        .frame(width: geometry.size.width, height: visualHeight, alignment: .topLeading)
                        .offset(y: -layout.scrollOffset)
                }
                .frame(height: visible, alignment: .top)
                .clipped()
                .contentShape(.rect)
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
            widthControls
            statusToggle("Chữ nhỏ", icon: "textformat.size.smaller", keyPath: \.smallText)
            Divider().frame(height: 12)
            zoomMenu
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

    private var zoomMenu: some View {
        Menu {
            ForEach(CanvasOptions.zoomSteps, id: \.self) { step in
                Button {
                    controller.setZoom(step)
                } label: {
                    Text("\(Int(step * 100))%")
                    if abs(controller.canvasOptions.zoom - step) < 0.01 { Image(systemName: "checkmark") }
                }
            }
        } label: {
            Text("\(Int((controller.canvasOptions.zoom * 100).rounded()))%")
                .monospacedDigit()
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Thu phóng — pinch trên trackpad, ⌘+ ⌘− ⌘0")
    }

    private var widthControls: some View {
        Button {
            controller.toggleFullWidth()
        } label: {
            Label("Toàn rộng", systemImage: "arrow.left.and.right")
                .foregroundStyle(controller.canvasOptions.fullWidth ? Color.accentColor : .secondary)
        }
        .buttonStyle(.borderless)
        .disabled(!controller.canvasOptions.continuous)
        .help("Toàn chiều rộng: cột chữ giãn sát hai mép (⇧⌘\\)")
    }
}

private extension CGFloat {
    func rounded(toPlaces places: Int) -> CGFloat {
        let factor = pow(10, CGFloat(places))
        return (self * factor).rounded() / factor
    }
}
