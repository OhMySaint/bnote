import SwiftData
import SwiftUI

/// Nested page tree, the way Notion organises documents.
struct SidebarView: View {
    let roots: [Note]
    let allTags: [String]
    let totalPages: Int
    @Binding var selection: PersistentIdentifier?
    @Binding var search: String
    @Binding var activeTag: String?

    var onAddPage: (Note?) -> Void
    var onDelete: (Note) -> Void
    var onDuplicate: (Note) -> Void

    var body: some View {
        VStack(spacing: 0) {
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
                                if activeTag == tag {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.tertiary)
                                }
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
            .overlay {
                if roots.isEmpty {
                    if search.isEmpty && activeTag == nil {
                        ContentUnavailableView {
                            Label("Chưa có trang", systemImage: "doc.text")
                        } description: {
                            Text("Mỗi trang là một tài liệu, có thể lồng trang con bên trong.")
                        } actions: {
                            Button("Tạo trang đầu tiên") { onAddPage(nil) }
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
        .searchable(text: $search, placement: .sidebar, prompt: "Tìm trong mọi trang")
        .navigationSplitViewColumnWidth(min: 220, ideal: 260)
    }

    private var footer: some View {
        HStack {
            Button {
                onAddPage(nil)
            } label: {
                Label("Trang mới", systemImage: "plus")
                    .font(.callout)
            }
            .buttonStyle(.borderless)
            .help("Trang mới (⌘N)")
            Spacer()
            Text("\(totalPages) trang")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

private struct PageRow: View {
    let note: Note
    var onAddPage: (Note?) -> Void
    var onDelete: (Note) -> Void
    var onDuplicate: (Note) -> Void

    @State private var hovering = false

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
        HStack(spacing: 7) {
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
            Spacer(minLength: 4)
            if hovering {
                Button {
                    onAddPage(note)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .semibold))
                        .frame(width: 18, height: 18)
                        .background(Color.primary.opacity(0.08), in: .rect(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .help("Thêm trang con")
            }
        }
        .padding(.vertical, 1)
        .contentShape(.rect)
        .onHover { hovering = $0 }
    }
}
