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
            documentView?.applyConfig(config, options: canvasOptions)
        }
    }
    @Published var canvasOptions = CanvasOptions() {
        didSet {
            guard canvasOptions != oldValue else { return }
            documentView?.applyConfig(config, options: canvasOptions)
        }
    }

    weak var documentView: PagedDocumentView?
    /// Called (debounced) with flattened RTFD + plain text whenever the document changes.
    var onSave: ((Data, String) -> Void)?

    let slashModel = SlashMenuModel()
    private lazy var slashPanel = SlashMenuPanel(model: slashModel)
    /// Character offset of the "/" that opened the block menu.
    private(set) var slashTrigger: Int?
    /// A "/" the user typed past or dismissed; it stays closed until the next one.
    private var slashDismissedTrigger: Int?

    private var isLoading = false
    private var isRenumbering = false
    private var saveWork: DispatchWorkItem?

    override init() {
        super.init()
        textStorage.addLayoutManager(layoutManager)
        slashModel.onPick = { [weak self] command in
            self?.runSlashCommand(command)
        }
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
        closeSlashMenu()
        slashDismissedTrigger = nil
        self.config = config
        documentView?.applyConfig(config, options: canvasOptions)
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
        updateSlashMenu()
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
            let paragraph = paragraphRange(at: location)
            ranges.append(paragraph)
            location = paragraph.upperBound
        } while location < end
        return ranges
    }

    /// Paragraph containing `location`. Unlike a clamped lookup this still
    /// answers the empty last paragraph when the caret sits after a trailing
    /// newline at the end of the document.
    func paragraphRange(at location: Int) -> NSRange {
        let string = textStorage.string as NSString
        return string.paragraphRange(for: NSRange(location: max(0, min(location, string.length)), length: 0))
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
        if paragraph.hasPrefix("\(Checkbox.unchecked)\t") || paragraph.hasPrefix("\(Checkbox.checked)\t") {
            return (.todo, 2, 0)
        }
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
                    let marker = kind.marker
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
            let info = listInfo(in: text)
            if let info, info.kind == .numbered {
                counter += 1
                if info.number != counter {
                    let markerRange = NSRange(location: paragraph.location, length: info.markerLength)
                    replacements.append((markerRange, "\(counter).\t"))
                }
            } else if info == nil, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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

// MARK: - Slash menu

extension DocumentController {
    /// Opens while the caret sits right after a "/" that starts a word.
    func updateSlashMenu() {
        guard let textView = activeTextView else {
            closeSlashMenu()
            return
        }
        // While an input method is composing, the "caret" is the end of the
        // marked text; some IMEs also keep that text selected.
        let caret: Int
        if textView.hasMarkedText() {
            caret = textView.markedRange().upperBound
        } else {
            let selection = textView.selectedRange()
            guard selection.length == 0 else {
                closeSlashMenu()
                return
            }
            caret = selection.location
        }
        let string = textStorage.string as NSString
        guard string.length > 0, caret <= string.length, caret > 0 else {
            closeSlashMenu()
            return
        }

        // The query may contain spaces ("/dau muc"), so scan back to the "/" itself
        // and stop only at a line break.
        let paragraph = paragraphRange(at: caret)
        var slash: Int?
        var index = caret - 1
        while index >= paragraph.location, caret - index <= 32 {
            let character = string.character(at: index)
            if character == 47 { // "/"
                slash = index
                break
            }
            if let scalar = UnicodeScalar(character), CharacterSet.newlines.contains(scalar) {
                break
            }
            index -= 1
        }

        guard let slash else {
            closeSlashMenu()
            return
        }
        // "/" must start a word, and the query must not start with a space.
        if slash > paragraph.location {
            let previous = string.character(at: slash - 1)
            guard let scalar = UnicodeScalar(previous), CharacterSet.whitespacesAndNewlines.contains(scalar) else {
                closeSlashMenu()
                return
            }
        }
        if caret > slash + 1 {
            let next = string.character(at: slash + 1)
            if let scalar = UnicodeScalar(next), CharacterSet.whitespaces.contains(scalar) {
                closeSlashMenu()
                return
            }
        }

        if let dismissed = slashDismissedTrigger, dismissed != slash {
            slashDismissedTrigger = nil
        }
        guard slashDismissedTrigger != slash else {
            closeSlashMenu()
            return
        }

        let query = string.substring(with: NSRange(location: slash + 1, length: caret - slash - 1))
        let matches = SlashCatalog.filter(query: query)
        guard !matches.isEmpty else {
            // Typing past the last match dismisses the menu until the next "/".
            slashDismissedTrigger = slash
            closeSlashMenu()
            return
        }

        let isNew = slashTrigger != slash
        slashTrigger = slash
        slashModel.query = query
        if slashModel.commands.map(\.id) != matches.map(\.id) {
            slashModel.commands = matches
            slashModel.selection = 0
            slashPanel.resize()
        } else if isNew {
            slashModel.selection = 0
        }
        slashModel.selection = min(slashModel.selection, matches.count - 1)

        // Menu state stands on its own; the panel only appears once the caret
        // can be located on screen.
        if let caretRect = caretScreenRect() {
            slashPanel.show(near: caretRect, parent: textView.window)
        }
    }

    func closeSlashMenu() {
        guard slashTrigger != nil || slashPanel.isVisible else { return }
        slashTrigger = nil
        slashPanel.hide()
    }

    /// Escape: close and keep it closed for this "/".
    func dismissSlashMenu() {
        slashDismissedTrigger = slashTrigger
        closeSlashMenu()
    }

    /// A dismissal belongs to one specific "/" character. Any edit at or before
    /// it either deletes or shifts that character, so the dismissal is void.
    func noteEditForSlashDismissal(at range: NSRange) {
        guard let dismissed = slashDismissedTrigger, range.location <= dismissed else { return }
        slashDismissedTrigger = nil
    }

    var isSlashMenuOpen: Bool { slashTrigger != nil && !slashModel.commands.isEmpty }

    /// Raw key handling for the menu. Returns true when the key was consumed.
    func handleSlashKey(_ event: NSEvent, in textView: NSTextView) -> Bool {
        guard isSlashMenuOpen, !event.modifierFlags.contains(.command) else { return false }
        switch event.keyCode {
        case 125: // ↓
            moveSlashSelection(1)
            return true
        case 126: // ↑
            moveSlashSelection(-1)
            return true
        case 36, 76, 48: // Return, keypad Enter, Tab
            finishComposition(in: textView)
            commitSlashSelection()
            return true
        case 53: // Escape
            dismissSlashMenu()
            return true
        default:
            return false
        }
    }

    /// Keeps whatever the input method has composed so far as plain text.
    private func finishComposition(in textView: NSTextView) {
        guard textView.hasMarkedText() else { return }
        textView.unmarkText()
        textView.inputContext?.discardMarkedText()
    }

    func moveSlashSelection(_ delta: Int) {
        guard !slashModel.commands.isEmpty else { return }
        let count = slashModel.commands.count
        slashModel.selection = (slashModel.selection + delta + count) % count
    }

    func commitSlashSelection() {
        guard slashModel.commands.indices.contains(slashModel.selection) else { return }
        runSlashCommand(slashModel.commands[slashModel.selection])
    }

    func runSlashCommand(_ command: SlashCommand) {
        guard let textView = activeTextView, let trigger = slashTrigger else { return }
        finishComposition(in: textView)
        let caret = textView.selectedRange().location
        closeSlashMenu()

        let typed = NSRange(location: trigger, length: max(0, min(caret, textStorage.length) - trigger))
        if typed.length > 0, textView.shouldChangeText(in: typed, replacementString: "") {
            textStorage.beginEditing()
            textStorage.replaceCharacters(in: typed, with: "")
            textStorage.endEditing()
            textView.didChangeText()
            textView.setSelectedRange(NSRange(location: trigger, length: 0))
        }

        command.perform(self)
        documentDidChange()
        refreshFormatState()
    }

    private func caretScreenRect() -> NSRect? {
        guard let textView = activeTextView,
              let container = textView.textContainer,
              let window = textView.window
        else { return nil }
        let caret = textView.selectedRange()
        let glyphRange = layoutManager.glyphRange(forCharacterRange: caret, actualCharacterRange: nil)
        var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: container)
        if rect.width < 1 { rect.size.width = 2 }
        if rect.height < 1 { rect.size.height = 16 }
        return window.convertToScreen(textView.convert(rect, to: nil))
    }
}

