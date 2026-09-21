import SwiftData
import SwiftUI

/// Nested page tree, the way Notion organises documents.
struct SidebarView: View {
    let roots: [Note]
    let allTags: [String]
    @Binding var selection: PersistentIdentifier?
    @Binding var search: String
    @Binding var activeTag: String?

    var onAddPage: (Note?) -> Void
    var onDelete: (Note) -> Void
    var onDuplicate: (Note) -> Void

    var body: some View {
        List(selection: $selection) {
            Section("Trang") {
                ForEach(roots) { note in
                    PageRow(
                        note: note,
                        onAddPage: onAddPage,
                        onDelete: onDelete,
                        onDuplicate: onDuplicate
                    )
                }
            }

            if !allTags.isEmpty {
                Section("Thẻ") {
                    ForEach(allTags, id: \.self) { tag in
                        HStack(spacing: 6) {
                            Image(systemName: activeTag == tag ? "tag.fill" : "tag")
                            Text(tag)
                            Spacer()
                        }
                        .foregroundStyle(activeTag == tag ? Color.accentColor : .primary)
                        .contentShape(.rect)
                        .onTapGesture {
                            activeTag = activeTag == tag ? nil : tag
                        }
                    }
                }
            }
        }
        .searchable(text: $search, placement: .sidebar, prompt: "Tìm trong mọi trang")
        .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        .overlay {
            if roots.isEmpty {
                ContentUnavailableView(
                    search.isEmpty ? "Chưa có trang" : "Không tìm thấy",
                    systemImage: search.isEmpty ? "doc.text" : "magnifyingglass"
                )
            }
        }
    }
}

private struct PageRow: View {
    let note: Note
    var onAddPage: (Note?) -> Void
    var onDelete: (Note) -> Void
    var onDuplicate: (Note) -> Void

    var body: some View {
        Group {
            if note.sortedChildren.isEmpty {
                label
            } else {
                DisclosureGroup(isExpanded: expansion) {
                    ForEach(note.sortedChildren) { child in
                        PageRow(note: child, onAddPage: onAddPage, onDelete: onDelete, onDuplicate: onDuplicate)
                    }
                } label: {
                    label
                }
            }
        }
        .tag(note.persistentModelID)
        .contextMenu {
            Button("Thêm trang con") { onAddPage(note) }
            Button("Nhân bản") { onDuplicate(note) }
            Divider()
            Button("Xóa", role: .destructive) { onDelete(note) }
        }
    }

    private var expansion: Binding<Bool> {
        Binding(get: { note.isExpanded }, set: { note.isExpanded = $0 })
    }

    private var label: some View {
        HStack(spacing: 6) {
            Text(note.icon)
            VStack(alignment: .leading, spacing: 1) {
                Text(note.displayTitle)
                    .lineLimit(1)
                if !note.tags.isEmpty {
                    Text(note.tags.map { "#\($0)" }.joined(separator: " "))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
    }
}
