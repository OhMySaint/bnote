import Foundation
import SwiftData

@Model
final class Note {
    /// Stable identity for internal links (bnote://page/<uid>).
    var uid: UUID = UUID()
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
    var orientationRaw: String = PageOrientation.portrait.rawValue
    var marginTop: Double = 54
    var marginBottom: Double = 54
    var marginLeft: Double = 54
    var marginRight: Double = 54

    // Cover & header
    @Attribute(.externalStorage) var coverData: Data?
    var coverStyle: String = ""
    var coverHeight: Double = 200
    /// Vertical focus of the cover picture, 0 = top edge, 1 = bottom edge.
    var coverOffset: Double = 0.5
    var headerAlignmentRaw: String = HeaderAlignment.leading.rawValue
    var subtitle: String = ""
    var showIcon: Bool = true
    // Layout (per page, like Notion)
    var fullWidth: Bool = false
    /// No longer offered; kept so existing stores open without a migration.
    var smallText: Bool = false

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
        get {
            PageConfig(
                paper: Paper(rawValue: paperRaw) ?? .a4,
                orientation: PageOrientation(rawValue: orientationRaw) ?? .portrait,
                margins: PageMargins(
                    top: marginTop,
                    bottom: marginBottom,
                    left: marginLeft,
                    right: marginRight
                )
            )
        }
        set {
            paperRaw = newValue.paper.rawValue
            orientationRaw = newValue.orientation.rawValue
            marginTop = newValue.margins.top
            marginBottom = newValue.margins.bottom
            marginLeft = newValue.margins.left
            marginRight = newValue.margins.right
        }
    }

    var headerAlignment: HeaderAlignment {
        get { HeaderAlignment(rawValue: headerAlignmentRaw) ?? .leading }
        set { headerAlignmentRaw = newValue.rawValue }
    }

    var hasCover: Bool { coverData != nil || !coverStyle.isEmpty }

    var linkURL: URL { URL(string: "bnote://page/\(uid.uuidString)")! }

    /// Every page below this one, depth first.
    var descendants: [Note] {
        sortedChildren.flatMap { [$0] + $0.descendants }
    }

    var depth: Int {
        var level = 0
        var current = parent
        while let node = current {
            level += 1
            current = node.parent
        }
        return level
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
