import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Note.updatedAt, order: .reverse) private var notes: [Note]

    @State private var selectedID: PersistentIdentifier?
    @State private var search = ""
    @State private var activeTag: String?

    private var allTags: [String] {
        var seen = Set<String>()
        return notes.flatMap(\.tags).filter { seen.insert($0.lowercased()).inserted }.sorted()
    }

    private var visibleNotes: [Note] {
        notes.filter { note in
            note.matches(search)
                && (activeTag == nil || note.tags.contains { $0.caseInsensitiveCompare(activeTag!) == .orderedSame })
        }
    }

    private var selectedNote: Note? {
        notes.first { $0.persistentModelID == selectedID }
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            if let note = selectedNote {
                NoteEditorView(note: note)
                    .id(note.persistentModelID)
            } else {
                ContentUnavailableView(
                    "Chưa chọn ghi chú",
                    systemImage: "note.text",
                    description: Text("Chọn một ghi chú bên trái hoặc nhấn ⌘N để tạo mới.")
                )
            }
        }
        .navigationTitle("BNote")
        .onReceive(NotificationCenter.default.publisher(for: .newNoteRequested)) { _ in
            createNote()
        }
    }

    private var sidebar: some View {
        List(selection: $selectedID) {
            if !allTags.isEmpty {
                Section("Thẻ") {
                    tagFilter
                }
            }
            Section("Ghi chú") {
                ForEach(visibleNotes) { note in
                    NoteRow(note: note)
                        .tag(note.persistentModelID)
                        .contextMenu {
                            Button("Xóa", role: .destructive) { delete(note) }
                        }
                }
            }
        }
        .searchable(text: $search, placement: .sidebar, prompt: "Tìm ghi chú")
        .navigationSplitViewColumnWidth(min: 240, ideal: 280)
        .toolbar {
            ToolbarItem {
                Button(action: createNote) {
                    Label("Ghi chú mới", systemImage: "square.and.pencil")
                }
                .help("Tạo ghi chú mới (⌘N)")
            }
            ToolbarItem {
                Button(role: .destructive) {
                    if let note = selectedNote { delete(note) }
                } label: {
                    Label("Xóa", systemImage: "trash")
                }
                .disabled(selectedNote == nil)
                .help("Xóa ghi chú đang chọn")
            }
        }
        .overlay {
            if visibleNotes.isEmpty {
                ContentUnavailableView(
                    notes.isEmpty ? "Chưa có ghi chú" : "Không tìm thấy",
                    systemImage: notes.isEmpty ? "tray" : "magnifyingglass"
                )
            }
        }
    }

    private var tagFilter: some View {
        ForEach(allTags, id: \.self) { tag in
            HStack {
                Image(systemName: activeTag == tag ? "tag.fill" : "tag")
                Text(tag)
                Spacer()
            }
            .contentShape(.rect)
            .foregroundStyle(activeTag == tag ? Color.accentColor : .primary)
            .onTapGesture {
                activeTag = activeTag == tag ? nil : tag
            }
        }
    }

    private func createNote() {
        let note = Note()
        context.insert(note)
        try? context.save()
        activeTag = nil
        search = ""
        selectedID = note.persistentModelID
    }

    private func delete(_ note: Note) {
        if selectedID == note.persistentModelID { selectedID = nil }
        context.delete(note)
        try? context.save()
    }
}

private struct NoteRow: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(note.displayTitle)
                .font(.headline)
                .lineLimit(1)
            HStack(spacing: 6) {
                Text(note.updatedAt, format: .dateTime.day().month().hour().minute())
                    .foregroundStyle(.secondary)
                if !note.snippet.isEmpty {
                    Text(note.snippet)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .font(.caption)
            if !note.tags.isEmpty {
                Text(note.tags.map { "#\($0)" }.joined(separator: " "))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Note.self, inMemory: true)
}
