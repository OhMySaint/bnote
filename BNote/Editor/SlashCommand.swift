import AppKit

/// One entry in the "/" block menu.
struct SlashCommand: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let section: String
    let keywords: [String]
    let perform: (DocumentController) -> Void
}

enum SlashCatalog {
    static let all: [SlashCommand] = [
        SlashCommand(
            id: "text", title: "Text", subtitle: "Plain paragraph",
            symbol: "text.alignleft", section: "Basic", keywords: ["van ban", "text", "paragraph", "doan"]
        ) { $0.apply(style: .body) },
        SlashCommand(
            id: "h1", title: "Heading 1", subtitle: "Big section heading",
            symbol: "textformat.size.larger", section: "Basic", keywords: ["dau muc", "heading", "h1", "tieu de"]
        ) { $0.apply(style: .heading1) },
        SlashCommand(
            id: "h2", title: "Heading 2", subtitle: "Medium section heading",
            symbol: "textformat.size", section: "Basic", keywords: ["dau muc", "heading", "h2"]
        ) { $0.apply(style: .heading2) },
        SlashCommand(
            id: "h3", title: "Heading 3", subtitle: "Small section heading",
            symbol: "textformat.size.smaller", section: "Basic", keywords: ["dau muc", "heading", "h3"]
        ) { $0.apply(style: .heading3) },
        SlashCommand(
            id: "title", title: "Title", subtitle: "Document name",
            symbol: "textformat", section: "Basic", keywords: ["tieu de", "title"]
        ) { $0.apply(style: .title) },
        SlashCommand(
            id: "bullet", title: "Bulleted list", subtitle: "A dot in front of every item",
            symbol: "list.bullet", section: "Lists", keywords: ["danh sach", "bullet", "list", "cham"]
        ) { $0.toggleList(.bullet) },
        SlashCommand(
            id: "numbered", title: "Numbered list", subtitle: "Numbered 1, 2, 3",
            symbol: "list.number", section: "Lists", keywords: ["danh sach", "so", "numbered", "ordered"]
        ) { $0.toggleList(.numbered) },
        SlashCommand(
            id: "todo", title: "To-do list", subtitle: "A checkbox you click to complete",
            symbol: "checklist", section: "Lists", keywords: ["viec can lam", "todo", "checkbox", "task", "cong viec"]
        ) { $0.toggleList(.todo) },
        SlashCommand(
            id: "quote", title: "Quote", subtitle: "A paragraph with a rule down its left side",
            symbol: "text.quote", section: "Blocks", keywords: ["trich dan", "quote", "blockquote"]
        ) { $0.insertQuote() },
        SlashCommand(
            id: "callout", title: "A note that stands out", subtitle: "A tinted block with an icon",
            symbol: "lightbulb", section: "Blocks", keywords: ["ghi chu", "callout", "noi bat", "note"]
        ) { $0.insertCallout() },
        SlashCommand(
            id: "code", title: "Code block", subtitle: "A code frame with syntax colours",
            symbol: "chevron.left.forwardslash.chevron.right", section: "Blocks", keywords: ["ma", "code", "block"]
        ) { $0.apply(style: .code) },
        SlashCommand(
            id: "inlinecode", title: "Inline code", subtitle: "Monospaced text for names and commands",
            symbol: "curlybraces", section: "Blocks", keywords: ["ma", "code", "inline", "noi dong"]
        ) { $0.toggleInlineCode() },
        SlashCommand(
            id: "divider", title: "Divider", subtitle: "Separates two sections",
            symbol: "minus", section: "Blocks", keywords: ["duong ke", "divider", "line", "ngan cach"]
        ) { $0.insertDivider() },
        SlashCommand(
            id: "table", title: "3×3 table", subtitle: "A bordered grid you type straight into",
            symbol: "tablecells", section: "Blocks", keywords: ["bang", "table", "grid"]
        ) { $0.insertTable(rows: 3, columns: 3) },
        SlashCommand(
            id: "subpage", title: "Subpage", subtitle: "Create a subpage and link to it",
            symbol: "doc.badge.plus", section: "Insert", keywords: ["trang con", "page", "subpage", "chuong", "chapter"]
        ) { $0.createLinkedSubpage() },
        SlashCommand(
            id: "image", title: "Picture", subtitle: "Insert a picture from your Mac",
            symbol: "photo", section: "Insert", keywords: ["anh", "image", "photo", "hinh"]
        ) { $0.insertImageFromPanel() },
        SlashCommand(
            id: "link", title: "Link", subtitle: "Attach a URL to the selected text",
            symbol: "link", section: "Insert", keywords: ["lien ket", "link", "url"]
        ) { $0.insertLinkFromPanel() },
        SlashCommand(
            id: "date", title: "Today", subtitle: "Insert today’s date",
            symbol: "calendar", section: "Insert", keywords: ["ngay", "date", "hom nay", "today"]
        ) { $0.insertToday() },
        SlashCommand(
            id: "pagebreak", title: "Page break", subtitle: "Start a new page",
            symbol: "arrow.down.to.line", section: "Insert", keywords: ["ngat trang", "page break", "trang moi"]
        ) { $0.insertPageBreak() },
    ]

    static func filter(query: String) -> [SlashCommand] {
        let needle = fold(query)
        guard !needle.isEmpty else { return all }
        return all.filter { command in
            fold(command.title).contains(needle)
                || command.keywords.contains { fold($0).contains(needle) }
        }
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "vi"))
            .trimmingCharacters(in: .whitespaces)
    }
}

final class SlashMenuModel: ObservableObject {
    @Published var commands: [SlashCommand] = []
    @Published var selection = 0
    @Published var query = ""
    var onPick: ((SlashCommand) -> Void)?
}
