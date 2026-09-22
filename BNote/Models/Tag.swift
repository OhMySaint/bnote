import Foundation
import SwiftData
import SwiftUI

enum HeaderAlignment: String, CaseIterable, Identifiable {
    case leading, center

    var id: String { rawValue }

    var label: String {
        switch self {
        case .leading: "Left"
        case .center: "Center"
        }
    }
}

enum TagColor: String, CaseIterable, Identifiable {
    case gray, red, orange, yellow, green, teal, blue, purple, pink

    var id: String { rawValue }

    var label: String {
        switch self {
        case .gray: "Gray"
        case .red: "Red"
        case .orange: "Cam"
        case .yellow: "Yellow"
        case .green: "Green"
        case .teal: "Teal"
        case .blue: "Blue"
        case .purple: "Purple"
        case .pink: "Pink"
        }
    }

    var color: Color {
        switch self {
        case .gray: .gray
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .teal: .teal
        case .blue: .blue
        case .purple: .purple
        case .pink: .pink
        }
    }
}

/// A named label with a colour. Notes reference tags by name so the tag list
/// stays a simple, editable catalogue.
@Model
final class Tag {
    @Attribute(.unique) var key: String
    var name: String
    var colorRaw: String = TagColor.gray.rawValue
    var note: String = ""
    var createdAt: Date = Date()

    init(name: String, color: TagColor = .gray) {
        self.name = name
        self.key = Tag.key(for: name)
        self.colorRaw = color.rawValue
        self.createdAt = Date()
    }

    var color: TagColor {
        get { TagColor(rawValue: colorRaw) ?? .gray }
        set { colorRaw = newValue.rawValue }
    }

    static func key(for name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

/// Keeps the tag catalogue in step with the strings stored on notes.
enum TagStore {
    @discardableResult
    static func ensure(_ name: String, in context: ModelContext) -> Tag? {
        let key = Tag.key(for: name)
        guard !key.isEmpty else { return nil }
        if let existing = fetch(key: key, in: context) { return existing }
        let tag = Tag(name: name.trimmingCharacters(in: .whitespacesAndNewlines))
        context.insert(tag)
        return tag
    }

    static func fetch(key: String, in context: ModelContext) -> Tag? {
        let descriptor = FetchDescriptor<Tag>(predicate: #Predicate { $0.key == key })
        return try? context.fetch(descriptor).first
    }

    static func rename(_ tag: Tag, to newName: String, notes: [Note]) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let oldKey = tag.key
        for note in notes {
            let updated = note.tags.map { Tag.key(for: $0) == oldKey ? trimmed : $0 }
            if updated != note.tags {
                note.tags = updated
                note.touch()
            }
        }
        tag.name = trimmed
        tag.key = Tag.key(for: trimmed)
    }

    static func delete(_ tag: Tag, notes: [Note], in context: ModelContext) {
        let key = tag.key
        for note in notes {
            let updated = note.tags.filter { Tag.key(for: $0) != key }
            if updated != note.tags {
                note.tags = updated
                note.touch()
            }
        }
        context.delete(tag)
    }

    static func usage(of tag: Tag, in notes: [Note]) -> Int {
        notes.filter { note in note.tags.contains { Tag.key(for: $0) == tag.key } }.count
    }
}
