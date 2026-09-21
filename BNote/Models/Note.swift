import Foundation
import SwiftData

@Model
final class Note {
    var title: String = ""
    var content: String = ""
    @Attribute(.externalStorage) var rtfData: Data?
    var tags: [String] = []
    var icon: String = "📄"
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var sortIndex: Int = 0
    var isExpanded: Bool = true
    var paperRaw: String = Paper.a4.rawValue
    var margin: Double = 72

    var parent: Note?
    @Relationship(deleteRule: .cascade, inverse: \Note.parent)
    var children: [Note]? = []

    init(title: String = "", parent: Note? = nil, sortIndex: Int = 0) {
        self.title = title
        self.parent = parent
        self.sortIndex = sortIndex
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
    }

    var pageConfig: PageConfig {
        get { PageConfig(paper: Paper(rawValue: paperRaw) ?? .a4, margin: margin) }
        set {
            paperRaw = newValue.paper.rawValue
            margin = newValue.margin
        }
    }

    var sortedChildren: [Note] {
        (children ?? []).sorted { ($0.sortIndex, $0.createdAt) < ($1.sortIndex, $1.createdAt) }
    }

    var childrenForOutline: [Note]? {
        let kids = sortedChildren
        return kids.isEmpty ? nil : kids
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let firstLine = content.split(separator: "\n").first.map(String.init) ?? ""
        return firstLine.isEmpty ? "Trang không tên" : firstLine
    }

    var snippet: String {
        content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
    }

    /// Note itself or any descendant matches the query.
    func matches(_ query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return true }
        if title.lowercased().contains(q)
            || content.lowercased().contains(q)
            || tags.contains(where: { $0.lowercased().contains(q) }) {
            return true
        }
        return sortedChildren.contains { $0.matches(q) }
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
