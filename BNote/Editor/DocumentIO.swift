import AppKit
import UniformTypeIdentifiers

enum DocumentFormat: String, CaseIterable, Identifiable {
    case rtf, docx, html, markdown, text, pdf

    var id: String { rawValue }

    var label: String {
        switch self {
        case .rtf: "Rich Text (.rtf)"
        case .docx: "Word (.docx)"
        case .html: "HTML (.html)"
        case .markdown: "Markdown (.md)"
        case .text: "Văn bản thuần (.txt)"
        case .pdf: "PDF (.pdf)"
        }
    }

    var fileExtension: String {
        switch self {
        case .rtf: "rtf"
        case .docx: "docx"
        case .html: "html"
        case .markdown: "md"
        case .text: "txt"
        case .pdf: "pdf"
        }
    }

    var contentType: UTType {
        switch self {
        case .rtf: .rtf
        case .docx: UTType("org.openxmlformats.wordprocessingml.document") ?? .data
        case .html: .html
        case .markdown: UTType(filenameExtension: "md") ?? .plainText
        case .text: .plainText
        case .pdf: .pdf
        }
    }
}

enum DocumentIOError: LocalizedError {
    case unsupportedExport(DocumentFormat)
    case pdfFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedExport(let format): "Không xuất được định dạng \(format.label)."
        case .pdfFailed: "Không tạo được file PDF."
        }
    }
}

enum DocumentIO {
    static let importableExtensions = ["rtf", "rtfd", "doc", "docx", "odt", "html", "htm", "md", "markdown", "txt", "text"]

    // MARK: - Import

    struct ImportedDocument {
        let title: String
        let attributed: NSAttributedString
    }

    static func runImportPanel() -> [ImportedDocument] {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.message = "Chọn tài liệu để nhập vào BNote"
        panel.prompt = "Nhập"
        panel.allowedContentTypes = importableExtensions.compactMap { UTType(filenameExtension: $0) }

        guard panel.runModal() == .OK else { return [] }
        return panel.urls.compactMap { url in
            guard let attributed = read(url: url) else { return nil }
            return ImportedDocument(title: url.deletingPathExtension().lastPathComponent, attributed: attributed)
        }
    }

    static func read(url: URL) -> NSAttributedString? {
        let ext = url.pathExtension.lowercased()
        if ext == "md" || ext == "markdown" {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
            return MarkdownConverter.attributedString(fromMarkdown: text)
        }
        if let attributed = try? NSAttributedString(
            url: url,
            options: [.documentType: documentType(for: ext) as Any].compactMapValues { $0 },
            documentAttributes: nil
        ) {
            return normalize(attributed)
        }
        if let text = try? String(contentsOf: url, encoding: .utf8) {
            return NSAttributedString(string: text, attributes: EditorDefaults.bodyAttributes)
        }
        return nil
    }

    private static func documentType(for ext: String) -> NSAttributedString.DocumentType? {
        switch ext {
        case "rtf": .rtf
        case "rtfd": .rtfd
        case "html", "htm": .html
        case "docx": .officeOpenXML
        case "doc": .docFormat
        case "odt": .openDocument
        case "txt", "text": .plain
        default: nil
        }
    }

    /// Imported documents often carry no font or an oversized one; keep them readable.
    private static func normalize(_ attributed: NSAttributedString) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: attributed)
        let full = NSRange(location: 0, length: mutable.length)
        mutable.enumerateAttribute(.font, in: full) { value, range, _ in
            if value == nil {
                mutable.addAttribute(.font, value: EditorDefaults.bodyFont, range: range)
            }
        }
        mutable.enumerateAttribute(.foregroundColor, in: full) { value, range, _ in
            if value == nil {
                mutable.addAttribute(.foregroundColor, value: NSColor.textColor, range: range)
            }
        }
        return mutable
    }

    // MARK: - Export

    static func runExportPanel(
        attributed: NSAttributedString,
        format: DocumentFormat,
        suggestedName: String,
        config: PageConfig
    ) throws {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [format.contentType]
        panel.nameFieldStringValue = "\(sanitize(suggestedName)).\(format.fileExtension)"
        panel.message = "Xuất tài liệu"
        panel.prompt = "Xuất"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try write(attributed: attributed, format: format, to: url, config: config)
    }

    static func write(attributed: NSAttributedString, format: DocumentFormat, to url: URL, config: PageConfig) throws {
        let range = NSRange(location: 0, length: attributed.length)
        switch format {
        case .rtf:
            guard let data = attributed.rtf(from: range, documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
            else { throw DocumentIOError.unsupportedExport(format) }
            try data.write(to: url)
        case .docx:
            let data = try attributed.data(
                from: range,
                documentAttributes: [.documentType: NSAttributedString.DocumentType.officeOpenXML]
            )
            try data.write(to: url)
        case .html:
            let data = try attributed.data(
                from: range,
                documentAttributes: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue,
                ]
            )
            try data.write(to: url)
        case .markdown:
            try MarkdownConverter.markdown(from: attributed).write(to: url, atomically: true, encoding: .utf8)
        case .text:
            try attributed.string.write(to: url, atomically: true, encoding: .utf8)
        case .pdf:
            try writePDF(attributed: attributed, to: url, config: config)
        }
    }

    private static func writePDF(attributed: NSAttributedString, to url: URL, config: PageConfig) throws {
        let info = NSPrintInfo(dictionary: [:])
        info.paperSize = config.size
        info.topMargin = config.margin
        info.bottomMargin = config.margin
        info.leftMargin = config.margin
        info.rightMargin = config.margin
        info.horizontalPagination = .fit
        info.verticalPagination = .automatic
        info.isVerticallyCentered = false
        info.isHorizontallyCentered = false
        info.jobDisposition = .save
        info.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = url

        let printView = makePrintView(attributed: attributed, contentWidth: config.contentSize.width)
        let operation = NSPrintOperation(view: printView, printInfo: info)
        operation.showsPrintPanel = false
        operation.showsProgressPanel = false
        guard operation.run() else { throw DocumentIOError.pdfFailed }
    }

    static func makePrintView(attributed: NSAttributedString, contentWidth: CGFloat) -> NSTextView {
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: contentWidth, height: 100))
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.containerSize = NSSize(width: contentWidth, height: .greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textStorage?.setAttributedString(attributed)
        textView.sizeToFit()
        return textView
    }

    private static func sanitize(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = trimmed.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        return cleaned.isEmpty ? "BNote" : cleaned
    }
}
