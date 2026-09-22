import SwiftData
import SwiftUI

/// Master screen: every page at a glance, with search, sort, tag filter,
/// and the same actions as the sidebar.
struct DashboardView: View {
    let notes: [Note]
    let tags: [Tag]
    let actions: PageActions
    var onOpen: (Note) -> Void
    var onManageTags: () -> Void

    @State private var query = ""
    @State private var sort = SortMode.updated
    @State private var tagFilter: String?
    @State private var layout = Layout.grid
    @State private var onlyRoots = true

    enum SortMode: String, CaseIterable, Identifiable {
        case updated, created, title
        var id: String { rawValue }
        var label: String {
            switch self {
            case .updated: "Recently edited"
            case .created: "Recently created"
            case .title: "Title A–Z"
            }
        }
    }

    enum Layout: String, CaseIterable, Identifiable {
        case grid, list
        var id: String { rawValue }
        var symbol: String { self == .grid ? "square.grid.2x2" : "list.bullet" }
    }

    private var visible: [Note] {
        var result = notes
        if onlyRoots { result = result.filter { $0.parent == nil } }
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        if !needle.isEmpty {
            result = result.filter {
                $0.title.lowercased().contains(needle)
                    || $0.content.lowercased().contains(needle)
                    || $0.tags.contains { $0.lowercased().contains(needle) }
            }
        }
        if let tagFilter {
            let key = Tag.key(for: tagFilter)
            result = result.filter { $0.tags.contains { Tag.key(for: $0) == key } }
        }
        switch sort {
        case .updated: result.sort { $0.updatedAt > $1.updatedAt }
        case .created: result.sort { $0.createdAt > $1.createdAt }
        case .title: result.sort { $0.displayTitle.localizedCaseInsensitiveCompare($1.displayTitle) == .orderedAscending }
        }
        return result
    }

    private var usedTags: [String] {
        var seen = Set<String>()
        return notes.flatMap(\.tags).filter { seen.insert(Tag.key(for: $0)).inserted }.sorted()
    }

    private var totalWords: Int {
        notes.reduce(0) { $0 + $1.content.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if visible.isEmpty {
                ContentUnavailableView {
                    Label(notes.isEmpty ? "No pages yet" : "No matching pages", systemImage: "square.grid.2x2")
                } description: {
                    Text(notes.isEmpty ? "Create your first page to get started." : "Try another search, or clear the tag filter.")
                } actions: {
                    if notes.isEmpty {
                        Button("New page") { actions.add(nil) }
                            .buttonStyle(.borderedProminent)
                    }
                }
                // Without this the empty state keeps its natural height, the
                // whole screen shrinks, and the split view centres it — which
                // reads as a huge blank band above the title.
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    switch layout {
                    case .grid:
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 14)], spacing: 14) {
                            ForEach(visible) { note in
                                PageCard(note: note, tags: tags)
                                    .onTapGesture { onOpen(note) }
                                    .contextMenu { PageContextMenu(note: note, allNotes: notes, actions: actions) }
                            }
                        }
                        .padding(18)
                    case .list:
                        LazyVStack(spacing: 0) {
                            ForEach(visible) { note in
                                PageListRow(note: note, tags: tags)
                                    .contentShape(.rect)
                                    .onTapGesture { onOpen(note) }
                                    .contextMenu { PageContextMenu(note: note, allNotes: notes, actions: actions) }
                                Divider()
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Overview")
                    .font(.largeTitle.weight(.bold))
                if AppFlavor.isDev {
                    // Two copies can run side by side; this says which one.
                    Text("DEV \(AppFlavor.version)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.orange, in: .capsule)
                }
                Spacer()
                Button {
                    actions.add(nil)
                } label: {
                    Label("New page", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }

            HStack(spacing: 18) {
                stat("\(notes.count)", "trang")
                stat("\(notes.filter { $0.parent == nil }.count)", "top level")
                stat("\(totalWords)", "words")
                stat("\(usedTags.count)", "tags")
            }

            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search pages…", text: $query)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.primary.opacity(0.05), in: .rect(cornerRadius: 7))
                .frame(maxWidth: 280)

                Picker("", selection: $sort) {
                    ForEach(SortMode.allCases) { Text($0.label).tag($0) }
                }
                .labelsHidden()
                .fixedSize()

                Toggle("Top level only", isOn: $onlyRoots)
                    .toggleStyle(.checkbox)

                Spacer()

                Picker("", selection: $layout) {
                    ForEach(Layout.allCases) { Image(systemName: $0.symbol).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }

            if !usedTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        filterChip("All", selected: tagFilter == nil) { tagFilter = nil }
                        ForEach(usedTags, id: \.self) { tag in
                            let selected = tagFilter.map { Tag.key(for: $0) == Tag.key(for: tag) } ?? false
                            filterChip(tag, color: tags.color(for: tag), selected: selected) {
                                tagFilter = selected ? nil : tag
                            }
                        }
                        Button(action: onManageTags) {
                            Label("Manage tags", systemImage: "slider.horizontal.3")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                        .padding(.leading, 6)
                    }
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(value).font(.title3.weight(.semibold)).monospacedDigit()
            Text(label).foregroundStyle(.secondary)
        }
    }

    private func filterChip(_ text: String, color: TagColor? = nil, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let color {
                    Circle().fill(color.color).frame(width: 6, height: 6)
                }
                Text(text)
            }
            .font(.caption)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(selected ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.05), in: .capsule)
            .overlay(Capsule().stroke(selected ? Color.accentColor : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct PageCard: View {
    let note: Note
    let tags: [Tag]
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                if note.hasCover {
                    CoverView(note: note)
                        .frame(height: 92)
                        .clipped()
                } else {
                    Color.primary.opacity(0.04)
                        .frame(height: 92)
                }
                Text(note.icon)
                    .font(.system(size: 26))
                    .padding(8)
                    .background(.regularMaterial, in: .rect(cornerRadius: 8))
                    .padding(8)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(note.displayTitle)
                    .font(.headline)
                    .lineLimit(1)
                Text(note.snippet.isEmpty ? "Blank page" : note.snippet)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !note.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(note.tags.prefix(3), id: \.self) { tag in
                            TagChip(name: tag, color: tags.color(for: tag), compact: true)
                        }
                    }
                }
                HStack {
                    Text(note.updatedAt.formatted(.relative(presentation: .named)))
                    Spacer()
                    if !note.sortedChildren.isEmpty {
                        Label("\(note.sortedChildren.count)", systemImage: "doc.on.doc")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
            .padding(10)
        }
        .background(.background, in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(hovering ? Color.accentColor.opacity(0.55) : Color.primary.opacity(0.07)))
        .shadow(color: .black.opacity(hovering ? 0.10 : 0.04), radius: hovering ? 10 : 2, y: hovering ? 3 : 1)
        .animation(.easeOut(duration: 0.14), value: hovering)
        .onHover { hovering = $0 }
    }
}

private struct PageListRow: View {
    let note: Note
    let tags: [Tag]

    var body: some View {
        HStack(spacing: 12) {
            Text(note.icon).font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if note.depth > 0 {
                        Text(String(repeating: "› ", count: note.depth))
                            .foregroundStyle(.tertiary)
                    }
                    Text(note.displayTitle).font(.body.weight(.medium))
                }
                Text(note.snippet.isEmpty ? "Blank page" : note.snippet)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            ForEach(note.tags.prefix(3), id: \.self) { tag in
                TagChip(name: tag, color: tags.color(for: tag), compact: true)
            }
            Text(note.updatedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(width: 130, alignment: .trailing)
        }
        .padding(.vertical, 8)
    }
}
