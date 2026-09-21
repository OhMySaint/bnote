import AppKit
import Combine
import SwiftUI

struct FormatState: Equatable {
    var fontFamily = EditorDefaults.fontFamily
    var fontSize: CGFloat = EditorDefaults.fontSize
    var bold = false
    var italic = false
    var underline = false
    var strikethrough = false
    var alignment: NSTextAlignment = .left
    var style: TextStyle = .body
    var list: ListKind = .none
    var lineHeight: CGFloat = 1.0
}

/// Owns the shared text storage for the whole app and applies every formatting
/// command. Pages are laid out by `PagedDocumentView`, which shares this layout
/// manager, so a single edit reflows across every page.
final class DocumentController: NSObject, ObservableObject {
    static let shared = DocumentController()

    let textStorage = NSTextStorage()
    let layoutManager = NSLayoutManager()

    @Published private(set) var pageCount = 1
    @Published private(set) var outline: [OutlineItem] = []
    @Published private(set) var wordCount = 0
    @Published private(set) var characterCount = 0
    @Published var format = FormatState()
    @Published var config = PageConfig() {
        didSet {
            guard config != oldValue else { return }
            documentView?.applyConfig(config)
        }
    }

    weak var documentView: PagedDocumentView?
    /// Called (debounced) with flattened RTFD + plain text whenever the document changes.
    var onSave: ((Data, String) -> Void)?

    private var isLoading = false
    private var isRenumbering = false
    private var saveWork: DispatchWorkItem?

    override init() {
        super.init()
        textStorage.addLayoutManager(layoutManager)
    }

    // MARK: - Document lifecycle

    func load(data: Data?, plainText: String, config: PageConfig) {
        isLoading = true
        saveWork?.cancel()

        let attributed: NSAttributedString
        if let data, let restored = Self.attributedString(from: data) {
            attributed = restored
        } else {
            attributed = NSAttributedString(string: plainText, attributes: EditorDefaults.bodyAttributes)
        }

        textStorage.setAttributedString(attributed)
        self.config = config
        documentView?.applyConfig(config)
        documentView?.resetUndo()
        refreshDerivedState()
        refreshFormatState()
        isLoading = false
    }

