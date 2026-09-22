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
                Text("Tags")
                    .font(.title3.weight(.semibold))
                Spacer()
                Text("\(tags.count) tags")
                    .foregroundStyle(.secondary)
            }
            .padding(16)

            Divider()

            if tags.isEmpty {
                ContentUnavailableView(
                    "No tags yet",
                    systemImage: "tag",
                    description: Text("Add tags here, or at the top of any page.")
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
                TextField("New tag…", text: $newTag)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addTag)
                Button("Add", action: addTag)
                    .disabled(Tag.key(for: newTag).isEmpty)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(12)
        }
        .frame(width: 460, height: 420)
        .confirmationDialog(
            "Delete the tag “\(pendingDelete?.name ?? "")”?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
        ) {
            Button("Delete and remove from \(pendingDelete.map { TagStore.usage(of: $0, in: notes) } ?? 0) pages", role: .destructive) {
                if let tag = pendingDelete { TagStore.delete(tag, notes: notes, in: context) }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
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
            .help("Change color")

            if renaming?.persistentModelID == tag.persistentModelID {
                TextField("Tag name", text: $renameText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { commitRename(tag) }
                Button("Save") { commitRename(tag) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                Button("Cancel") { renaming = nil }
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
                .help("Rename (merges into an existing tag)")
                Button {
                    pendingDelete = tag
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Delete tag")
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
