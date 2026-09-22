import AppKit
import UniformTypeIdentifiers

/// How a document is persisted and how legacy data is repaired.
///
/// RTF cannot express a plain `NSTextBlock` (quote / callout / code frame): it
/// writes it as a table row and never closes the row, so every paragraph after
/// the first frame comes back inside one giant table cell and pagination
/// collapses. Documents are therefore stored as a keyed archive, which keeps
/// blocks intact; RTF is only produced for export, with frames flattened.
enum DocumentStorage {
    private static let archiveMagic = "bplist".data(using: .ascii)!

    // MARK: Save

    /// Plain `NSTextBlock` is rejected by NSParagraphStyle's secure decoder, and
    /// NSURL attribute values fail to decode securely, so the archive is written
    /// and read without secure coding. It only ever comes from this app's own
    /// sandboxed store.
    static func data(from attributed: NSAttributedString) -> Data {
        let copy = NSMutableAttributedString(attributedString: attributed)
        dehydrateAttachments(in: copy)
        copy.enumerateAttribute(.link, in: NSRange(location: 0, length: copy.length)) { value, range, _ in
            if let url = value as? URL { copy.addAttribute(.link, value: url.absoluteString as NSString, range: range) }
        }
        return (try? NSKeyedArchiver.archivedData(withRootObject: copy, requiringSecureCoding: false)) ?? Data()
    }

    /// Pictures are archived as PNG / JPEG bytes, not as NSImage (which would
    /// serialise uncompressed TIFF).
    private static func dehydrateAttachments(in string: NSMutableAttributedString) {
        string.enumerateAttribute(.attachment, in: NSRange(location: 0, length: string.length)) { value, range, _ in
            guard let attachment = value as? NSTextAttachment, let image = attachment.image else { return }
            let replacement = NSTextAttachment()
            replacement.bounds = attachment.bounds
            if attachment.contents == nil {
                let (data, type) = encoded(image)
                replacement.contents = data
                replacement.fileType = type
            } else {
                replacement.contents = attachment.contents
                replacement.fileType = attachment.fileType
            }
            string.addAttribute(.attachment, value: replacement, range: range)
        }
    }

