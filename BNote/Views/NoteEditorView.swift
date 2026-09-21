import SwiftData
import SwiftUI

struct NoteEditorView: View {
    @Bindable var note: Note
    @ObservedObject var controller: DocumentController
    @Binding var showOutline: Bool

    @State private var tagsText = ""

    private static let icons = ["📄", "📝", "📘", "🗒️", "📊", "🧩", "🚀", "💡", "🗓️", "✅", "🔖", "🧪"]

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            FormatToolbar(controller: controller)
            Divider()
            HStack(spacing: 0) {
                PagedEditor(controller: controller)
                if showOutline {
                    Divider()
                    OutlinePanel(controller: controller)
                }
            }
            Divider()
            statusBar
        }
        .toolbar {
            ToolbarItem {
                Button {
                    showOutline.toggle()
                } label: {
                    Label("Mục lục", systemImage: "list.bullet.indent")
                }
                .help("Ẩn/hiện mục lục (⌃⌘O)")
            }
        }
        .task(id: note.persistentModelID) {
            tagsText = note.tags.joined(separator: ", ")
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Menu {
                ForEach(Self.icons, id: \.self) { icon in
                    Button(icon) { note.icon = icon }
                }
            } label: {
                Text(note.icon).font(.title3)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()

            TextField("Tên trang", text: $note.title)
                .textFieldStyle(.plain)
                .font(.title3.weight(.semibold))
                .onChange(of: note.title) { _, _ in note.touch() }

            HStack(spacing: 4) {
                Image(systemName: "tag")
                    .foregroundStyle(.secondary)
                TextField("Thẻ, cách nhau bằng dấu phẩy", text: $tagsText)
                    .textFieldStyle(.plain)
                    .frame(width: 200)
                    .onSubmit(commitTags)
            }
            .font(.callout)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var statusBar: some View {
        HStack(spacing: 14) {
            Label("\(controller.pageCount) trang", systemImage: "doc.on.doc")
            Label("\(controller.wordCount) từ", systemImage: "textformat.abc")
            Text("\(controller.characterCount) ký tự")
            Spacer()
            Text("Sửa lần cuối \(note.updatedAt.formatted(date: .abbreviated, time: .shortened))")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 5)
    }

    private func commitTags() {
        let parsed = Note.parseTags(tagsText)
        guard parsed != note.tags else { return }
        note.tags = parsed
        note.touch()
    }
}
