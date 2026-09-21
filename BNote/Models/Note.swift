import Foundation
import SwiftData

@Model
final class Note {
    var title: String
    var content: String
    var tags: [String]
    var createdAt: Date
    var updatedAt: Date

    init(title: String = "", content: String = "", tags: [String] = []) {
        self.title = title
        self.content = content
        self.tags = tags
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let firstLine = content.split(separator: "\n").first.map(String.init) ?? ""
        return firstLine.isEmpty ? "Ghi chú mới" : firstLine
    }

    var snippet: String {
        content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
    }

    func matches(_ query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return true }
        return title.lowercased().contains(q)
            || content.lowercased().contains(q)
            || tags.contains { $0.lowercased().contains(q) }
    }

    func touch() {
        updatedAt = Date()
    }

    static func parseTags(_ raw: String) -> [String] {
        var seen = Set<String>()
        return raw
            .split(whereSeparator: { $0 == "," || $0 == "\n" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
    }
}
