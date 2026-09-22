import AppKit

/// Lightweight, language-agnostic syntax colouring for code blocks. Keywords
/// are the union of the languages IT learners meet most, so a block reads
/// well without asking which language it is.
enum CodeHighlighter {
    static let font = NSFont.monospacedSystemFont(ofSize: 12.5, weight: .regular)

    private static let keywords: Set<String> = [
        // Shared / C-family
        "if", "else", "for", "while", "do", "switch", "case", "default", "break", "continue", "return",
        "class", "struct", "enum", "interface", "protocol", "extension", "import", "package", "namespace",
        "public", "private", "protected", "internal", "static", "final", "abstract", "override", "virtual",
        "new", "delete", "this", "self", "super", "null", "nil", "none", "true", "false", "void",
        "int", "float", "double", "bool", "char", "string", "long", "short", "byte", "var", "let", "const",
        "try", "catch", "finally", "throw", "throws", "async", "await", "yield", "typedef", "template",
        // Swift / Kotlin / Rust / Go
        "func", "fun", "fn", "guard", "defer", "in", "is", "as", "where", "mut", "impl", "trait", "match",
        "some", "any", "init", "deinit", "lazy", "weak", "unowned", "inout", "typealias", "associatedtype",
        "go", "chan", "select", "map", "range", "type", "func", "pub", "use", "mod", "crate", "loop",
        // Python / Ruby / PHP
        "def", "elif", "except", "lambda", "pass", "raise", "with", "from", "global", "nonlocal", "not", "and", "or",
        "print", "end", "begin", "module", "require", "echo", "function", "foreach", "elseif",
        // JavaScript / TypeScript
        "export", "extends", "implements", "instanceof", "typeof", "undefined", "of", "readonly", "declare",
        // SQL
        "select", "insert", "update", "delete", "where", "join", "left", "right", "inner", "outer", "on",
        "group", "order", "by", "having", "limit", "create", "table", "drop", "alter", "primary", "key",
        "values", "into", "set", "distinct", "union", "exists", "between", "like",
        // Shell
        "then", "fi", "done", "esac", "exit", "export", "sudo", "cd", "ls", "mkdir", "rm", "cp", "mv",
    ]

    private static let keywordPattern = try! NSRegularExpression(
        pattern: "\\b(" + keywords.map(NSRegularExpression.escapedPattern).joined(separator: "|") + ")\\b",
        options: [.caseInsensitive]
    )
    private static let numberPattern = try! NSRegularExpression(pattern: "\\b\\d+(?:\\.\\d+)?\\b")
    private static let stringPattern = try! NSRegularExpression(
        pattern: "\"(?:\\\\.|[^\"\\\\\\n])*\"|'(?:\\\\.|[^'\\\\\\n])*'|`(?:\\\\.|[^`\\\\])*`"
    )
    private static let commentPattern = try! NSRegularExpression(
        pattern: "//[^\\n]*|#[^\\n]*|/\\*[\\s\\S]*?\\*/",
        options: []
    )
    private static let typePattern = try! NSRegularExpression(pattern: "\\b[A-Z][A-Za-z0-9_]{2,}\\b")

    static var keywordColor: NSColor { .systemPurple }
    static var stringColor: NSColor { .systemRed }
    static var numberColor: NSColor { .systemTeal }
    static var commentColor: NSColor { .systemGray }
    static var typeColor: NSColor { .systemBlue }

    /// Colours `range` of `storage`; callers wrap this in their own editing session.
    static func highlight(_ storage: NSTextStorage, range: NSRange) {
        guard range.length > 0, range.upperBound <= storage.length else { return }
        let string = storage.string as NSString
        storage.addAttribute(.foregroundColor, value: NSColor.textColor, range: range)

        func paint(_ pattern: NSRegularExpression, _ color: NSColor) {
            for match in pattern.matches(in: string as String, range: range) {
                storage.addAttribute(.foregroundColor, value: color, range: match.range)
            }
        }
        paint(typePattern, typeColor)
        paint(keywordPattern, keywordColor)
        paint(numberPattern, numberColor)
        paint(stringPattern, stringColor)
        paint(commentPattern, commentColor)
    }

    /// One block object shared by every paragraph of a code block, so the
    /// layout manager draws them as a single framed box.
    static func makeBlock() -> NSTextBlock {
        let block = NSTextBlock()
        block.setValue(100, type: .percentageValueType, for: .width)
        block.backgroundColor = NSColor.textColor.withAlphaComponent(0.06)
        block.setBorderColor(NSColor.separatorColor)
        block.setWidth(1, type: .absoluteValueType, for: .border)
        for edge in [NSRectEdge.minX, .maxX, .minY, .maxY] {
            block.setWidth(10, type: .absoluteValueType, for: .padding, edge: edge)
        }
        return block
    }

    static func paragraphStyle(sharing block: NSTextBlock) -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.textBlocks = [block]
        style.paragraphSpacing = 0
        style.paragraphSpacingBefore = 0
        style.lineSpacing = 2
        style.defaultTabInterval = 28
        style.tabStops = []
        return style
    }
}

extension NSTextBlock {
    /// Quote, callout and code frames come back from RTF as one-column
    /// tables; a real table has more than one column.
    var isDecoration: Bool {
        guard let cell = self as? NSTextTableBlock else { return true }
        return cell.table.numberOfColumns <= 1
    }
}
