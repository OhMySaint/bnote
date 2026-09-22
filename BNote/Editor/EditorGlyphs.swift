import AppKit

extension NSAttributedString.Key {
    /// Marks characters inside a collapsed toggle. Derived from the toggle
    /// markers on every change, never authored by hand.
    static let bnHidden = NSAttributedString.Key("BNHidden")
}

enum ToggleMarker {
    static let expanded: Character = "▾"
    static let collapsed: Character = "▸"
    static let all: Set<Character> = [expanded, collapsed]
}

/// Checkboxes and toggle arrows live in the text as single characters, so plain
/// text, search and export keep working. On screen they are drawn by hand: the
/// character becomes a control glyph of a known width and `EditorMarkers` paints
/// a crisp control in that box.
enum EditorMarkers {
    static let all: Set<Character> = ToggleMarker.all.union([Checkbox.unchecked, Checkbox.checked])

    static func isMarker(_ character: Character) -> Bool { all.contains(character) }

    /// Box the control glyph reserves, sized off the paragraph's font.
    static func width(for font: NSFont) -> CGFloat {
        (font.pointSize * 1.15).rounded()
    }

    static func boxSide(for font: NSFont) -> CGFloat {
        (font.pointSize * 1.06).rounded()
    }

    /// Draws one marker inside the rect the layout manager reserved for it.
    static func draw(_ character: Character, in rect: NSRect, font: NSFont, checked: Bool) {
        switch character {
        case Checkbox.unchecked, Checkbox.checked:
            drawCheckbox(in: rect, font: font, checked: character == Checkbox.checked)
        case ToggleMarker.expanded, ToggleMarker.collapsed:
            drawTriangle(in: rect, font: font, expanded: character == ToggleMarker.expanded)
        default:
            break
        }
    }

    // MARK: - Pieces

    private static func drawCheckbox(in rect: NSRect, font: NSFont, checked: Bool) {
        let side = boxSide(for: font)
        // Sits on the text baseline the way a capital letter does.
        let box = NSRect(
            x: rect.minX,
            y: rect.midY - side / 2,
            width: side,
            height: side
        ).insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: box, xRadius: side * 0.28, yRadius: side * 0.28)
        path.lineWidth = 1.4

        if checked {
            NSColor.controlAccentColor.setFill()
            path.fill()
            // The text view is flipped, so +y points down.
            let tick = NSBezierPath()
            tick.move(to: NSPoint(x: box.minX + box.width * 0.24, y: box.midY + box.height * 0.02))
            tick.line(to: NSPoint(x: box.minX + box.width * 0.43, y: box.midY + box.height * 0.22))
            tick.line(to: NSPoint(x: box.minX + box.width * 0.78, y: box.midY - box.height * 0.22))
            tick.lineWidth = max(1.6, side * 0.14)
            tick.lineCapStyle = .round
            tick.lineJoinStyle = .round
            NSColor.white.setStroke()
            tick.stroke()
        } else {
            NSColor.tertiaryLabelColor.setStroke()
            path.stroke()
        }
    }

    private static func drawTriangle(in rect: NSRect, font: NSFont, expanded: Bool) {
        let side = boxSide(for: font)
        let box = NSRect(x: rect.minX, y: rect.midY - side / 2, width: side, height: side)
        let inset = side * 0.26
        let path = NSBezierPath()
        if expanded {
            path.move(to: NSPoint(x: box.minX + inset, y: box.midY - side * 0.13))
            path.line(to: NSPoint(x: box.maxX - inset, y: box.midY - side * 0.13))
            path.line(to: NSPoint(x: box.midX, y: box.midY + side * 0.20))
        } else {
            path.move(to: NSPoint(x: box.minX + inset + 1, y: box.midY - side * 0.26))
            path.line(to: NSPoint(x: box.minX + inset + 1, y: box.midY + side * 0.26))
            path.line(to: NSPoint(x: box.midX + inset * 0.9, y: box.midY))
        }
        path.close()
        NSColor.secondaryLabelColor.setFill()
        path.fill()
    }
}

/// Drives two things for the shared layout manager: text inside a collapsed
/// toggle generates no glyphs at all (so the lines really disappear), and
/// marker characters become blank control glyphs that `PageTextView` paints.
final class EditorGlyphDelegate: NSObject, NSLayoutManagerDelegate {
    func layoutManager(
        _ layoutManager: NSLayoutManager,
        shouldGenerateGlyphs glyphs: UnsafePointer<CGGlyph>,
        properties: UnsafePointer<NSLayoutManager.GlyphProperty>,
        characterIndexes: UnsafePointer<Int>,
        font: NSFont,
        forGlyphRange glyphRange: NSRange
    ) -> Int {
        guard let storage = layoutManager.textStorage else { return 0 }
        let length = (storage.string as NSString).length
        var adjusted: [NSLayoutManager.GlyphProperty] = []
        var touched = false

        for offset in 0..<glyphRange.length {
            let index = characterIndexes[offset]
            var property = properties[offset]
            if index < length {
                if storage.attribute(.bnHidden, at: index, effectiveRange: nil) != nil {
                    property = .null
                    touched = true
                } else if let character = storage.string.character(atUTF16: index),
                          EditorMarkers.isMarker(character) {
                    property = .controlCharacter
                    touched = true
                }
            }
            adjusted.append(property)
        }
        guard touched else { return 0 }

        adjusted.withUnsafeBufferPointer { buffer in
            layoutManager.setGlyphs(
                glyphs,
                properties: buffer.baseAddress!,
                characterIndexes: characterIndexes,
                font: font,
                forGlyphRange: glyphRange
            )
        }
        return glyphRange.length
    }

    func layoutManager(
        _ layoutManager: NSLayoutManager,
        shouldUse action: NSLayoutManager.ControlCharacterAction,
        forControlCharacterAt charIndex: Int
    ) -> NSLayoutManager.ControlCharacterAction {
        guard let storage = layoutManager.textStorage, charIndex < storage.length,
              let character = storage.string.character(atUTF16: charIndex),
              EditorMarkers.isMarker(character)
        else { return action }
        return .whitespace
    }

    func layoutManager(
        _ layoutManager: NSLayoutManager,
        boundingBoxForControlGlyphAt glyphIndex: Int,
        for textContainer: NSTextContainer,
        proposedLineFragment proposedRect: NSRect,
        glyphPosition: NSPoint,
        characterIndex: Int
    ) -> NSRect {
        let font = (layoutManager.textStorage?.attribute(.font, at: characterIndex, effectiveRange: nil) as? NSFont)
            ?? EditorDefaults.bodyFont
        return NSRect(
            x: glyphPosition.x,
            y: proposedRect.minY,
            width: EditorMarkers.width(for: font),
            height: proposedRect.height
        )
    }
}

extension String {
    /// The character at a UTF-16 offset, for the many AppKit APIs that count that way.
    func character(atUTF16 index: Int) -> Character? {
        let text = self as NSString
        guard index >= 0, index < text.length else { return nil }
        return Character(text.substring(with: NSRange(location: index, length: 1)))
    }
}
