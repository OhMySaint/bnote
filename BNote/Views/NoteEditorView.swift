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
    @ObservedObject private var find = DocumentController.shared.find

    /// The Notion-style header is a SwiftUI overlay above the canvas, scrolled
    /// in step with it, so it stays crisp and fully interactive.
    private var editorWithHeader: some View {
        let layout = headerLayout
        let height = PageHeaderView.height(for: note, width: layout.width)
        let visible = max(0, height - layout.scrollOffset)
        return PagedEditor(controller: controller, headerHeight: height)
            .overlay(alignment: .top) {
                GeometryReader { geometry in
                    PageHeaderView(note: note, layout: layout)
                        .frame(width: geometry.size.width, height: height, alignment: .topLeading)
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
            if find.isVisible {
                FindBar(controller: controller, model: find)
                Divider()
            }
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
                    Label("Inspector", systemImage: "sidebar.right")
                }
                .help("Show or hide the inspector (⌃⌘O)")
            }
        }
    }

    // MARK: - Status bar

    private var statusBar: some View {
        HStack(spacing: 12) {
            saveIndicator
            Divider().frame(height: 12)
            Text(controller.canvasOptions.continuous
                ? "\(controller.wordCount) words · \(controller.characterCount) characters"
                : "\(controller.pageCount) pages · \(controller.wordCount) words · \(controller.characterCount) characters")
                .monospacedDigit()
            Divider().frame(height: 12)
            Text("\(controller.config.paper.label) \(controller.config.orientation.label.lowercased()) · \(Unit.format(controller.config.margins.left)) margins")

            Spacer()

            Text("Press / to insert a block")
                .foregroundStyle(.tertiary)

            Divider().frame(height: 12)
            layoutToggles
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
            Text(controller.hasUnsavedChanges ? "Saving…" : "Saved \(note.updatedAt.formatted(date: .omitted, time: .shortened))")
        }
        .animation(.easeInOut(duration: 0.2), value: controller.hasUnsavedChanges)
    }

    /// Notion's page option "Full width", as a switch.
    private var layoutToggles: some View {
        Toggle(isOn: $controller.canvasOptions.fullWidth) {
            Label("Full width", systemImage: "arrow.left.and.right")
        }
        .help("Full width: the text column stretches to both edges (⇧⌘\\)")
        .toggleStyle(.switch)
        .controlSize(.mini)
        .disabled(!controller.canvasOptions.continuous)
    }
}
