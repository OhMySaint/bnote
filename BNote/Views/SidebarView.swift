import SwiftData
import SwiftUI

/// Everything the sidebar can do to a page; the dashboard reuses the same set.
struct PageActions {
    var add: (Note?) -> Void
    var delete: (Note) -> Void
    var duplicate: (Note) -> Void
    var move: (Note, Note?) -> Void
    var rename: (Note) -> Void
}

/// Shared chrome for every sidebar row — Overview, pages, tag filters — so all
/// of them share one left edge, one row height and one selected look.
///
/// The highlight is a quiet grey rather than the system's blue: the sidebar is
/// a place to navigate from, not the focus of the window (Notion and Finder's
/// unemphasised rows read the same way), and hand-painting it keeps every row
/// identical whether or not the list has keyboard focus.
struct SidebarRow<Content: View>: View {
    var depth: Int = 0
    var isSelected = false
    var action: () -> Void
    @ViewBuilder var content: () -> Content

    /// Width of the twisty column; rows without children still reserve it so
    /// icons line up all the way down the sidebar.
    static var twistyWidth: CGFloat { 14 }

    @State private var hovering = false

    var body: some View {
        content()
            .lineLimit(1)
            .padding(.leading, 6 + CGFloat(depth) * 13)
            .padding(.trailing, 6)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background, in: RoundedRectangle(cornerRadius: 6))
            .contentShape(.rect)
            .onTapGesture(perform: action)
            .onHover { hovering = $0 }
            .listRowInsets(EdgeInsets(top: 1, leading: 6, bottom: 1, trailing: 6))
            .listRowSeparator(.hidden)
    }

    private var background: Color {
        if isSelected { return Color.primary.opacity(0.11) }
        if hovering { return Color.primary.opacity(0.05) }
        return .clear
    }
}

/// Nested page tree, the way Notion organises documents.
struct SidebarView: View {
    let roots: [Note]
    let allNotes: [Note]
    let tags: [Tag]
    @Binding var selection: PersistentIdentifier?
    @Binding var search: String
    @Binding var activeTag: String?
    @Binding var renamingID: PersistentIdentifier?
    let actions: PageActions
    var onManageTags: () -> Void
    var onShowDashboard: () -> Void

    /// The tree as a flat list: every page whose ancestors are all expanded.
    private var visibleRows: [(note: Note, depth: Int)] {
        var rows: [(Note, Int)] = []
        func walk(_ notes: [Note], depth: Int) {
            for note in notes {
                rows.append((note, depth))
                if note.isExpanded, !note.sortedChildren.isEmpty {
                    walk(note.sortedChildren, depth: depth + 1)
                }
            }
        }
        walk(roots, depth: 0)
        return rows
    }

    private var usedTagNames: [String] {
        var seen = Set<String>()
        return allNotes.flatMap(\.tags).filter { seen.insert(Tag.key(for: $0)).inserted }.sorted()
    }

