import AppKit

/// Paragraph-level presets, like the style dropdown in Google Docs.
enum TextStyle: String, CaseIterable, Identifiable {
    case title, heading1, heading2, heading3, body, caption, code

    var id: String { rawValue }

    var label: String {
        switch self {
        case .title: "Title"
        case .heading1: "Heading 1"
        case .heading2: "Heading 2"
        case .heading3: "Heading 3"
        case .body: "Text"
        case .caption: "Callout"
        case .code: "Code"
        }
    }

    /// Notion's scale: 16 px body, 30 / 24 / 20 headings, 40 for the title.
    var fontSize: CGFloat {
        switch self {
        case .title: 40
        case .heading1: 30
        case .heading2: 24
        case .heading3: 20
        case .body: 16
        case .caption: 14
        case .code: 14.5
        }
    }

    var isBold: Bool {
        switch self {
        case .title, .heading1, .heading2, .heading3: true
        default: false
        }
    }

    /// 0 means "not a heading"; 1...3 feed the document outline.
    var headerLevel: Int {
        switch self {
        case .title, .heading1: 1
        case .heading2: 2
        case .heading3: 3
        default: 0
        }
    }

    var spacingBefore: CGFloat {
        switch self {
        case .title: 14
        case .heading1: 12
        case .heading2: 10
        case .heading3: 8
        default: 0
        }
    }

    var spacingAfter: CGFloat {
        switch self {
        case .title, .heading1, .heading2, .heading3: 6
        case .code: 4
        default: 4
        }
    }

    var isMonospaced: Bool { self == .code }

    /// RTF drops custom attributes, so a style is recovered from font size + weight.
    static func detect(font: NSFont?, paragraph: NSParagraphStyle?) -> TextStyle {
        if let level = paragraph?.headerLevel, level > 0 {
            switch level {
            case 1: return .heading1
            case 2: return .heading2
            default: return .heading3
            }
        }
        guard let font else { return .body }
        let bold = NSFontManager.shared.traits(of: font).contains(.boldFontMask)
        let size = font.pointSize
        if font.isFixedPitch && size <= 16 { return .code }
        if bold {
            if size >= 36 { return .title }
            if size >= 27 { return .heading1 }
            if size >= 22 { return .heading2 }
            if size >= 18 { return .heading3 }
        }
        if size <= 14.5 { return .caption }
        return .body
    }
}

enum ListKind {
    case none, bullet, numbered, todo, toggle

    /// Bullet glyph per nesting level, cycling like Notion / Word.
    static let bulletGlyphs: [Character] = ["•", "◦", "▪"]

    static func bulletGlyph(level: Int) -> Character {
        bulletGlyphs[max(0, level) % bulletGlyphs.count]
    }

    var marker: String { marker(level: 0) }

    func marker(level: Int) -> String {
        switch self {
        case .none: ""
        case .bullet: "\(ListKind.bulletGlyph(level: level))\t"
        case .numbered: "1.\t"
        case .todo: "☐\t"
        case .toggle: "\(ToggleMarker.expanded)\t"
        }
    }
}

enum Checkbox {
    static let unchecked: Character = "☐"
    static let checked: Character = "☑"
}

enum EditorDefaults {
    static let fontFamily = "Helvetica Neue"
    static let fontSize: CGFloat = 16
    static let listIndent: CGFloat = 26
    static let tabIndent: CGFloat = 28
    /// Notion reads at about 1.5. Added as space *below* each line rather than
    /// as `lineHeightMultiple`: a multiple inflates the line box and drops the
    /// glyphs to its bottom, so the text sits lower than the caret drawn beside it.
    static let lineHeightRatio: CGFloat = 1.5

    static func lineSpacing(for fontSize: CGFloat) -> CGFloat {
        ((lineHeightRatio - 1.15) * fontSize).rounded()
    }

    static var bodyFont: NSFont {
        NSFont(name: fontFamily, size: fontSize) ?? .systemFont(ofSize: fontSize)
    }

    static var bodyAttributes: [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing(for: fontSize)
        paragraph.paragraphSpacing = TextStyle.body.spacingAfter
        return [
            .font: bodyFont,
            .foregroundColor: NSColor.textColor,
            .paragraphStyle: paragraph,
        ]
    }
}

/// A heading found in the document, used by the outline panel.
struct OutlineItem: Identifiable, Equatable {
    let id: Int
    let text: String
    let level: Int
    let location: Int
}
