import AppKit
import Combine

/// State of the in-page find bar (⌘F). Matches are highlighted through the
/// shared layout manager's temporary attributes, so they show on every page
/// without touching the document itself.
final class FindModel: ObservableObject {
    @Published var isVisible = false
    @Published var showReplace = false
    @Published var query = ""
    @Published var replacement = ""
    @Published var caseSensitive = false
    @Published private(set) var matches: [NSRange] = []
    @Published private(set) var current = 0
    /// Bumped whenever the bar should take keyboard focus again.
    @Published var focusRequest = 0

    var hasMatches: Bool { !matches.isEmpty }
    var summary: String {
        if query.isEmpty { return "" }
        return matches.isEmpty ? "Not found" : "\(current + 1)/\(matches.count)"
    }

    fileprivate func set(matches: [NSRange], current: Int) {
        self.matches = matches
        self.current = matches.isEmpty ? 0 : min(max(current, 0), matches.count - 1)
    }
}

extension DocumentController {
    private static let matchColor = NSColor.systemYellow.withAlphaComponent(0.35)
    private static let currentMatchColor = NSColor.systemOrange.withAlphaComponent(0.6)

    // MARK: - Showing and hiding

    /// Opens the bar, seeding it with the selection when that is a short single line.
    func showFind(replace: Bool = false) {
        let range = activeTextView?.selectedRange() ?? NSRange(location: 0, length: 0)
        if range.length > 0, range.length <= 200, range.upperBound <= textStorage.length {
            let selected = (textStorage.string as NSString).substring(with: range)
            if !selected.contains("\n") { find.query = selected }
        }
        if replace { find.showReplace = true }
        find.isVisible = true
        find.focusRequest += 1
        refreshFind(preferring: range.location)
    }

    /// Closes the bar; the caret lands on the current match so Escape then
    /// typing continues right there.
    func hideFind() {
        guard find.isVisible else { return }
        let target = find.matches[safe: find.current]
        find.isVisible = false
        clearFindHighlights()
        find.set(matches: [], current: 0)
        if let target, target.upperBound <= textStorage.length, let textView = textView(containing: target.location) {
            textView.window?.makeFirstResponder(textView)
            textView.setSelectedRange(target)
            textView.scrollRangeToVisible(target)
        } else {
            focusEditor()
        }
    }

    func toggleFindReplace() {
        find.showReplace.toggle()
        find.focusRequest += 1
    }

    /// ⌘E: the selection becomes the search string without opening the bar.
    func useSelectionForFind() {
        let range = activeTextView?.selectedRange() ?? NSRange(location: 0, length: 0)
        guard range.length > 0, range.upperBound <= textStorage.length else { return }
        find.query = (textStorage.string as NSString).substring(with: range)
        if find.isVisible { refreshFind(preferring: range.location) }
    }

    // MARK: - Searching

    /// Re-runs the search over the whole document, keeping the current match
    /// as close as possible to `location` (or to the previous current match).
    func refreshFind(preferring location: Int? = nil) {
        guard find.isVisible else { return }
        let anchor = location ?? find.matches[safe: find.current]?.location ?? (activeTextView?.selectedRange().location ?? 0)
        let matches = allMatches(of: find.query)
        let index = matches.firstIndex { $0.location >= anchor } ?? 0
        find.set(matches: matches, current: index)
        applyFindHighlights()
    }

    /// Search then jump: used when the query changes, so the first hit after the
    /// caret scrolls into view.
    func findQueryChanged() {
        let caret = activeTextView?.selectedRange().location ?? 0
        refreshFind(preferring: caret)
        revealCurrentMatch()
    }

    func findNext() {
        guard find.isVisible, find.hasMatches else { return }
        find.set(matches: find.matches, current: (find.current + 1) % find.matches.count)
        applyFindHighlights()
        revealCurrentMatch()
    }

    func findPrevious() {
        guard find.isVisible, find.hasMatches else { return }
        find.set(matches: find.matches, current: (find.current - 1 + find.matches.count) % find.matches.count)
        applyFindHighlights()
        revealCurrentMatch()
    }

    private func allMatches(of query: String) -> [NSRange] {
        guard !query.isEmpty else { return [] }
        let text = textStorage.string as NSString
        var options: NSString.CompareOptions = []
        if !find.caseSensitive { options.insert(.caseInsensitive) }
        var result: [NSRange] = []
        var location = 0
        while location < text.length {
            let range = text.range(of: query, options: options, range: NSRange(location: location, length: text.length - location))
            guard range.location != NSNotFound else { break }
            result.append(range)
            location = range.upperBound
            if range.length == 0 { location += 1 }
        }
        return result
    }

    // MARK: - Highlights

    private func applyFindHighlights() {
        clearFindHighlights()
        for (index, range) in find.matches.enumerated() {
            let color = index == find.current ? Self.currentMatchColor : Self.matchColor
            layoutManager.addTemporaryAttribute(.backgroundColor, value: color, forCharacterRange: range)
        }
    }

    private func clearFindHighlights() {
        let full = NSRange(location: 0, length: textStorage.length)
        guard full.length > 0 else { return }
        layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: full)
    }

    /// Scrolls the current match into view. The selection is left alone so the
    /// orange highlight is not covered by the inactive-selection grey.
    func revealCurrentMatch() {
        guard let range = find.matches[safe: find.current], range.upperBound <= textStorage.length,
              let textView = textView(containing: range.location) else { return }
        textView.scrollRangeToVisible(range)
    }

    /// The page whose container lays out the character at `location`.
    private func textView(containing location: Int) -> NSTextView? {
        guard layoutManager.numberOfGlyphs > 0 else { return layoutManager.firstTextView }
        let glyph = layoutManager.glyphIndexForCharacter(at: location)
        let container = layoutManager.textContainer(forGlyphAt: min(glyph, layoutManager.numberOfGlyphs - 1), effectiveRange: nil)
        return container?.textView ?? layoutManager.firstTextView
    }

    // MARK: - Replacing

    func replaceCurrentMatch() {
        guard find.isVisible, let range = find.matches[safe: find.current], range.upperBound <= textStorage.length,
              let textView = activeTextView else { return }
        let replacement = find.replacement
        guard textView.shouldChangeText(in: range, replacementString: replacement) else { return }
        textStorage.replaceCharacters(in: range, with: replacement)
        textView.didChangeText()
        documentDidChange()
        // The next match now starts where the replaced text ends.
        refreshFind(preferring: range.location + (replacement as NSString).length)
        revealCurrentMatch()
    }

    func replaceAllMatches() {
        guard find.isVisible, find.hasMatches, let textView = activeTextView else { return }
        let ranges = find.matches
        let replacement = find.replacement
        guard textView.shouldChangeText(inRanges: ranges.map { NSValue(range: $0) },
                                        replacementStrings: Array(repeating: replacement, count: ranges.count)) else { return }
        textStorage.beginEditing()
        for range in ranges.reversed() {
            textStorage.replaceCharacters(in: range, with: replacement)
        }
        textStorage.endEditing()
        textView.didChangeText()
        documentDidChange()
        refreshFind(preferring: ranges.first?.location)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