    var body: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    SidebarRow(isSelected: selection == nil, action: onShowDashboard) {
                        HStack(spacing: 6) {
                            // Empty twisty slot: keeps this icon in the same
                            // column as the page icons below.
                            Color.clear.frame(width: SidebarRow<EmptyView>.twistyWidth, height: 12)
                            Image(systemName: "square.grid.2x2")
                                .frame(width: 16)
                                .foregroundStyle(.secondary)
                            Text("Overview")
                        }
                    }
                }

                Section("Pages") {
                    // Flattened on purpose: a DisclosureGroup label never shows
                    // the List's selection tint, so a parent page looked
                    // unselected. Rows carry their own chevron and indent.
                    ForEach(visibleRows, id: \.note.persistentModelID) { row in
                        PageRow(
                            note: row.note,
                            depth: row.depth,
                            isSelected: selection == row.note.persistentModelID,
                            allNotes: allNotes,
                            tags: tags,
                            renamingID: $renamingID,
                            actions: actions,
                            onSelect: { selection = row.note.persistentModelID }
                        )
                    }
                }

                if !usedTagNames.isEmpty {
                    Section {
                        ForEach(usedTagNames, id: \.self) { name in
                            let isActive = activeTag.map { Tag.key(for: $0) == Tag.key(for: name) } ?? false
                            SidebarRow(isSelected: isActive, action: { activeTag = isActive ? nil : name }) {
                                HStack(spacing: 6) {
                                    Color.clear.frame(width: SidebarRow<EmptyView>.twistyWidth, height: 12)
                                    Circle()
                                        .fill(tags.color(for: name).color)
                                        .frame(width: 8, height: 8)
                                        .frame(width: 16)
                                    Text(name)
                                    Spacer(minLength: 4)
                                    if isActive {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                        }
                    } header: {
                        HStack {
                            Text("Tags")
                            Spacer()
                            Button(action: onManageTags) {
                                Image(systemName: "slider.horizontal.3")
                            }
                            .buttonStyle(.plain)
                            .help("Manage tags (⇧⌘T)")
                        }
                    }
                }
            }
            .overlay {
                if roots.isEmpty {
                    if search.isEmpty && activeTag == nil {
                        ContentUnavailableView {
                            Label("No pages yet", systemImage: "doc.text")
                        } description: {
                            Text("Every page is a document and can hold subpages.")
                        } actions: {
                            Button("Create your first page") { actions.add(nil) }
                                .buttonStyle(.borderedProminent)
                        }
                    } else {
                        ContentUnavailableView.search(text: search.isEmpty ? (activeTag ?? "") : search)
                    }
                }
            }

            Divider()
            footer
        }
        .searchable(text: $search, placement: .sidebar, prompt: "Search all pages")
        .navigationSplitViewColumnWidth(min: 220, ideal: 260)
    }

    private var footer: some View {
        HStack {
            Button {
                actions.add(nil)
            } label: {
                Label("New page", systemImage: "plus")
                    .font(.callout)
            }
            .buttonStyle(.borderless)
            .help("New page (⌘N)")
            Spacer()
            Text("\(allNotes.count) \(allNotes.count == 1 ? "page" : "pages")")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

/// Context menu shared by sidebar rows and dashboard cards.
struct PageContextMenu: View {
    let note: Note
    let allNotes: [Note]
    let actions: PageActions

    private static let icons = ["📄", "📝", "📘", "🗒️", "📊", "🧩", "🚀", "💡", "🗓️", "✅", "🔖", "🧪", "🎯", "📚", "🧠", "⭐️"]

    /// Pages this one can be moved under: everything except itself and its subtree.
    private var moveTargets: [Note] {
        let excluded = Set(([note] + note.descendants).map(\.persistentModelID))
        return allNotes
            .filter { !excluded.contains($0.persistentModelID) }
            .sorted { ($0.depth, $0.sortIndex, $0.createdAt) < ($1.depth, $1.sortIndex, $1.createdAt) }
    }

    var body: some View {
        Button("Rename") { actions.rename(note) }
        Button("Add subpage") { actions.add(note) }
        Button("Duplicate") { actions.duplicate(note) }

        Menu("Icon") {
            ForEach(Self.icons, id: \.self) { icon in
                Button(icon) {
                    note.icon = icon
                    note.touch()
                }
            }
        }

        Menu("Move to") {
            Button("Top level") { actions.move(note, nil) }
                .disabled(note.parent == nil)
            Divider()
            ForEach(moveTargets) { target in
                Button {
                    actions.move(note, target)
                } label: {
                    Text(String(repeating: "    ", count: target.depth) + "\(target.icon) \(target.displayTitle)")
                }
                .disabled(target.persistentModelID == note.parent?.persistentModelID)
            }
        }

        Divider()
        Button("Delete", role: .destructive) { actions.delete(note) }
    }
}

private struct PageRow: View {
    let note: Note
    var depth: Int = 0
    var isSelected = false
    let allNotes: [Note]
    let tags: [Tag]
    @Binding var renamingID: PersistentIdentifier?
    let actions: PageActions
    var onSelect: () -> Void = {}

    @State private var hovering = false
    @State private var draft = ""
    @FocusState private var renameFocused: Bool

    private var isRenaming: Bool { renamingID == note.persistentModelID }

    var body: some View {
        SidebarRow(depth: depth, isSelected: isSelected, action: onSelect) {
            HStack(spacing: 6) {
                chevron
                label
            }
        }
        .contextMenu {
            PageContextMenu(note: note, allNotes: allNotes, actions: actions)
        }
        .onChange(of: isRenaming) { _, renaming in
            if renaming {
                draft = note.title
                renameFocused = true
            }
        }
    }

    /// Twisty in the row itself, so the row stays a plain selectable List row.
    @ViewBuilder
    private var chevron: some View {
        if note.sortedChildren.isEmpty {
            Color.clear.frame(width: SidebarRow<EmptyView>.twistyWidth, height: 12)
        } else {
            Button {
                note.isExpanded.toggle()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(note.isExpanded ? 90 : 0))
                    .frame(width: SidebarRow<EmptyView>.twistyWidth, height: 12)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .animation(.easeOut(duration: 0.12), value: note.isExpanded)
        }
    }

    @ViewBuilder
    private var label: some View {
        if isRenaming {
            HStack(spacing: 6) {
                Text(note.icon)
                    .frame(width: 16)
                TextField("Page title", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .focused($renameFocused)
                    .onSubmit(commitRename)
                    .onExitCommand { renamingID = nil }
            }
        } else {
            HStack(spacing: 6) {
                Text(note.icon)
                    .frame(width: 16)
                Text(note.displayTitle)
                    .lineLimit(1)
                // Tags as plain dots: the row stays one line tall, so every row
                // in the sidebar has the same height.
                if !note.tags.isEmpty, !hovering {
                    HStack(spacing: 3) {
                        ForEach(note.tags.prefix(3), id: \.self) { tag in
                            Circle()
                                .fill(tags.color(for: tag).color)
                                .frame(width: 6, height: 6)
                        }
                    }
                    .help(note.tags.joined(separator: " · "))
                }
                Spacer(minLength: 4)
                if hovering {
                    Button {
                        actions.add(note)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .semibold))
                            .frame(width: 18, height: 18)
                            .background(Color.primary.opacity(0.08), in: .rect(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                    .help("Add subpage")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .onHover { hovering = $0 }
        }
    }

    private func commitRename() {
        note.title = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        note.touch()
        renamingID = nil
    }
}