    func snapshot() -> (data: Data, plainText: String) {
        let range = NSRange(location: 0, length: textStorage.length)
        let data = textStorage.rtfd(from: range, documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd])
            ?? Data()
        return (data, textStorage.string)
    }

    static func attributedString(from data: Data) -> NSAttributedString? {
        if let rtfd = NSAttributedString(rtfd: data, documentAttributes: nil) { return rtfd }
        return NSAttributedString(rtf: data, documentAttributes: nil)
    }

    var attributedCopy: NSAttributedString {
        NSAttributedString(attributedString: textStorage)
    }

    func replaceDocument(with attributed: NSAttributedString) {
        let full = NSRange(location: 0, length: textStorage.length)
        guard let textView = activeTextView else {
            textStorage.setAttributedString(attributed)
            documentDidChange()
            return
        }
        guard textView.shouldChangeText(in: full, replacementString: attributed.string) else { return }
        textStorage.setAttributedString(attributed)
        textView.didChangeText()
        documentDidChange()
    }

    // MARK: - Active view

    var activeTextView: NSTextView? {
        layoutManager.textViewForBeginningOfSelection ?? layoutManager.firstTextView
    }

    private var selectedRange: NSRange {
        activeTextView?.selectedRange() ?? NSRange(location: 0, length: 0)
    }

    func focusEditor() {
        guard let textView = layoutManager.firstTextView else { return }
        textView.window?.makeFirstResponder(textView)
    }

    // MARK: - Change plumbing

    func documentDidChange() {
        guard !isLoading else { return }
        documentView?.updatePagination()
        renumberLists()
        refreshDerivedState()
        scheduleSave()
    }

    private func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, let onSave else { return }
            let snap = snapshot()
            onSave(snap.data, snap.plainText)
        }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    func saveNow() {
        saveWork?.cancel()
        guard let onSave else { return }
        let snap = snapshot()
        onSave(snap.data, snap.plainText)
    }

    private func refreshDerivedState() {
        pageCount = documentView?.pageCount ?? 1
        outline = buildOutline()
        let text = textStorage.string
        characterCount = text.count
        wordCount = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    func refreshFormatState() {
        var state = FormatState()
        let range = selectedRange
        let attributes: [NSAttributedString.Key: Any]
        if range.length > 0, range.location < textStorage.length {
            attributes = textStorage.attributes(at: range.location, effectiveRange: nil)
        } else if let typing = activeTextView?.typingAttributes, !typing.isEmpty {
            attributes = typing
        } else if textStorage.length > 0 {
            attributes = textStorage.attributes(at: max(0, min(range.location, textStorage.length - 1)), effectiveRange: nil)
        } else {
            attributes = EditorDefaults.bodyAttributes
        }

        let font = attributes[.font] as? NSFont ?? EditorDefaults.bodyFont
        let traits = NSFontManager.shared.traits(of: font)
        state.fontFamily = font.familyName ?? EditorDefaults.fontFamily
        state.fontSize = font.pointSize
        state.bold = traits.contains(.boldFontMask)
        state.italic = traits.contains(.italicFontMask)
        state.underline = (attributes[.underlineStyle] as? Int ?? 0) != 0
        state.strikethrough = (attributes[.strikethroughStyle] as? Int ?? 0) != 0

        let paragraph = attributes[.paragraphStyle] as? NSParagraphStyle
        state.alignment = paragraph?.alignment ?? .left
        state.lineHeight = paragraph?.lineHeightMultiple == 0 ? 1.0 : (paragraph?.lineHeightMultiple ?? 1.0)
        state.style = TextStyle.detect(font: font, paragraph: paragraph)
        state.list = currentListKind()

        if state != format { format = state }
    }

    // MARK: - Edit helpers

    private func mutate(range: NSRange, replacement: String? = nil, _ body: () -> Void) {
        guard let textView = activeTextView else { return }
        guard textView.shouldChangeText(in: range, replacementString: replacement) else { return }
        textStorage.beginEditing()
        body()
        textStorage.endEditing()
        textView.didChangeText()
        documentDidChange()
        refreshFormatState()
    }

    private func applyAttributes(_ attributes: [NSAttributedString.Key: Any]) {
        let range = selectedRange
        if range.length == 0 {
            activeTextView?.typingAttributes.merge(attributes) { _, new in new }
            refreshFormatState()
            return
        }
        mutate(range: range) {
            textStorage.addAttributes(attributes, range: range)
        }
    }

    private func paragraphRanges(for range: NSRange) -> [NSRange] {
        let string = textStorage.string as NSString
        guard string.length > 0 else { return [NSRange(location: 0, length: 0)] }
        var ranges: [NSRange] = []
        var location = min(range.location, string.length)
        let end = min(max(range.location + range.length, range.location), string.length)
        repeat {
            let paragraph = string.paragraphRange(for: NSRange(location: min(location, string.length - 1), length: 0))
            ranges.append(paragraph)
            location = paragraph.upperBound
        } while location < end
        return ranges
    }

    private func enclosingParagraphRange(for range: NSRange) -> NSRange {
        let ranges = paragraphRanges(for: range)
        guard let first = ranges.first, let last = ranges.last else { return range }
        return NSRange(location: first.location, length: last.upperBound - first.location)
    }

    private func paragraphStyle(at location: Int) -> NSMutableParagraphStyle {
        let existing = location < textStorage.length
            ? textStorage.attribute(.paragraphStyle, at: location, effectiveRange: nil) as? NSParagraphStyle
            : activeTextView?.typingAttributes[.paragraphStyle] as? NSParagraphStyle
        let style = (existing?.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
        return style
    }

    private func updateParagraphs(_ transform: (NSMutableParagraphStyle) -> Void) {
        let selection = selectedRange
        guard textStorage.length > 0 else {
            let style = paragraphStyle(at: 0)
            transform(style)
            activeTextView?.typingAttributes[.paragraphStyle] = style
            refreshFormatState()
            return
        }
        let ranges = paragraphRanges(for: selection)
        mutate(range: enclosingParagraphRange(for: selection)) {
            for paragraph in ranges where paragraph.length > 0 || paragraph.location < textStorage.length {
                let style = paragraphStyle(at: min(paragraph.location, max(0, textStorage.length - 1)))
                transform(style)
                let applied = NSRange(
                    location: paragraph.location,
                    length: min(paragraph.length, textStorage.length - paragraph.location)
                )
                if applied.length > 0 {
                    textStorage.addAttribute(.paragraphStyle, value: style, range: applied)
                }
            }
        }
        if let style = activeTextView?.typingAttributes[.paragraphStyle] as? NSParagraphStyle,
           let mutable = style.mutableCopy() as? NSMutableParagraphStyle {
            transform(mutable)
            activeTextView?.typingAttributes[.paragraphStyle] = mutable
        }
    }

    // MARK: - Character formatting

    func toggleTrait(_ trait: NSFontTraitMask) {
        let manager = NSFontManager.shared
        let range = selectedRange
        if range.length == 0 {
            let current = (activeTextView?.typingAttributes[.font] as? NSFont) ?? EditorDefaults.bodyFont
            let isOn = manager.traits(of: current).contains(trait)
            let updated = isOn
                ? manager.convert(current, toNotHaveTrait: trait)
                : manager.convert(current, toHaveTrait: trait)
            activeTextView?.typingAttributes[.font] = updated
            refreshFormatState()
            return
        }

        let startFont = textStorage.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont
            ?? EditorDefaults.bodyFont
        let turnOff = manager.traits(of: startFont).contains(trait)

        mutate(range: range) {
            textStorage.enumerateAttribute(.font, in: range) { value, subrange, _ in
                let font = value as? NSFont ?? EditorDefaults.bodyFont
                let updated = turnOff
                    ? manager.convert(font, toNotHaveTrait: trait)
                    : manager.convert(font, toHaveTrait: trait)
                textStorage.addAttribute(.font, value: updated, range: subrange)
            }
        }
    }

    func toggleUnderline() {
        let isOn = format.underline
        applyAttributes([.underlineStyle: isOn ? 0 : NSUnderlineStyle.single.rawValue])
    }

    func toggleStrikethrough() {
        let isOn = format.strikethrough
        applyAttributes([.strikethroughStyle: isOn ? 0 : NSUnderlineStyle.single.rawValue])
    }

    func setFontFamily(_ family: String) {
        let range = selectedRange
        if range.length == 0 {
            let current = (activeTextView?.typingAttributes[.font] as? NSFont) ?? EditorDefaults.bodyFont
            if let converted = NSFontManager.shared.convert(current, toFamily: family) as NSFont? {
                activeTextView?.typingAttributes[.font] = converted
            }
            refreshFormatState()
            return
        }
        mutate(range: range) {
            textStorage.enumerateAttribute(.font, in: range) { value, subrange, _ in
                let font = value as? NSFont ?? EditorDefaults.bodyFont
                let converted = NSFontManager.shared.convert(font, toFamily: family)
                textStorage.addAttribute(.font, value: converted, range: subrange)
            }
        }
    }

    func setFontSize(_ size: CGFloat) {
        let clamped = min(max(size, 6), 288)
        let range = selectedRange
        if range.length == 0 {
            let current = (activeTextView?.typingAttributes[.font] as? NSFont) ?? EditorDefaults.bodyFont
            activeTextView?.typingAttributes[.font] = NSFontManager.shared.convert(current, toSize: clamped)
            refreshFormatState()
            return
        }
        mutate(range: range) {
            textStorage.enumerateAttribute(.font, in: range) { value, subrange, _ in
                let font = value as? NSFont ?? EditorDefaults.bodyFont
                textStorage.addAttribute(.font, value: NSFontManager.shared.convert(font, toSize: clamped), range: subrange)
            }
        }
    }

    func nudgeFontSize(by delta: CGFloat) {
        setFontSize(format.fontSize + delta)
    }

    func setTextColor(_ color: NSColor) {
        applyAttributes([.foregroundColor: color])
    }

    func setHighlight(_ color: NSColor?) {
        if let color {
            applyAttributes([.backgroundColor: color])
        } else {
            let range = selectedRange
            if range.length == 0 {
                activeTextView?.typingAttributes.removeValue(forKey: .backgroundColor)
                return
            }
            mutate(range: range) {
                textStorage.removeAttribute(.backgroundColor, range: range)
            }
        }
    }

    func clearFormatting() {
        let range = selectedRange
        guard range.length > 0 else { return }
        mutate(range: range) {
            textStorage.setAttributes(EditorDefaults.bodyAttributes, range: range)
        }
    }

    func setLink(_ urlString: String) {
        let range = selectedRange
        guard range.length > 0, let url = URL(string: urlString) else { return }
        mutate(range: range) {
            textStorage.addAttributes([
                .link: url,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .foregroundColor: NSColor.linkColor,
            ], range: range)
        }
    }

    // MARK: - Paragraph formatting

    func setAlignment(_ alignment: NSTextAlignment) {
        updateParagraphs { $0.alignment = alignment }
    }

    func setLineHeight(_ multiple: CGFloat) {
        updateParagraphs { $0.lineHeightMultiple = multiple }
    }

    func changeIndent(by delta: CGFloat) {
        updateParagraphs { style in
            let base = max(0, style.firstLineHeadIndent + delta)
            let hanging = style.headIndent - style.firstLineHeadIndent
            style.firstLineHeadIndent = base
            style.headIndent = max(base, base + max(0, hanging))
        }
    }

    func apply(style: TextStyle) {
        let selection = selectedRange
        let ranges = paragraphRanges(for: selection)
        let manager = NSFontManager.shared

        let makeFont: (NSFont?) -> NSFont = { current in
            if style.isMonospaced {
                return NSFont.monospacedSystemFont(ofSize: style.fontSize, weight: .regular)
            }
            let family = current?.familyName ?? EditorDefaults.fontFamily
            var font = NSFont(name: family, size: style.fontSize)
                ?? NSFont(descriptor: NSFontDescriptor(fontAttributes: [.family: family]), size: style.fontSize)
                ?? NSFont.systemFont(ofSize: style.fontSize)
            font = manager.convert(font, toNotHaveTrait: .boldFontMask)
            if style.isBold { font = manager.convert(font, toHaveTrait: .boldFontMask) }
            return font
        }

        guard textStorage.length > 0 else {
            var typing = activeTextView?.typingAttributes ?? EditorDefaults.bodyAttributes
            typing[.font] = makeFont(typing[.font] as? NSFont)
            let paragraph = NSMutableParagraphStyle()
            paragraph.headerLevel = style.headerLevel
            paragraph.paragraphSpacing = style.spacingAfter
            paragraph.paragraphSpacingBefore = style.spacingBefore
            typing[.paragraphStyle] = paragraph
            activeTextView?.typingAttributes = typing
            refreshFormatState()
            return
        }

        mutate(range: enclosingParagraphRange(for: selection)) {
            for paragraph in ranges {
                let clamped = NSRange(
                    location: paragraph.location,
                    length: min(paragraph.length, textStorage.length - paragraph.location)
                )
                guard clamped.length > 0 else { continue }
                let current = textStorage.attribute(.font, at: clamped.location, effectiveRange: nil) as? NSFont
                textStorage.addAttribute(.font, value: makeFont(current), range: clamped)

                let paragraphStyle = paragraphStyle(at: clamped.location)
                paragraphStyle.headerLevel = style.headerLevel
                paragraphStyle.paragraphSpacing = style.spacingAfter
                paragraphStyle.paragraphSpacingBefore = style.spacingBefore
                textStorage.addAttribute(.paragraphStyle, value: paragraphStyle, range: clamped)

                if style.isMonospaced {
                    textStorage.addAttribute(.backgroundColor, value: NSColor.quaternaryLabelColor, range: clamped)
                } else {
                    textStorage.removeAttribute(.backgroundColor, range: clamped)
                }
            }
        }
    }

    // MARK: - Lists

    private func listInfo(in paragraph: String) -> (kind: ListKind, markerLength: Int, number: Int)? {
        if paragraph.hasPrefix("•\t") { return (.bullet, 2, 0) }
        var digits = ""
        for character in paragraph {
            if character.isNumber { digits.append(character) } else { break }
        }
        guard !digits.isEmpty else { return nil }
        let rest = paragraph.dropFirst(digits.count)
        guard rest.hasPrefix(".\t") else { return nil }
        return (.numbered, digits.count + 2, Int(digits) ?? 1)
    }

    private func currentListKind() -> ListKind {
        let string = textStorage.string as NSString
        guard string.length > 0 else { return .none }
        let location = min(selectedRange.location, string.length - 1)
        let paragraph = string.paragraphRange(for: NSRange(location: location, length: 0))
        return listInfo(in: string.substring(with: paragraph))?.kind ?? .none
    }

    func toggleList(_ kind: ListKind) {
        guard kind != .none else { return }
        let string = textStorage.string as NSString
        guard string.length > 0 else {
            insertText(kind.marker)
            return
        }
        let selection = selectedRange
        let ranges = paragraphRanges(for: selection)
        let alreadyList = ranges.allSatisfy { range in
            listInfo(in: string.substring(with: range))?.kind == kind
        }

        mutate(range: enclosingParagraphRange(for: selection), replacement: "") {
            // Reversed, so edits never shift the ranges still to be processed.
            for range in ranges.reversed() {
                let text = (textStorage.string as NSString).substring(with: range)
                if let existing = listInfo(in: text) {
                    let markerRange = NSRange(location: range.location, length: existing.markerLength)
                    textStorage.replaceCharacters(in: markerRange, with: "")
                }
                if !alreadyList {
                    // renumberLists() fixes the ordinals afterwards.
                    let marker = kind == .bullet ? "•\t" : "1.\t"
                    let attributes = textStorage.length > range.location
                        ? textStorage.attributes(at: range.location, effectiveRange: nil)
                        : EditorDefaults.bodyAttributes
                    textStorage.insert(NSAttributedString(string: marker, attributes: attributes), at: range.location)
                }

                let updated = (textStorage.string as NSString)
                    .paragraphRange(for: NSRange(location: min(range.location, max(0, textStorage.length - 1)), length: 0))
                guard updated.length > 0 else { continue }
                let style = paragraphStyle(at: updated.location)
                if alreadyList {
                    style.headIndent = style.firstLineHeadIndent
                    style.tabStops = []
                } else {
                    let base = style.firstLineHeadIndent
                    style.headIndent = base + EditorDefaults.listIndent
                    style.tabStops = [NSTextTab(textAlignment: .left, location: base + EditorDefaults.listIndent, options: [:])]
                }
                textStorage.addAttribute(.paragraphStyle, value: style, range: updated)
            }
        }
        renumberLists()
        refreshFormatState()
    }

    /// Keeps `1. 2. 3.` sequences correct after edits.
    private func renumberLists() {
        guard !isRenumbering else { return }
        let string = textStorage.string as NSString
        guard string.length > 0 else { return }

        var replacements: [(NSRange, String)] = []
        var counter = 0
        var location = 0
        while location < string.length {
            let paragraph = string.paragraphRange(for: NSRange(location: location, length: 0))
            let text = string.substring(with: paragraph)
            if let info = listInfo(in: text), info.kind == .numbered {
                counter += 1
                if info.number != counter {
                    let markerRange = NSRange(location: paragraph.location, length: info.markerLength)
                    replacements.append((markerRange, "\(counter).\t"))
                }
            } else if listInfo(in: text)?.kind != .bullet, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                counter = 0
            }
            location = paragraph.upperBound
        }

        guard !replacements.isEmpty else { return }
        isRenumbering = true
        let selection = selectedRange
        textStorage.beginEditing()
        for (range, marker) in replacements.reversed() {
            let attributes = textStorage.attributes(at: range.location, effectiveRange: nil)
            textStorage.replaceCharacters(in: range, with: NSAttributedString(string: marker, attributes: attributes))
        }
        textStorage.endEditing()
        activeTextView?.setSelectedRange(NSRange(location: min(selection.location, textStorage.length), length: 0))
        isRenumbering = false
    }

    private func insertText(_ text: String) {
        let range = selectedRange
        mutate(range: range, replacement: text) {
            let attributes = activeTextView?.typingAttributes ?? EditorDefaults.bodyAttributes
            textStorage.replaceCharacters(in: range, with: NSAttributedString(string: text, attributes: attributes))
        }
    }

    // MARK: - Attachments

    func insertImage(_ image: NSImage) {
        let attachment = NSTextAttachment()
        let maxWidth = config.contentSize.width
        var size = image.size
        if size.width > maxWidth {
            let scale = maxWidth / size.width
            size = NSSize(width: maxWidth, height: size.height * scale)
        }
        image.size = size
        attachment.image = image
        attachment.bounds = NSRect(origin: .zero, size: size)

        let range = selectedRange
        mutate(range: range, replacement: " ") {
            textStorage.replaceCharacters(in: range, with: NSAttributedString(attachment: attachment))
        }
    }

    func insertPageBreak() {
        insertText("\u{000C}")
    }

    // MARK: - Outline

    private func buildOutline() -> [OutlineItem] {
        let string = textStorage.string as NSString
        guard string.length > 0 else { return [] }
        var items: [OutlineItem] = []
        var location = 0
        var index = 0
        while location < string.length {
            let paragraph = string.paragraphRange(for: NSRange(location: location, length: 0))
            let font = textStorage.attribute(.font, at: paragraph.location, effectiveRange: nil) as? NSFont
            let style = textStorage.attribute(.paragraphStyle, at: paragraph.location, effectiveRange: nil) as? NSParagraphStyle
            let detected = TextStyle.detect(font: font, paragraph: style)
            if detected.headerLevel > 0 {
                let text = string.substring(with: paragraph).trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    items.append(OutlineItem(id: index, text: text, level: detected.headerLevel, location: paragraph.location))
                    index += 1
                }
            }
            location = paragraph.upperBound
        }
        return items
    }

    func scrollToOutlineItem(_ item: OutlineItem) {
        documentView?.scroll(toCharacterIndex: item.location)
    }

    func notePageCountChanged() {
        pageCount = documentView?.pageCount ?? 1
    }
}

