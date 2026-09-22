import AppKit

/// Notion's toggle list: a paragraph that starts with a triangle and owns every
/// following paragraph indented deeper than itself. Collapsing hides those
/// paragraphs outright — they generate no glyphs, so the lines really fold away.
///
/// The triangle character in the text is the single source of truth (▸ closed,
/// ▾ open); the `.bnHidden` attribute is derived from it after every edit, so
/// the state survives save / reload and can never drift.
extension DocumentController {
    // MARK: - Geometry

    func paragraphIndent(at location: Int) -> CGFloat {
        guard location < textStorage.length,
              let style = textStorage.attribute(.paragraphStyle, at: location, effectiveRange: nil) as? NSParagraphStyle
        else { return 0 }
        return style.firstLineHeadIndent
    }

    /// The paragraph is a toggle when it starts with a triangle plus a tab.
    func toggleMarker(at paragraph: NSRange) -> Character? {
        guard paragraph.length >= 2, paragraph.location < textStorage.length else { return nil }
        let text = (textStorage.string as NSString).substring(with: NSRange(location: paragraph.location, length: 2))
        guard let first = text.first, ToggleMarker.all.contains(first), text.dropFirst().hasPrefix("\t") else { return nil }
        return first
    }

    /// Everything nested under the toggle: the following paragraphs indented
    /// deeper than it, up to the first one that is not.
    func childRange(ofToggleAt paragraph: NSRange) -> NSRange {
        let string = textStorage.string as NSString
        let base = paragraphIndent(at: paragraph.location)
        var end = paragraph.upperBound
        var location = paragraph.upperBound
        while location < string.length {
            let next = string.paragraphRange(for: NSRange(location: location, length: 0))
            guard paragraphIndent(at: next.location) > base + 0.5 else { break }
            end = next.upperBound
            location = next.upperBound
        }
        return NSRange(location: paragraph.upperBound, length: max(0, end - paragraph.upperBound))
    }

    func isHidden(at location: Int) -> Bool {
        guard location < textStorage.length else { return false }
        return textStorage.attribute(.bnHidden, at: location, effectiveRange: nil) != nil
    }

    // MARK: - Folding

    /// Re-derives `.bnHidden` for the whole document from the triangles. Cheap
    /// (one pass over paragraphs) and self-healing, so typing, pasting or
    /// re-indenting can never leave stale hidden text behind.
    func refreshCollapsedRanges() {
        guard !isFoldingUpdate else { return }
        let string = textStorage.string as NSString
        guard string.length > 0 else { return }

        var wanted: [NSRange] = []
        var location = 0
        while location < string.length {
            let paragraph = string.paragraphRange(for: NSRange(location: location, length: 0))
            if toggleMarker(at: paragraph) == ToggleMarker.collapsed {
                let children = childRange(ofToggleAt: paragraph)
                if children.length > 0 {
                    wanted.append(children)
                    // Nested toggles inside are hidden by this one already.
                    location = children.upperBound
                    continue
                }
            }
            location = paragraph.upperBound
        }

        var current: [NSRange] = []
        textStorage.enumerateAttribute(.bnHidden, in: NSRange(location: 0, length: string.length)) { value, range, _ in
            if value != nil { current.append(range) }
        }
        guard current != wanted else { return }

        isFoldingUpdate = true
        defer { isFoldingUpdate = false }
        textStorage.beginEditing()
        textStorage.removeAttribute(.bnHidden, range: NSRange(location: 0, length: string.length))
        for range in wanted {
            textStorage.addAttribute(.bnHidden, value: true, range: range)
        }
        textStorage.endEditing()

        let whole = NSRange(location: 0, length: string.length)
        layoutManager.invalidateGlyphs(forCharacterRange: whole, changeInLength: 0, actualCharacterRange: nil)
        layoutManager.invalidateLayout(forCharacterRange: whole, actualCharacterRange: nil)
        documentView?.updatePagination()
    }

    /// Flips the triangle at this paragraph and folds or unfolds its children.
    func toggleSection(at paragraph: NSRange) {
        guard let marker = toggleMarker(at: paragraph), let textView = activeTextView ?? layoutManager.firstTextView else { return }
        let opening = marker == ToggleMarker.collapsed
        let replacement = String(opening ? ToggleMarker.expanded : ToggleMarker.collapsed)
        let markerRange = NSRange(location: paragraph.location, length: 1)
        let attributes = textStorage.attributes(at: paragraph.location, effectiveRange: nil)

        guard textView.shouldChangeText(in: markerRange, replacementString: replacement) else { return }
        textStorage.beginEditing()
        textStorage.replaceCharacters(in: markerRange, with: NSAttributedString(string: replacement, attributes: attributes))
        textStorage.endEditing()
        textView.didChangeText()

        // Folding under the caret would strand it inside invisible text.
        let selection = textView.selectedRange()
        if !opening {
            let children = childRange(ofToggleAt: paragraph)
            if NSLocationInRange(selection.location, children) {
                textView.setSelectedRange(NSRange(location: max(paragraph.location, paragraph.upperBound - 1), length: 0))
            }
        }
        documentDidChange()
    }

    /// Opens every toggle that hides `location`, innermost last, so search and
    /// outline jumps can land inside a folded section.
    func expandToggles(containing location: Int) {
        var guardCount = 0
        while isHidden(at: location), guardCount < 50 {
            guardCount += 1
            let string = textStorage.string as NSString
            var candidate: NSRange?
            var probe = string.paragraphRange(for: NSRange(location: min(location, max(0, string.length - 1)), length: 0)).location
            while probe > 0 {
                let previous = string.paragraphRange(for: NSRange(location: probe - 1, length: 0))
                if toggleMarker(at: previous) == ToggleMarker.collapsed,
                   NSLocationInRange(location, childRange(ofToggleAt: previous)) {
                    candidate = previous
                    break
                }
                probe = previous.location
            }
            guard let paragraph = candidate else { return }
            toggleSection(at: paragraph)
        }
    }
}
