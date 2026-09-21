import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\Note.sortIndex), SortDescriptor(\Note.createdAt)])
    private var notes: [Note]
    @Query(sort: \Tag.name) private var tags: [Tag]

    @StateObject private var controller = DocumentController.shared
    @State private var selection: PersistentIdentifier?
    @State private var search = ""
    @State private var activeTag: String?
    @ObservedObject private var ui = AppUIState.shared
    @State private var inspectorTab = InspectorTab.outline
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var inspectorBeforeFocus = true
    @State private var pendingDeletion: Note?
    @State private var errorMessage: String?
    @State private var showTagManager = false
    @State private var renamingID: PersistentIdentifier?

    private var roots: [Note] {
        notes.filter { $0.parent == nil && passes($0) }
    }

    private var selectedNote: Note? {
        notes.first { $0.persistentModelID == selection }
    }

    private var pageActions: PageActions {
        PageActions(
            add: { parent in addPage(parent: parent) },
            delete: { note in requestDelete(note) },
            duplicate: { note in duplicate(note) },
            move: { note, target in move(note, under: target) },
            rename: { note in renamingID = note.persistentModelID }
        )
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(
                roots: roots,
                allNotes: notes,
                tags: tags,
                selection: $selection,
                search: $search,
                activeTag: $activeTag,
                renamingID: $renamingID,
                actions: pageActions,
                onManageTags: { showTagManager = true },
                onShowDashboard: { selection = nil }
            )
            .toolbar {
                ToolbarItem {
                    Button {
                        addPage(parent: nil)
                    } label: {
                        Label("Trang mới", systemImage: "square.and.pencil")
                    }
                    .help("Trang mới (⌘N)")
                }
            }
        } detail: {
            if let note = selectedNote {
                NoteEditorView(
                    note: note,
                    controller: controller,
                    showInspector: $ui.showInspector,
                    inspectorTab: $inspectorTab
                )
            } else {
                DashboardView(
                    notes: notes,
                    tags: tags,
                    actions: pageActions,
                    onOpen: { note in selection = note.persistentModelID },
                    onManageTags: { showTagManager = true }
                )
            }
        }
        .navigationTitle(selectedNote?.displayTitle ?? "Tổng quan")
        .onChange(of: selection) { _, _ in activate(selectedNote) }
        .onChange(of: controller.config) { _, config in
            selectedNote?.pageConfig = config
        }
        .onAppear(perform: wireCommands)
        .sheet(isPresented: $showTagManager) { TagManagerView() }
        .confirmationDialog(
            "Xóa “\(pendingDeletion?.displayTitle ?? "")”?",
            isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } })
        ) {
            Button("Xóa trang và trang con", role: .destructive) {
                if let note = pendingDeletion { delete(note) }
                pendingDeletion = nil
            }
            Button("Hủy", role: .cancel) { pendingDeletion = nil }
        } message: {
            Text("Mọi trang con bên trong cũng bị xóa.")
        }
        .alert("Không thực hiện được", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Filtering

    private func passes(_ note: Note) -> Bool {
        guard note.matches(search) else { return false }
        guard let activeTag else { return true }
        return hasTag(note, tag: activeTag)
    }

    private func hasTag(_ note: Note, tag: String) -> Bool {
        if note.tags.contains(where: { Tag.key(for: $0) == Tag.key(for: tag) }) { return true }
        return note.sortedChildren.contains { hasTag($0, tag: tag) }
    }

    // MARK: - Document activation

    private func activate(_ note: Note?) {
        controller.saveNow()
        controller.onSave = nil
        guard let note else {
            controller.load(data: nil, plainText: "", config: PageConfig())
            return
        }
        controller.load(data: note.rtfData, plainText: note.content, config: note.pageConfig)
        controller.onSave = { [weak note] data, text in
            guard let note else { return }
            note.rtfData = data
            note.content = text
            note.touch()
        }
        // The editor view may still be mounting; focus once it exists.
        DispatchQueue.main.async { controller.focusEditor() }
    }

    // MARK: - Page actions

    @discardableResult
    private func addPage(parent: Note?) -> Note {
        let siblings = parent?.sortedChildren ?? notes.filter { $0.parent == nil }
        let note = Note(parent: parent, sortIndex: (siblings.map(\.sortIndex).max() ?? 0) + 1)
        note.pageConfig = Defaults.pageConfig
        context.insert(note)
        parent?.isExpanded = true
        try? context.save()
        search = ""
        activeTag = nil
        selection = note.persistentModelID
        return note
    }

    private func requestDelete(_ note: Note) {
        if note.sortedChildren.isEmpty {
            delete(note)
        } else {
            pendingDeletion = note
        }
    }

    private func delete(_ note: Note) {
        if selection == note.persistentModelID {
            controller.onSave = nil
            selection = nil
        }
        context.delete(note)
        try? context.save()
    }

    private func duplicate(_ note: Note) {
        let copy = Note(title: note.title + " (bản sao)", parent: note.parent, sortIndex: note.sortIndex + 1)
        copy.content = note.content
        copy.rtfData = note.rtfData
        copy.tags = note.tags
        copy.icon = note.icon
        copy.pageConfig = note.pageConfig
        copy.coverData = note.coverData
        copy.coverStyle = note.coverStyle
        copy.coverHeight = note.coverHeight
        copy.headerAlignmentRaw = note.headerAlignmentRaw
        copy.subtitle = note.subtitle
        copy.showIcon = note.showIcon
        context.insert(copy)
        try? context.save()
        selection = copy.persistentModelID
    }

    private func move(_ note: Note, under target: Note?) {
        // Never move a page into its own subtree.
        if let target, ([note] + note.descendants).contains(where: { $0.persistentModelID == target.persistentModelID }) {
            return
        }
        let siblings = target?.sortedChildren ?? notes.filter { $0.parent == nil }
        note.parent = target
        note.sortIndex = (siblings.map(\.sortIndex).max() ?? 0) + 1
        target?.isExpanded = true
        note.touch()
        try? context.save()
    }

    // MARK: - Import / export

    private func importDocuments() {
        let documents = DocumentIO.runImportPanel()
        guard !documents.isEmpty else { return }
        var last: Note?
        for document in documents {
            let note = Note(title: document.title, sortIndex: (notes.map(\.sortIndex).max() ?? 0) + 1)
            note.rtfData = document.attributed.rtfd(
                from: NSRange(location: 0, length: document.attributed.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]
            )
            note.content = document.attributed.string
            context.insert(note)
            last = note
        }
        try? context.save()
        if let last {
            selection = last.persistentModelID
        }
    }

    private func export(_ format: DocumentFormat) {
        guard let note = selectedNote else { return }
        controller.saveNow()
        do {
            try DocumentIO.runExportPanel(
                attributed: controller.attributedCopy,
                format: format,
                suggestedName: note.displayTitle,
                config: controller.config
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func wireCommands() {
        let actions = AppActions.shared
        actions.newPage = { addPage(parent: nil) }
        actions.newSubpage = { addPage(parent: selectedNote) }
        actions.deleteCurrent = { if let note = selectedNote { requestDelete(note) } }
        actions.importDocuments = { importDocuments() }
        actions.export = { format in export(format) }
        actions.toggleOutline = { ui.showInspector.toggle() }
        actions.showPageSetup = {
            inspectorTab = .page
            ui.showInspector = true
        }
        actions.showDashboard = { selection = nil }
        actions.manageTags = { showTagManager = true }
        actions.toggleFocusMode = {
            withAnimation(.easeInOut(duration: 0.2)) {
                if ui.focusMode {
                    columnVisibility = .all
                    ui.showInspector = inspectorBeforeFocus
                    ui.focusMode = false
                } else {
                    inspectorBeforeFocus = ui.showInspector
                    columnVisibility = .detailOnly
                    ui.showInspector = false
                    ui.focusMode = true
                }
            }
        }
        actions.printDocument = {
            controller.saveNow()
            controller.documentView?.printDocument(jobTitle: selectedNote?.displayTitle ?? "BNote")
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Note.self, Tag.self], inMemory: true)
}
