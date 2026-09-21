import AppKit
import SwiftUI

/// One white sheet. Draws the paper; the text view inside covers the content box.
final class PageView: NSView {
    let textView: NSTextView
    let index: Int

    init(textView: NSTextView, index: Int) {
        self.textView = textView
        self.index = index
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
        layer?.shadowColor = NSColor.black.withAlphaComponent(0.25).cgColor
        layer?.shadowOpacity = 1
        layer?.shadowOffset = CGSize(width: 0, height: -1)
        layer?.shadowRadius = 6
        layer?.cornerRadius = 2
        addSubview(textView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }

    override var isFlipped: Bool { true }

    func layoutPage(config: PageConfig) {
        textView.frame = NSRect(
            x: config.margin,
            y: config.margin,
            width: config.contentSize.width,
            height: config.contentSize.height
        )
    }
}

/// Stacks pages vertically and grows or shrinks the page count as the shared
/// text storage reflows.
final class PagedDocumentView: NSView {
    private enum Metrics {
        static let gap: CGFloat = 24
        static let sideInset: CGFloat = 32
    }

    weak var controller: DocumentController?
    private(set) var pages: [PageView] = []
    private var config = PageConfig()
    private var isPaginating = false

    var pageCount: Int { max(1, pages.count) }

    private var layoutManager: NSLayoutManager? { controller?.layoutManager }

    init(controller: DocumentController) {
        self.controller = controller
        super.init(frame: .zero)
        controller.documentView = self
        // A previous canvas may still own containers on the shared layout manager.
        while !controller.layoutManager.textContainers.isEmpty {
            controller.layoutManager.removeTextContainer(at: 0)
        }
        appendPage()
        updatePagination()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }

    override var isFlipped: Bool { true }

    // MARK: - Page construction

    private func makeTextView() -> NSTextView {
        let container = NSTextContainer(size: config.contentSize)
        container.widthTracksTextView = false
        container.heightTracksTextView = false
        container.lineFragmentPadding = 0
        layoutManager?.addTextContainer(container)

        let textView = NSTextView(frame: NSRect(origin: .zero, size: config.contentSize), textContainer: container)
        textView.isVerticallyResizable = false
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = []
        textView.minSize = config.contentSize
        textView.maxSize = config.contentSize
        textView.textContainerInset = .zero
        textView.isRichText = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.allowsImageEditing = true
        textView.importsGraphics = true
        textView.usesFontPanel = true
        textView.drawsBackground = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.delegate = controller
        textView.typingAttributes = EditorDefaults.bodyAttributes
        return textView
    }

    @discardableResult
    private func appendPage() -> PageView {
        let page = PageView(textView: makeTextView(), index: pages.count)
        addSubview(page)
        pages.append(page)
        return page
    }

    private func removeLastPage() {
        guard pages.count > 1, let page = pages.popLast(), let layoutManager else { return }
        if let container = page.textView.textContainer,
           let index = layoutManager.textContainers.firstIndex(where: { $0 === container }) {
            layoutManager.removeTextContainer(at: index)
        }
        page.textView.delegate = nil
        page.removeFromSuperview()
    }

    // MARK: - Pagination

    func updatePagination() {
        guard !isPaginating, let layoutManager else { return }
        isPaginating = true
        defer { isPaginating = false }

        var safety = 0
        while safety < 400 {
            guard let lastContainer = layoutManager.textContainers.last else { break }
            layoutManager.ensureLayout(for: lastContainer)
            let laidOut = layoutManager.glyphRange(for: lastContainer)
            let total = layoutManager.numberOfGlyphs
            if laidOut.upperBound < total {
                appendPage()
                layoutPages()
                safety += 1
            } else {
                break
            }
        }

        while pages.count > 1 {
            guard let container = pages.last?.textView.textContainer else { break }
            layoutManager.ensureLayout(for: container)
            if layoutManager.glyphRange(for: container).length == 0 {
                removeLastPage()
            } else {
                break
            }
        }

        layoutPages()
        controller?.notePageCountChanged()
    }

    func applyConfig(_ newConfig: PageConfig) {
        guard newConfig != config else { return }
        config = newConfig
        for page in pages {
            page.textView.textContainer?.size = config.contentSize
            page.textView.minSize = config.contentSize
            page.textView.maxSize = config.contentSize
            page.layoutPage(config: config)
        }
        updatePagination()
    }

    func resetUndo() {
        for page in pages {
            page.textView.undoManager?.removeAllActions()
        }
    }

    // MARK: - Geometry

    private func layoutPages() {
        let visibleWidth = enclosingScrollView?.contentView.bounds.width ?? bounds.width
        let width = max(visibleWidth, config.size.width + Metrics.sideInset * 2)
        let originX = ((width - config.size.width) / 2).rounded()

        var y = Metrics.gap
        for page in pages {
            page.frame = NSRect(x: originX, y: y, width: config.size.width, height: config.size.height)
            page.layoutPage(config: config)
            y += config.size.height + Metrics.gap
        }

        let newSize = NSSize(width: width, height: y)
        if frame.size != newSize {
            setFrameSize(newSize)
        }
    }

    override func layout() {
        super.layout()
        layoutPages()
    }

    func scroll(toCharacterIndex index: Int) {
        guard let layoutManager, layoutManager.numberOfGlyphs > 0 else { return }
        let glyphIndex = layoutManager.glyphIndexForCharacter(at: index)
        guard let container = layoutManager.textContainer(forGlyphAt: min(glyphIndex, layoutManager.numberOfGlyphs - 1), effectiveRange: nil),
              let page = pages.first(where: { $0.textView.textContainer === container })
        else { return }

        let rect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 1), in: container)
        let target = page.textView.convert(rect, to: self).insetBy(dx: 0, dy: -90)
        scrollToVisible(target)
        window?.makeFirstResponder(page.textView)
        page.textView.setSelectedRange(NSRange(location: index, length: 0))
    }

    func printDocument(jobTitle: String) {
        let info = NSPrintInfo.shared.copy() as? NSPrintInfo ?? NSPrintInfo.shared
        info.paperSize = config.size
        info.topMargin = config.margin
        info.bottomMargin = config.margin
        info.leftMargin = config.margin
        info.rightMargin = config.margin
        info.horizontalPagination = .fit
        info.verticalPagination = .automatic
        info.isVerticallyCentered = false
        info.isHorizontallyCentered = false

        let printView = DocumentIO.makePrintView(
            attributed: controller?.attributedCopy ?? NSAttributedString(),
            contentWidth: config.contentSize.width
        )
        let operation = NSPrintOperation(view: printView, printInfo: info)
        operation.jobTitle = jobTitle
        operation.run()
    }
}

/// SwiftUI host for the paged canvas.
struct PagedEditor: NSViewRepresentable {
    @ObservedObject var controller: DocumentController

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = NSColor.windowBackgroundColor
        scrollView.borderType = .noBorder

        let documentView = PagedDocumentView(controller: controller)
        scrollView.documentView = documentView
        DispatchQueue.main.async {
            documentView.updatePagination()
            controller.focusEditor()
        }
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let documentView = nsView.documentView as? PagedDocumentView else { return }
        documentView.applyConfig(controller.config)
        documentView.needsLayout = true
    }
}
