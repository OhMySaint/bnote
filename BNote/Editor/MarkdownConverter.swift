import AppKit

/// Markdown is lossy both ways; this covers headings, lists, and inline
/// bold / italic / code, which is what round-trips usefully.
enum MarkdownConverter {
    // MARK: - Export

    static func markdown(from attributed: NSAttributedString) -> String {
        let string = attributed.string as NSString
        guard string.length > 0 else { return "" }

        var lines: [String] = []
        var location = 0
        while location < string.length {
            let paragraph = string.paragraphRange(for: NSRange(location: location, length: 0))
            location = paragraph.upperBound

            let raw = string.substring(with: paragraph).trimmingCharacters(in: .newlines)
            if raw.trimmingCharacters(in: .whitespaces).isEmpty {
                lines.append("")
                continue
            }

            let font = attributed.attribute(.font, at: paragraph.location, effectiveRange: nil) as? NSFont
            let style = attributed.attribute(.paragraphStyle, at: paragraph.location, effectiveRange: nil) as? NSParagraphStyle
            let textStyle = TextStyle.detect(font: font, paragraph: style)

            var contentRange = paragraph
            var prefix = ""
            if raw.hasPrefix("•\t") {
                prefix = "- "
                contentRange = NSRange(location: paragraph.location + 2, length: max(0, paragraph.length - 2))
            } else if let dot = raw.firstIndex(of: "."), raw[raw.startIndex..<dot].allSatisfy(\.isNumber),
                      raw.index(after: dot) < raw.endIndex, raw[raw.index(after: dot)] == "\t" {
                let markerLength = raw.distance(from: raw.startIndex, to: dot) + 2
                prefix = String(raw[raw.startIndex..<dot]) + ". "
                contentRange = NSRange(location: paragraph.location + markerLength, length: max(0, paragraph.length - markerLength))
            } else if textStyle.headerLevel > 0 {
                prefix = String(repeating: "#", count: textStyle.headerLevel) + " "
            } else if textStyle == .code {
                prefix = "    "
            }

            lines.append(prefix + inlineMarkdown(from: attributed, range: contentRange))
        }

        return lines.joined(separator: "\n")
    }

    private static func inlineMarkdown(from attributed: NSAttributedString, range: NSRange) -> String {
        let safe = NSRange(
            location: min(range.location, attributed.length),
            length: max(0, min(range.length, attributed.length - min(range.location, attributed.length)))
        )
        guard safe.length > 0 else { return "" }

        var output = ""
        attributed.enumerateAttributes(in: safe) { attributes, subrange, _ in
            var text = (attributed.string as NSString).substring(with: subrange)
            text = text.trimmingCharacters(in: .newlines)
            guard !text.isEmpty else { return }

            let font = attributes[.font] as? NSFont
            let traits = font.map { NSFontManager.shared.traits(of: $0) } ?? []
            let bold = traits.contains(.boldFontMask)
            let italic = traits.contains(.italicFontMask)
            let mono = font?.isFixedPitch ?? false
            let heading = TextStyle.detect(font: font, paragraph: attributes[.paragraphStyle] as? NSParagraphStyle).headerLevel > 0

            if mono {
                text = "`\(text)`"
            } else if bold && italic {
                text = "***\(text)***"
            } else if bold && !heading {
                text = "**\(text)**"
            } else if italic {
                text = "*\(text)*"
            }

            if let url = attributes[.link] as? URL {
                text = "[\(text)](\(url.absoluteString))"
            }
            output += text
        }
        return output
    }

    // MARK: - Import