    private static func encoded(_ image: NSImage) -> (Data?, String) {
        guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return (nil, UTType.png.identifier) }
        let hasAlpha = rep.hasAlpha && rep.samplesPerPixel == 4
        if !hasAlpha, rep.pixelsWide * rep.pixelsHigh > 300_000 {
            return (rep.representation(using: .jpeg, properties: [.compressionFactor: 0.88]), UTType.jpeg.identifier)
        }
        return (rep.representation(using: .png, properties: [:]), UTType.png.identifier)
    }

    // MARK: Load

    static func attributedString(from data: Data) -> NSAttributedString? {
        if data.starts(with: archiveMagic), let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data) {
            unarchiver.requiresSecureCoding = false
            let archived = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? NSAttributedString
            unarchiver.finishDecoding()
            if let archived {
                let mutable = NSMutableAttributedString(attributedString: archived)
                hydrateAttachments(in: mutable)
                repairLineHeights(in: mutable)
                return mutable
            }
            return nil
        }
        // Legacy RTFD / RTF written by earlier versions.
        let legacy = NSAttributedString(rtfd: data, documentAttributes: nil) ?? NSAttributedString(rtf: data, documentAttributes: nil)
        guard let legacy else { return nil }
        let mutable = NSMutableAttributedString(attributedString: legacy)
        repairLegacyFrames(in: mutable)
        hydrateAttachments(in: mutable)
        repairLineHeights(in: mutable)
        return mutable
    }

    /// Pages written while line spacing was expressed as `lineHeightMultiple`
    /// render with their glyphs sunk to the bottom of an inflated line, away
    /// from the caret. Convert the multiple to plain spacing under the line.
    static func repairLineHeights(in string: NSMutableAttributedString) {
        let whole = NSRange(location: 0, length: string.length)
        guard whole.length > 0 else { return }
        string.enumerateAttribute(.paragraphStyle, in: whole) { value, range, _ in
            guard let style = value as? NSParagraphStyle, style.lineHeightMultiple > 0,
                  let mutable = style.mutableCopy() as? NSMutableParagraphStyle
            else { return }
            let size = (string.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont)?.pointSize
                ?? EditorDefaults.fontSize
            mutable.lineSpacing = max(style.lineSpacing, ((style.lineHeightMultiple - 1.15) * size).rounded())
            mutable.lineHeightMultiple = 0
            string.addAttribute(.paragraphStyle, value: mutable, range: range)
        }
    }

    /// Runtime code works with `attachment.image`; rebuild it from the stored bytes.
    static func hydrateAttachments(in string: NSMutableAttributedString) {
        string.enumerateAttribute(.attachment, in: NSRange(location: 0, length: string.length)) { value, _, _ in
            guard let attachment = value as? NSTextAttachment, attachment.image == nil else { return }
            if let contents = attachment.contents, let image = NSImage(data: contents) {
                attachment.image = image
            } else if let wrapper = attachment.fileWrapper, let contents = wrapper.regularFileContents, let image = NSImage(data: contents) {
                attachment.image = image
            }
        }
    }

    /// Paragraphs that RTF dumped into a one-column table become proper frames
    /// again, grouped by what they look like; anything unrecognisable is unframed.
    static func repairLegacyFrames(in string: NSMutableAttributedString) {
        let text = string.string as NSString
        var location = 0
        var codeBlock: NSTextBlock?
        while location < text.length {
            let paragraph = text.paragraphRange(for: NSRange(location: location, length: 0))
            location = paragraph.upperBound
            guard paragraph.length > 0,
                  let style = string.attribute(.paragraphStyle, at: paragraph.location, effectiveRange: nil) as? NSParagraphStyle,
                  let block = style.textBlocks.first, block.isDecoration
            else {
                codeBlock = nil
                continue
            }
            let font = string.attribute(.font, at: paragraph.location, effectiveRange: nil) as? NSFont
            let content = text.substring(with: paragraph)
            let mutable = (style.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()

            if font?.isFixedPitch == true {
                let shared = codeBlock ?? CodeHighlighter.makeBlock()
                codeBlock = shared
                let code = CodeHighlighter.paragraphStyle(sharing: shared)
                string.addAttribute(.paragraphStyle, value: code, range: paragraph)
                continue
            }
            codeBlock = nil
            if content.hasPrefix("💡") {
                mutable.textBlocks = [Frames.callout()]
            } else if let font, NSFontManager.shared.traits(of: font).contains(.italicFontMask) {
                mutable.textBlocks = [Frames.quote()]
            } else {
                mutable.textBlocks = []
            }
            string.addAttribute(.paragraphStyle, value: mutable, range: paragraph)
        }
    }

    // MARK: Export

    /// Frames cannot survive RTF / DOCX / HTML; replace them with indents and a
    /// tint so other apps show something sensible and nothing gets swallowed.
    static func flattenedForExport(_ attributed: NSAttributedString) -> NSAttributedString {
        let copy = NSMutableAttributedString(attributedString: attributed)
        let text = copy.string as NSString
        var location = 0
        while location < text.length {
            let paragraph = text.paragraphRange(for: NSRange(location: location, length: 0))
            location = paragraph.upperBound
            guard paragraph.length > 0,
                  let style = copy.attribute(.paragraphStyle, at: paragraph.location, effectiveRange: nil) as? NSParagraphStyle,
                  let block = style.textBlocks.first, block.isDecoration,
                  let mutable = style.mutableCopy() as? NSMutableParagraphStyle
            else { continue }
            mutable.textBlocks = []
            mutable.firstLineHeadIndent += 18
            mutable.headIndent += 18
            copy.addAttribute(.paragraphStyle, value: mutable, range: paragraph)
            if let font = copy.attribute(.font, at: paragraph.location, effectiveRange: nil) as? NSFont, font.isFixedPitch {
                copy.addAttribute(.backgroundColor, value: NSColor(white: 0.94, alpha: 1), range: paragraph)
            } else if text.substring(with: paragraph).hasPrefix("💡") {
                copy.addAttribute(.backgroundColor, value: NSColor(red: 1, green: 0.96, blue: 0.8, alpha: 1), range: paragraph)
            }
        }
        return copy
    }
}

/// Frame builders shared by the editor and the legacy repair.
enum Frames {
    static func quote() -> NSTextBlock {
        let block = NSTextBlock()
        block.setValue(100, type: .percentageValueType, for: .width)
        block.setBorderColor(NSColor.tertiaryLabelColor, for: .minX)
        block.setWidth(3, type: .absoluteValueType, for: .border, edge: .minX)
        block.setWidth(12, type: .absoluteValueType, for: .padding, edge: .minX)
        return block
    }

    static func callout() -> NSTextBlock {
        let block = NSTextBlock()
        block.setValue(100, type: .percentageValueType, for: .width)
        block.backgroundColor = NSColor.systemYellow.withAlphaComponent(0.16)
        block.setBorderColor(NSColor.systemOrange.withAlphaComponent(0.6), for: .minX)
        block.setWidth(3, type: .absoluteValueType, for: .border, edge: .minX)
        for edge in [NSRectEdge.minX, .maxX, .minY, .maxY] {
            block.setWidth(9, type: .absoluteValueType, for: .padding, edge: edge)
        }
        return block
    }
}