// MARK: - Notion-style blocks

extension DocumentController {
    /// Inserts `block` on a line of its own, adding a newline first when the
    /// current paragraph already has content.
    private func insertBlock(_ block: NSAttributedString) {
        guard let textView = activeTextView else { return }
        let caret = textView.selectedRange()
        let string = textStorage.string as NSString

        let insertion = NSMutableAttributedString()
        if string.length > 0 {
            let paragraph = paragraphRange(at: caret.location)
            let text = string.substring(with: paragraph).trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                insertion.append(NSAttributedString(string: "\n", attributes: EditorDefaults.bodyAttributes))
            }
        }
        insertion.append(block)

        mutate(range: caret, replacement: insertion.string) {
            textStorage.replaceCharacters(in: caret, with: insertion)
        }
        let end = min(caret.location + insertion.length, textStorage.length)
        textView.setSelectedRange(NSRange(location: end, length: 0))
        textView.typingAttributes = EditorDefaults.bodyAttributes
    }

    func insertQuote() {
        updateParagraphs { style in
            let block = NSTextBlock()
            block.setValue(100, type: .percentageValueType, for: .width)
            block.setBorderColor(NSColor.tertiaryLabelColor, for: .minX)
            block.setWidth(3, type: .absoluteValueType, for: .border, edge: .minX)
            block.setWidth(12, type: .absoluteValueType, for: .padding, edge: .minX)
            style.textBlocks = [block]
            style.paragraphSpacing = 8
            style.paragraphSpacingBefore = 8
        }
        styleCurrentParagraphs { attributes in
            let font = attributes[.font] as? NSFont ?? EditorDefaults.bodyFont
            attributes[.font] = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
            attributes[.foregroundColor] = NSColor.secondaryLabelColor
        }
    }

    func insertCallout() {
        guard let textView = activeTextView else { return }
        let string = textStorage.string as NSString
        guard string.length > 0 else {
            insertBlock(NSAttributedString(string: "💡 ", attributes: EditorDefaults.bodyAttributes))
            insertCalloutDecoration()
            return
        }

        let caret = textView.selectedRange().location
        let paragraph = paragraphRange(at: caret)
        let text = string.substring(with: paragraph)
        guard !text.hasPrefix("💡") else { return }

        // A callout is not a list item; drop any marker before decorating.
        if let list = listInfo(in: text) {
            let markerRange = NSRange(location: paragraph.location, length: list.markerLength)
            mutate(range: markerRange, replacement: "") {
                textStorage.replaceCharacters(in: markerRange, with: "")
            }
        }

        let anchor = paragraph.location
        let attributes = textStorage.length > anchor
            ? textStorage.attributes(at: anchor, effectiveRange: nil)
            : EditorDefaults.bodyAttributes
        let prefix = NSAttributedString(string: "💡 ", attributes: attributes)
        mutate(range: NSRange(location: anchor, length: 0), replacement: prefix.string) {
            textStorage.insert(prefix, at: anchor)
        }
        textView.setSelectedRange(NSRange(location: min(caret + prefix.length, textStorage.length), length: 0))
        insertCalloutDecoration()
    }

    private func insertCalloutDecoration() {
        updateParagraphs { style in
            let block = NSTextBlock()
            block.setValue(100, type: .percentageValueType, for: .width)
            block.backgroundColor = NSColor.systemYellow.withAlphaComponent(0.16)
            block.setBorderColor(NSColor.systemOrange.withAlphaComponent(0.6), for: .minX)
            block.setWidth(3, type: .absoluteValueType, for: .border, edge: .minX)
            for edge in [NSRectEdge.minX, .maxX, .minY, .maxY] {
                block.setWidth(9, type: .absoluteValueType, for: .padding, edge: edge)
            }
            style.textBlocks = [block]
            style.firstLineHeadIndent = 0
            style.headIndent = 0
            style.tabStops = []
            style.paragraphSpacing = 8
            style.paragraphSpacingBefore = 8
        }
    }

    func insertDivider() {
        let width = config.contentSize.width
        let image = NSImage(size: NSSize(width: width, height: 11))
        image.lockFocus()
        NSColor.separatorColor.setFill()
        NSRect(x: 0, y: 5, width: width, height: 1).fill()
        image.unlockFocus()

        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = NSRect(x: 0, y: 0, width: width, height: 11)

        let block = NSMutableAttributedString(attachment: attachment)
        block.append(NSAttributedString(string: "\n", attributes: EditorDefaults.bodyAttributes))
        insertBlock(block)
    }

    func insertTable(rows: Int, columns: Int) {
        let table = NSTextTable()
        table.numberOfColumns = columns
        table.layoutAlgorithm = .automaticLayoutAlgorithm
        table.collapsesBorders = true
        table.hidesEmptyCells = false

        let block = NSMutableAttributedString()
        for row in 0..<rows {
            for column in 0..<columns {
                let cell = NSTextTableBlock(
                    table: table,
                    startingRow: row,
                    rowSpan: 1,
                    startingColumn: column,
                    columnSpan: 1
                )
                for edge in [NSRectEdge.minX, .maxX, .minY, .maxY] {
                    cell.setBorderColor(NSColor.separatorColor, for: edge)
                    cell.setWidth(1, type: .absoluteValueType, for: .border, edge: edge)
                    cell.setWidth(5, type: .absoluteValueType, for: .padding, edge: edge)
                }
                let style = NSMutableParagraphStyle()
                style.textBlocks = [cell]
                var attributes = EditorDefaults.bodyAttributes
                attributes[.paragraphStyle] = style
                if row == 0 {
                    attributes[.font] = NSFontManager.shared.convert(EditorDefaults.bodyFont, toHaveTrait: .boldFontMask)
                }
                block.append(NSAttributedString(string: "\n", attributes: attributes))
            }
        }
        block.append(NSAttributedString(string: "\n", attributes: EditorDefaults.bodyAttributes))
        insertBlock(block)
    }

    func insertToday() {
        let text = Date().formatted(date: .long, time: .omitted)
        let attributes = activeTextView?.typingAttributes ?? EditorDefaults.bodyAttributes
        guard let textView = activeTextView else { return }
        let caret = textView.selectedRange()
        mutate(range: caret, replacement: text) {
            textStorage.replaceCharacters(in: caret, with: NSAttributedString(string: text, attributes: attributes))
        }
        textView.setSelectedRange(NSRange(location: min(caret.location + text.count, textStorage.length), length: 0))
    }

    func insertImageFromPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.prompt = "Chèn"
        guard panel.runModal() == .OK, let url = panel.url, let image = NSImage(contentsOf: url) else { return }
        insertImage(image)
    }

    func insertLinkFromPanel() {
        let alert = NSAlert()
        alert.messageText = "Chèn liên kết"
        alert.informativeText = "Nhập địa chỉ cho phần văn bản đang chọn."
        alert.addButton(withTitle: "Chèn")
        alert.addButton(withTitle: "Hủy")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        field.placeholderString = "https://"
        alert.accessoryView = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        setLink(field.stringValue)
    }

    private func styleCurrentParagraphs(_ transform: (inout [NSAttributedString.Key: Any]) -> Void) {
        guard let textView = activeTextView, textStorage.length > 0 else { return }
        let string = textStorage.string as NSString
        let selection = textView.selectedRange()
        let paragraph = paragraphRange(at: selection.location)
        let range = NSRange(location: paragraph.location, length: max(0, min(paragraph.length, textStorage.length - paragraph.location)))
        guard range.length > 0 else { return }
        mutate(range: range) {
            textStorage.enumerateAttributes(in: range) { attributes, subrange, _ in
                var updated = attributes
                transform(&updated)
                textStorage.setAttributes(updated, range: subrange)
            }
        }
    }

    // MARK: Checkbox

    /// Returns true when the click landed on a to-do marker and toggled it.
    func handleCheckboxClick(at point: NSPoint, in textView: NSTextView) -> Bool {
        guard let container = textView.textContainer, textStorage.length > 0 else { return false }
        let index = layoutManager.characterIndex(
            for: point,
            in: container,
            fractionOfDistanceBetweenInsertionPoints: nil
        )
        let string = textStorage.string as NSString
        let paragraph = string.paragraphRange(for: NSRange(location: min(index, string.length - 1), length: 0))
        guard paragraph.length >= 2 else { return false }

        let marker = string.substring(with: NSRange(location: paragraph.location, length: 1))
        guard marker == String(Checkbox.unchecked) || marker == String(Checkbox.checked) else { return false }
        guard index <= paragraph.location + 1 else { return false }

        toggleCheckbox(paragraph: paragraph, isChecked: marker == String(Checkbox.checked))
        return true
    }

    private func toggleCheckbox(paragraph: NSRange, isChecked: Bool) {
        guard let textView = activeTextView ?? layoutManager.firstTextView else { return }
        let replacement = String(isChecked ? Checkbox.unchecked : Checkbox.checked)
        let markerRange = NSRange(location: paragraph.location, length: 1)
        let attributes = textStorage.attributes(at: paragraph.location, effectiveRange: nil)

        guard textView.shouldChangeText(in: paragraph, replacementString: nil) else { return }
        textStorage.beginEditing()
        textStorage.replaceCharacters(in: markerRange, with: NSAttributedString(string: replacement, attributes: attributes))
        let body = NSRange(location: paragraph.location + 2, length: max(0, paragraph.length - 2))
        if body.length > 0, body.upperBound <= textStorage.length {
            if isChecked {
                textStorage.removeAttribute(.strikethroughStyle, range: body)
                textStorage.addAttribute(.foregroundColor, value: NSColor.textColor, range: body)
            } else {
                textStorage.addAttributes([
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                    .foregroundColor: NSColor.secondaryLabelColor,
                ], range: body)
            }
        }
        textStorage.endEditing()
        textView.didChangeText()
        documentDidChange()
    }
}

