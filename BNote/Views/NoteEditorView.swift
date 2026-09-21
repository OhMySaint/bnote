import SwiftData
import SwiftUI

struct NoteEditorView: View {
    @Bindable var note: Note
    @Environment(\.modelContext) private var context

    @State private var tagsText = ""
    @FocusState private var titleFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Tiêu đề", text: $note.title)
                .textFieldStyle(.plain)
                .font(.title2.weight(.semibold))
                .focused($titleFocused)
                .padding(.horizontal, 20)
                .padding(.top, 16)

            HStack(spacing: 6) {
                Image(systemName: "tag")
                    .foregroundStyle(.secondary)
                TextField("Thẻ, cách nhau bằng dấu phẩy", text: $tagsText)
                    .textFieldStyle(.plain)
                    .onSubmit(commitTags)
            }
            .font(.callout)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)

            Divider()

            TextEditor(text: $note.content)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 16)
                .padding(.top, 8)
        }
        .safeAreaInset(edge: .bottom) {
            Text("Sửa lần cuối \(note.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
        }
        .task {
            tagsText = note.tags.joined(separator: ", ")
            titleFocused = note.title.isEmpty && note.content.isEmpty
        }
        .onChange(of: note.title) { note.touch() }
        .onChange(of: note.content) { note.touch() }
        .onDisappear(perform: commitTags)
    }

    private func commitTags() {
        let parsed = Note.parseTags(tagsText)
        guard parsed != note.tags else { return }
        note.tags = parsed
        note.touch()
        try? context.save()
    }
}
