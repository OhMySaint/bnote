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
            id: "text", title: "Văn bản", subtitle: "Đoạn văn thường",
            symbol: "text.alignleft", section: "Cơ bản", keywords: ["van ban", "text", "paragraph", "doan"]
        ) { $0.apply(style: .body) },
        SlashCommand(
            id: "h1", title: "Đầu mục 1", subtitle: "Tiêu đề mục lớn",
            symbol: "textformat.size.larger", section: "Cơ bản", keywords: ["dau muc", "heading", "h1", "tieu de"]
        ) { $0.apply(style: .heading1) },
        SlashCommand(
            id: "h2", title: "Đầu mục 2", subtitle: "Tiêu đề mục vừa",
            symbol: "textformat.size", section: "Cơ bản", keywords: ["dau muc", "heading", "h2"]
        ) { $0.apply(style: .heading2) },
        SlashCommand(
            id: "h3", title: "Đầu mục 3", subtitle: "Tiêu đề mục nhỏ",
            symbol: "textformat.size.smaller", section: "Cơ bản", keywords: ["dau muc", "heading", "h3"]
        ) { $0.apply(style: .heading3) },
        SlashCommand(
            id: "title", title: "Tiêu đề lớn", subtitle: "Tên tài liệu",
            symbol: "textformat", section: "Cơ bản", keywords: ["tieu de", "title"]
        ) { $0.apply(style: .title) },
        SlashCommand(
            id: "bullet", title: "Danh sách chấm", subtitle: "Gạch đầu dòng",
            symbol: "list.bullet", section: "Danh sách", keywords: ["danh sach", "bullet", "list", "cham"]
        ) { $0.toggleList(.bullet) },
        SlashCommand(
            id: "numbered", title: "Danh sách số", subtitle: "Đánh số 1, 2, 3",
            symbol: "list.number", section: "Danh sách", keywords: ["danh sach", "so", "numbered", "ordered"]
        ) { $0.toggleList(.numbered) },
        SlashCommand(
            id: "todo", title: "Việc cần làm", subtitle: "Ô đánh dấu, bấm để hoàn thành",
            symbol: "checklist", section: "Danh sách", keywords: ["viec can lam", "todo", "checkbox", "task", "cong viec"]
        ) { $0.toggleList(.todo) },
        SlashCommand(
            id: "quote", title: "Trích dẫn", subtitle: "Đoạn có vạch dọc bên trái",
            symbol: "text.quote", section: "Khối", keywords: ["trich dan", "quote", "blockquote"]
        ) { $0.insertQuote() },
        SlashCommand(
            id: "callout", title: "Ghi chú nổi bật", subtitle: "Khối nền màu kèm biểu tượng",
            symbol: "lightbulb", section: "Khối", keywords: ["ghi chu", "callout", "noi bat", "note"]
        ) { $0.insertCallout() },
        SlashCommand(
            id: "code", title: "Khối mã", subtitle: "Khung mã có tô màu cú pháp",
            symbol: "chevron.left.forwardslash.chevron.right", section: "Khối", keywords: ["ma", "code", "block"]
        ) { $0.apply(style: .code) },
        SlashCommand(
            id: "inlinecode", title: "Mã nội dòng", subtitle: "Chữ đều nét cho tên hàm, lệnh",
            symbol: "curlybraces", section: "Khối", keywords: ["ma", "code", "inline", "noi dong"]
        ) { $0.toggleInlineCode() },
        SlashCommand(
            id: "divider", title: "Đường kẻ ngang", subtitle: "Ngăn cách hai phần",
            symbol: "minus", section: "Khối", keywords: ["duong ke", "divider", "line", "ngan cach"]
        ) { $0.insertDivider() },
        SlashCommand(
            id: "table", title: "Bảng 3×3", subtitle: "Bảng có viền, gõ trực tiếp trong ô",
            symbol: "tablecells", section: "Khối", keywords: ["bang", "table", "grid"]
        ) { $0.insertTable(rows: 3, columns: 3) },
        SlashCommand(
            id: "subpage", title: "Trang con", subtitle: "Tạo trang con và chèn liên kết tới nó",
            symbol: "doc.badge.plus", section: "Chèn", keywords: ["trang con", "page", "subpage", "chuong", "chương"]
        ) { $0.createLinkedSubpage() },
        SlashCommand(
            id: "image", title: "Ảnh", subtitle: "Chèn ảnh từ máy",
            symbol: "photo", section: "Chèn", keywords: ["anh", "image", "photo", "hinh"]
        ) { $0.insertImageFromPanel() },
        SlashCommand(
            id: "link", title: "Liên kết", subtitle: "Gắn địa chỉ vào chữ đang chọn",
            symbol: "link", section: "Chèn", keywords: ["lien ket", "link", "url"]
        ) { $0.insertLinkFromPanel() },
        SlashCommand(
            id: "date", title: "Ngày hôm nay", subtitle: "Chèn ngày hiện tại",
            symbol: "calendar", section: "Chèn", keywords: ["ngay", "date", "hom nay", "today"]
        ) { $0.insertToday() },
        SlashCommand(
            id: "pagebreak", title: "Ngắt trang", subtitle: "Bắt đầu một trang mới",
            symbol: "arrow.down.to.line", section: "Chèn", keywords: ["ngat trang", "page break", "trang moi"]
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
