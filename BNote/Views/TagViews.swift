import SwiftData
import SwiftUI

/// Coloured pill for one tag name; colour comes from the tag catalogue.
struct TagChip: View {
    let name: String
    let color: TagColor
    var compact = false
    var onRemove: (() -> Void)?

    var body: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(color.color)
                .frame(width: 6, height: 6)
            Text(name)
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .font(compact ? .caption2 : .caption)
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, compact ? 2 : 4)
        .background(color.color.opacity(0.14), in: .capsule)
    }
}

extension Array where Element == Tag {
    func color(for name: String) -> TagColor {
        let key = Tag.key(for: name)
        return first { $0.key == key }?.color ?? .gray
    }
}

/// Sheet for curating the tag catalogue: rename, recolour, delete, merge by renaming.
struct TagManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Tag.name) private var tags: [Tag]
    @Query private var notes: [Note]

    @State private var newTag = ""
    @State private var renaming: Tag?
    @State private var renameText = ""
    @State private var pendingDelete: Tag?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Hệ thống thẻ")
                    .font(.title3.weight(.semibold))
                Spacer()
                Text("\(tags.count) thẻ")
                    .foregroundStyle(.secondary)
            }
            .padding(16)

            Divider()

            if tags.isEmpty {
                ContentUnavailableView(
                    "Chưa có thẻ",
                    systemImage: "tag",
                    description: Text("Thêm thẻ ở đây hoặc ngay trên đầu mỗi trang.")
                )
            } else {
                List {
                    ForEach(tags) { tag in
                        row(tag)
                    }
                }
                .listStyle(.inset)
            }

            Divider()

            HStack(spacing: 8) {
                TextField("Thẻ mới…", text: $newTag)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addTag)
                Button("Thêm", action: addTag)
                    .disabled(Tag.key(for: newTag).isEmpty)
                Spacer()
                Button("Xong") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(12)
        }
        .frame(width: 460, height: 420)
        .confirmationDialog(
            "Xóa thẻ “\(pendingDelete?.name ?? "")”?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
        ) {
            Button("Xóa và gỡ khỏi \(pendingDelete.map { TagStore.usage(of: $0, in: notes) } ?? 0) trang", role: .destructive) {
                if let tag = pendingDelete { TagStore.delete(tag, notes: notes, in: context) }
                pendingDelete = nil
            }
            Button("Hủy", role: .cancel) { pendingDelete = nil }
        }
    }

    private func row(_ tag: Tag) -> some View {
        HStack(spacing: 10) {
            Menu {
                ForEach(TagColor.allCases) { color in
                    Button {
                        tag.color = color
                    } label: {
                        Label(color.label, systemImage: tag.color == color ? "checkmark.circle.fill" : "circle.fill")
                    }
                }
            } label: {
                Circle()
                    .fill(tag.color.color)
                    .frame(width: 14, height: 14)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Đổi màu")

            if renaming?.persistentModelID == tag.persistentModelID {
                TextField("Tên thẻ", text: $renameText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { commitRename(tag) }
                Button("Lưu") { commitRename(tag) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                Button("Hủy") { renaming = nil }
                    .controlSize(.small)
            } else {
                Text(tag.name)
                Spacer()
                Text("\(TagStore.usage(of: tag, in: notes)) trang")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    renaming = tag
                    renameText = tag.name
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .help("Đổi tên (gộp nếu trùng tên thẻ khác)")
                Button {
                    pendingDelete = tag
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Xóa thẻ")
            }
        }
        .padding(.vertical, 2)
    }

    private func addTag() {
        TagStore.ensure(newTag, in: context)
        newTag = ""
    }

    private func commitRename(_ tag: Tag) {
        let newKey = Tag.key(for: renameText)
        if let other = tags.first(where: { $0.key == newKey && $0.persistentModelID != tag.persistentModelID }) {
            // Same name as another tag: merge into it.
            TagStore.rename(tag, to: other.name, notes: notes)
            context.delete(tag)
        } else {
            TagStore.rename(tag, to: renameText, notes: notes)
        }
        renaming = nil
    }
}