    static func attributedString(fromMarkdown markdown: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        var inCodeBlock = false

        for line in markdown.components(separatedBy: .newlines) {
            if line.hasPrefix("```") {
                inCodeBlock.toggle()
                continue
            }

            var text = line
            var style = TextStyle.body
            var listPrefix = ""

            if inCodeBlock {
                style = .code
            } else if text.hasPrefix("### ") {
                style = .heading3
                text = String(text.dropFirst(4))
            } else if text.hasPrefix("## ") {
                style = .heading2
                text = String(text.dropFirst(3))
            } else if text.hasPrefix("# ") {
                style = .heading1
                text = String(text.dropFirst(2))
            } else if text.hasPrefix("- ") || text.hasPrefix("* ") {
                listPrefix = "•\t"
                text = String(text.dropFirst(2))
            } else if let dot = text.firstIndex(of: "."),
                      text[text.startIndex..<dot].allSatisfy(\.isNumber),
                      !text[text.startIndex..<dot].isEmpty,
                      text.index(after: dot) < text.endIndex,
                      text[text.index(after: dot)] == " " {
                listPrefix = String(text[text.startIndex..<dot]) + ".\t"
                text = String(text[text.index(dot, offsetBy: 2)...])
            }

            let paragraph = NSMutableAttributedString()
            if !listPrefix.isEmpty {
                paragraph.append(NSAttributedString(string: listPrefix, attributes: attributes(for: style, bold: false, italic: false, mono: false)))
            }
            paragraph.append(inlineAttributed(from: text, style: style))

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.headerLevel = style.headerLevel
            paragraphStyle.paragraphSpacing = style.spacingAfter
            paragraphStyle.paragraphSpacingBefore = style.spacingBefore
            if !listPrefix.isEmpty {
                paragraphStyle.headIndent = EditorDefaults.listIndent
                paragraphStyle.tabStops = [NSTextTab(textAlignment: .left, location: EditorDefaults.listIndent, options: [:])]
            }
            paragraph.addAttribute(
                .paragraphStyle,
                value: paragraphStyle,
                range: NSRange(location: 0, length: paragraph.length)
            )

            result.append(paragraph)
            result.append(NSAttributedString(string: "\n", attributes: attributes(for: style, bold: false, italic: false, mono: false)))
        }

        return result
    }

    private static func inlineAttributed(from line: String, style: TextStyle) -> NSAttributedString {
        let result = NSMutableAttributedString()
        var buffer = ""
        var index = line.startIndex

        func flush(bold: Bool = false, italic: Bool = false, mono: Bool = false, text: String? = nil) {
            let value = text ?? buffer
            guard !value.isEmpty else { return }
            result.append(NSAttributedString(string: value, attributes: attributes(for: style, bold: bold, italic: italic, mono: mono)))
            if text == nil { buffer = "" }
        }

        while index < line.endIndex {
            let remainder = line[index...]
            if let match = marker(in: remainder) {
                flush()
                flush(bold: match.bold, italic: match.italic, mono: match.mono, text: match.text)
                index = line.index(index, offsetBy: match.consumed)
            } else {
                buffer.append(line[index])
                index = line.index(after: index)
            }
        }
        flush()
        return result
    }

    private struct InlineMatch {
        let text: String
        let consumed: Int
        var bold = false
        var italic = false
        var mono = false
    }

    private static func marker(in text: Substring) -> InlineMatch? {
        let delimiters: [(String, Bool, Bool, Bool)] = [
            ("***", true, true, false),
            ("**", true, false, false),
            ("*", false, true, false),
            ("`", false, false, true),
        ]
        for (delimiter, bold, italic, mono) in delimiters where text.hasPrefix(delimiter) {
            let body = text.dropFirst(delimiter.count)
            guard let end = body.range(of: delimiter) else { continue }
            let content = String(body[body.startIndex..<end.lowerBound])
            guard !content.isEmpty else { continue }
            return InlineMatch(
                text: content,
                consumed: delimiter.count * 2 + content.count,
                bold: bold,
                italic: italic,
                mono: mono
            )
        }
        return nil
    }

    private static func attributes(for style: TextStyle, bold: Bool, italic: Bool, mono: Bool) -> [NSAttributedString.Key: Any] {
        let manager = NSFontManager.shared
        var font: NSFont
        if mono || style.isMonospaced {
            font = .monospacedSystemFont(ofSize: style.fontSize, weight: .regular)
        } else {
            font = NSFont(name: EditorDefaults.fontFamily, size: style.fontSize) ?? .systemFont(ofSize: style.fontSize)
        }
        if bold || style.isBold { font = manager.convert(font, toHaveTrait: .boldFontMask) }
        if italic { font = manager.convert(font, toHaveTrait: .italicFontMask) }
        return [.font: font, .foregroundColor: NSColor.textColor]
    }
}