// MARK: - NSTextViewDelegate

extension DocumentController: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        documentDidChange()
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        refreshFormatState()
        updateSlashMenu()
    }

    /// While the "/" menu is open it owns the arrow keys, Enter and Escape.
    func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        guard isSlashMenuOpen else { return false }
        switch selector {
        case #selector(NSResponder.moveDown(_:)):
            moveSlashSelection(1)
            return true
        case #selector(NSResponder.moveUp(_:)):
            moveSlashSelection(-1)
            return true
        case #selector(NSResponder.insertNewline(_:)), #selector(NSResponder.insertTab(_:)):
            commitSlashSelection()
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            dismissSlashMenu()
            return true
        default:
            return false
        }
    }

    /// Enter inside a list continues it; Enter on an empty item leaves the list.
    func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
        noteEditForSlashDismissal(at: affectedCharRange)

        // Last line of defence: an input method may hand Return/Tab over as
        // plain text instead of a command while the "/" menu is open.
        if isSlashMenuOpen, let replacementString, replacementString == "\n" || replacementString == "\t" {
            finishComposition(in: textView)
            commitSlashSelection()
            return false
        }

        guard replacementString == "\n", affectedCharRange.length == 0 else { return true }
        let string = textStorage.string as NSString
        guard string.length > 0, affectedCharRange.location > 0 else { return true }

        let paragraph = paragraphRange(at: affectedCharRange.location)
        let text = string.substring(with: paragraph)

        // Enter on an empty quote / callout line leaves the block, as in Notion.
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // An empty trailing paragraph sits at index == length, where the
            // storage has no attributes to read.
            let style = paragraph.location < textStorage.length
                ? textStorage.attribute(.paragraphStyle, at: paragraph.location, effectiveRange: nil) as? NSParagraphStyle
                : textView.typingAttributes[.paragraphStyle] as? NSParagraphStyle

            if let style, !style.textBlocks.isEmpty, !(style.textBlocks.first is NSTextTableBlock) {
                let plain = NSMutableParagraphStyle()
                plain.paragraphSpacing = TextStyle.body.spacingAfter
                if paragraph.length > 0, paragraph.upperBound <= textStorage.length {
                    guard textView.shouldChangeText(in: paragraph, replacementString: nil) else { return false }
                    textStorage.beginEditing()
                    textStorage.addAttribute(.paragraphStyle, value: plain, range: paragraph)
                    textStorage.endEditing()
                    textView.didChangeText()
                }
                textView.typingAttributes[.paragraphStyle] = plain
                documentDidChange()
                return false
            }
        }

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

        let marker: String
        switch info.kind {
        case .bullet: marker = "•\t"
        case .todo: marker = "\(Checkbox.unchecked)\t"
        default: marker = "\(info.number + 1).\t"
        }

        // A finished to-do is struck through; the next one starts clean.
        var continuation = attributes
        if info.kind == .todo {
            continuation.removeValue(forKey: .strikethroughStyle)
            continuation[.foregroundColor] = NSColor.textColor
        }

        guard textView.shouldChangeText(in: affectedCharRange, replacementString: "\n" + marker) else { return false }
        textStorage.beginEditing()
        textStorage.replaceCharacters(
            in: affectedCharRange,
            with: NSAttributedString(string: "\n" + marker, attributes: continuation)
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