// MARK: - NSTextViewDelegate

extension DocumentController: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        documentDidChange()
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        refreshFormatState()
    }

    /// Enter inside a list continues it; Enter on an empty item leaves the list.
    func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
        guard replacementString == "\n", affectedCharRange.length == 0 else { return true }
        let string = textStorage.string as NSString
        guard string.length > 0, affectedCharRange.location > 0 else { return true }

        let paragraph = string.paragraphRange(for: NSRange(location: min(affectedCharRange.location, string.length - 1), length: 0))
        let text = string.substring(with: paragraph)
        guard let info = listInfo(in: text) else { return true }

        let body = String(text.dropFirst(info.markerLength)).trimmingCharacters(in: .whitespacesAndNewlines)
        let attributes = textStorage.attributes(at: paragraph.location, effectiveRange: nil)

        if body.isEmpty {
            let markerRange = NSRange(location: paragraph.location, length: info.markerLength)
            guard textView.shouldChangeText(in: markerRange, replacementString: "") else { return false }
            textStorage.beginEditing()
            textStorage.replaceCharacters(in: markerRange, with: "")
            let plain = NSMutableParagraphStyle()
            plain.paragraphSpacing = TextStyle.body.spacingAfter
            let cleared = NSRange(location: paragraph.location, length: max(0, paragraph.length - info.markerLength))
            if cleared.length > 0, cleared.upperBound <= textStorage.length {
                textStorage.addAttribute(.paragraphStyle, value: plain, range: cleared)
            }
            textStorage.endEditing()
            textView.didChangeText()
            textView.typingAttributes[.paragraphStyle] = plain
            documentDidChange()
            return false
        }

        let marker = info.kind == .bullet ? "•\t" : "\(info.number + 1).\t"
        guard textView.shouldChangeText(in: affectedCharRange, replacementString: "\n" + marker) else { return false }
        textStorage.beginEditing()
        textStorage.replaceCharacters(
            in: affectedCharRange,
            with: NSAttributedString(string: "\n" + marker, attributes: attributes)
        )
        textStorage.endEditing()
        textView.didChangeText()
        textView.setSelectedRange(NSRange(location: affectedCharRange.location + marker.count + 1, length: 0))
        documentDidChange()
        return false
    }

    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        if let url = link as? URL {
            NSWorkspace.shared.open(url)
            return true
        }
        if let string = link as? String, let url = URL(string: string) {
            NSWorkspace.shared.open(url)
            return true
        }
        return false
    }
}
