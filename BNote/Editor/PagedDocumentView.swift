import AppKit
import SwiftUI

/// Text view for one page. Extra jobs: route menu keys to the "/" menu before
/// the input method sees them, and toggle a to-do marker on click.
final class PageTextView: NSTextView {
    /// Input methods (Vietnamese Telex, CJK…) swallow Return and the arrows
    /// while composing, so the "/" menu takes them here, ahead of `interpretKeyEvents`.
    override func keyDown(with event: NSEvent) {
        if let controller = delegate as? DocumentController,
           controller.handleSlashKey(event, in: self) {
            return
        }
        super.keyDown(with: event)
    }

    /// Composition edits do not post `textDidChange`, so the menu is refreshed here.
    override func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        let controller = delegate as? DocumentController
        let edited = replacementRange.location == NSNotFound
            ? (hasMarkedText() ? markedRange() : self.selectedRange())
            : replacementRange
        controller?.noteEditForSlashDismissal(at: edited)
        super.setMarkedText(string, selectedRange: selectedRange, replacementRange: replacementRange)
        controller?.updateSlashMenu()
    }

    override func unmarkText() {
        super.unmarkText()
        (delegate as? DocumentController)?.updateSlashMenu()
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let controller = delegate as? DocumentController,
           controller.handleCheckboxClick(at: point, in: self) {
            return
        }
        super.mouseDown(with: event)
    }

    /// Shown on the first page while the document is empty.
    var placeholder: String?

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let placeholder,
              textStorage?.length == 0,
              layoutManager?.textContainers.first === textContainer
        else { return }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: EditorDefaults.bodyFont,
            .foregroundColor: NSColor.placeholderTextColor,
        ]
        (placeholder as NSString).draw(at: NSPoint(x: 0, y: 1), withAttributes: attributes)
    }
}

/// One white sheet: paper, optional grid, margin guides, and the text box.
final class PageView: NSView {
    let textView: PageTextView
    var pageNumber: Int
    private var config = PageConfig()
    private var options = CanvasOptions()

    init(textView: PageTextView, pageNumber: Int) {
        self.textView = textView
        self.pageNumber = pageNumber
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
        layer?.shadowColor = NSColor.black.withAlphaComponent(0.28).cgColor
        layer?.shadowOpacity = 1
        layer?.shadowOffset = CGSize(width: 0, height: -1)
        layer?.shadowRadius = 7
        layer?.cornerRadius = 2
        addSubview(textView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }

    override var isFlipped: Bool { true }

    func apply(config: PageConfig, options: CanvasOptions) {
        self.config = config
        self.options = options
        textView.frame = NSRect(origin: config.contentOrigin, size: config.contentSize)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.textBackgroundColor.setFill()
        bounds.fill()

        let content = NSRect(origin: config.contentOrigin, size: config.contentSize)

        if options.showGrid {
            NSColor.separatorColor.withAlphaComponent(0.35).setStroke()
            let path = NSBezierPath()
            path.lineWidth = 0.5
            let step = Unit.centimeter / 2
            var x = content.minX
            while x <= content.maxX + 0.5 {
                path.move(to: NSPoint(x: x.rounded(), y: content.minY))
                path.line(to: NSPoint(x: x.rounded(), y: content.maxY))
                x += step
            }
            var y = content.minY
            while y <= content.maxY + 0.5 {
                path.move(to: NSPoint(x: content.minX, y: y.rounded()))
                path.line(to: NSPoint(x: content.maxX, y: y.rounded()))
                y += step
            }
            path.stroke()
        }

        if options.showMarginGuides {
            NSColor.systemBlue.withAlphaComponent(0.5).setStroke()
            let guide = NSBezierPath(rect: content.insetBy(dx: -0.5, dy: -0.5))
            guide.lineWidth = 0.5
            guide.setLineDash([4, 3], count: 2, phase: 0)
            guide.stroke()
        }
    }
}

struct CanvasOptions: Equatable {
    var showGrid = false
    var showMarginGuides = true
    var showRuler = true
    var zoom: CGFloat = 1
}

/// Stacks pages vertically and grows or shrinks the page count as the shared
/// text storage reflows.
final class PagedDocumentView: NSView {
    private enum Metrics {
        static let gap: CGFloat = 26
        static let sideInset: CGFloat = 36
    }

    weak var controller: DocumentController?
    private(set) var pages: [PageView] = []
    private(set) var config = PageConfig()
    private var options = CanvasOptions()
    private var isPaginating = false

    var pageCount: Int { max(1, pages.count) }
    /// X offset of the sheets inside this view; the ruler lines up with it.
    private(set) var pageOriginX: CGFloat = 0

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

    private func makeTextView() -> PageTextView {
        let container = NSTextContainer(size: config.contentSize)
        container.widthTracksTextView = false
        container.heightTracksTextView = false
        container.lineFragmentPadding = 0
        layoutManager?.addTextContainer(container)

        let textView = PageTextView(frame: NSRect(origin: .zero, size: config.contentSize), textContainer: container)
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
        textView.placeholder = "Bắt đầu viết, hoặc gõ / để chèn khối…"
        return textView
    }

    @discardableResult
    private func appendPage() -> PageView {
        let page = PageView(textView: makeTextView(), pageNumber: pages.count + 1)
        page.apply(config: config, options: options)
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
            if laidOut.upperBound < layoutManager.numberOfGlyphs {
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

    func applyConfig(_ newConfig: PageConfig, options newOptions: CanvasOptions) {
        let configChanged = newConfig != config
        let optionsChanged = newOptions != options
        guard configChanged || optionsChanged else { return }
        config = newConfig
        options = newOptions

        if let scrollView = enclosingScrollView, scrollView.magnification != options.zoom {
            scrollView.magnification = options.zoom
        }

        for page in pages {
            page.textView.textContainer?.size = config.contentSize
            page.textView.minSize = config.contentSize
            page.textView.maxSize = config.contentSize
            page.apply(config: config, options: options)
        }
        if configChanged {
            updatePagination()
        } else {
            layoutPages()
        }
    }

    func resetUndo() {
        for page in pages {
            page.textView.undoManager?.removeAllActions()
        }
    }

    // MARK: - Geometry

    private func layoutPages() {
        let visibleWidth = (enclosingScrollView?.contentView.bounds.width ?? bounds.width)
        let width = max(visibleWidth, config.size.width + Metrics.sideInset * 2)
        pageOriginX = ((width - config.size.width) / 2).rounded()

        var y = Metrics.gap
        for (index, page) in pages.enumerated() {
            page.pageNumber = index + 1
            page.frame = NSRect(x: pageOriginX, y: y, width: config.size.width, height: config.size.height)
            page.apply(config: config, options: options)
            y += config.size.height + Metrics.gap
        }

        let newSize = NSSize(width: width, height: y)
        if frame.size != newSize {
            setFrameSize(newSize)
        }
        pages.first?.textView.needsDisplay = true
        needsDisplay = true
        NotificationCenter.default.post(name: .canvasGeometryChanged, object: self)
    }

    override func layout() {
        super.layout()
        layoutPages()
    }

    /// Page numbers in the gap under each sheet.
    override func draw(_ dirtyRect: NSRect) {
        guard pages.count > 1 else { return }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: NSColor.tertiaryLabelColor,
        ]
        for page in pages {
            let label = "\(page.pageNumber) / \(pages.count)" as NSString
            let size = label.size(withAttributes: attributes)
            let origin = NSPoint(
                x: page.frame.midX - size.width / 2,
                y: page.frame.maxY + (Metrics.gap - size.height) / 2
            )
            if dirtyRect.intersects(NSRect(origin: origin, size: size)) {
                label.draw(at: origin, withAttributes: attributes)
            }
        }
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
        info.topMargin = config.margins.top
        info.bottomMargin = config.margins.bottom
        info.leftMargin = config.margins.left
        info.rightMargin = config.margins.right
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

extension Notification.Name {
    static let canvasGeometryChanged = Notification.Name("BNote.canvasGeometryChanged")
}

// MARK: - Ruler

/// Horizontal ruler in centimetres with draggable left / right margin handles,
/// lined up with the sheet below it.
final class RulerView: NSView {
    weak var controller: DocumentController?
    weak var canvas: PagedDocumentView?
    weak var scrollView: NSScrollView?

    private enum Drag { case none, left, right }
    private var drag = Drag.none

    override var isFlipped: Bool { true }

    override func resetCursorRects() {
        super.resetCursorRects()
        for rect in [handleRect(edge: .left), handleRect(edge: .right)] {
            addCursorRect(rect.insetBy(dx: -4, dy: 0), cursor: .resizeLeftRight)
        }
    }

    private var config: PageConfig { canvas?.config ?? PageConfig() }
    private var zoom: CGFloat { scrollView?.magnification ?? 1 }

    /// X of the sheet's left edge in ruler coordinates.
    private var pageOrigin: CGFloat {
        guard let canvas, let scrollView else { return 0 }
        let scrolled = scrollView.contentView.bounds.origin.x
        return (canvas.pageOriginX - scrolled) * zoom
    }

    private func x(forPagePoint point: CGFloat) -> CGFloat {
        pageOrigin + point * zoom
    }

    private func pagePoint(forX x: CGFloat) -> CGFloat {
        (x - pageOrigin) / max(zoom, 0.01)
    }

    private enum Edge { case left, right }

    private func handleRect(edge: Edge) -> NSRect {
        let position = edge == .left
            ? x(forPagePoint: config.margins.left)
            : x(forPagePoint: config.size.width - config.margins.right)
        return NSRect(x: position - 5, y: bounds.height - 11, width: 10, height: 9)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        bounds.fill()

        let pageStart = x(forPagePoint: 0)
        let pageEnd = x(forPagePoint: config.size.width)
        let contentStart = x(forPagePoint: config.margins.left)
        let contentEnd = x(forPagePoint: config.size.width - config.margins.right)

        // Margin area darker, text area light.
        NSColor.tertiaryLabelColor.withAlphaComponent(0.22).setFill()
        NSRect(x: pageStart, y: bounds.height - 9, width: pageEnd - pageStart, height: 5).fill()
        NSColor.textBackgroundColor.setFill()
        NSRect(x: contentStart, y: bounds.height - 9, width: contentEnd - contentStart, height: 5).fill()

        // Ticks every half centimetre, numbered every centimetre from the text edge.
        let font = NSFont.systemFont(ofSize: 8)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.secondaryLabelColor,
        ]
        NSColor.secondaryLabelColor.setStroke()
        let ticks = NSBezierPath()
        ticks.lineWidth = 0.5

        var centimetre = 0
        var point = config.margins.left
        while point <= config.size.width - config.margins.right + 0.5 {
            let position = x(forPagePoint: point).rounded() + 0.25
            let isWhole = centimetre % 2 == 0
            ticks.move(to: NSPoint(x: position, y: bounds.height - 13))
            ticks.line(to: NSPoint(x: position, y: bounds.height - (isWhole ? 18 : 16)))
            if isWhole {
                let label = "\(centimetre / 2)" as NSString
                let size = label.size(withAttributes: attributes)
                label.draw(at: NSPoint(x: position - size.width / 2, y: 1), withAttributes: attributes)
            }
            centimetre += 1
            point += Unit.centimeter / 2
        }
        ticks.stroke()

        for edge in [Edge.left, Edge.right] {
            let rect = handleRect(edge: edge)
            let path = NSBezierPath(roundedRect: rect, xRadius: 2, yRadius: 2)
            NSColor.controlAccentColor.setFill()
            path.fill()
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if handleRect(edge: .left).insetBy(dx: -5, dy: -6).contains(point) {
            drag = .left
        } else if handleRect(edge: .right).insetBy(dx: -5, dy: -6).contains(point) {
            drag = .right
        } else {
            drag = .none
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard drag != .none, let controller else { return }
        let point = convert(event.locationInWindow, from: nil)
        var updated = config
        let value = pagePoint(forX: point.x)
        switch drag {
        case .left: updated.margins.left = round(value)
        case .right: updated.margins.right = round(config.size.width - value)
        case .none: return
        }
        updated.clampMargins()
        controller.config = updated
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        drag = .none
        window?.invalidateCursorRects(for: self)
    }
}

// MARK: - SwiftUI host

/// Ruler strip stacked on top of the scrolling page canvas.
final class EditorCanvasView: NSView {
    let scrollView = NSScrollView()
    let ruler = RulerView()
    let canvas: PagedDocumentView
    private var showRuler = true

    init(controller: DocumentController) {
        canvas = PagedDocumentView(controller: controller)
        super.init(frame: .zero)

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = NSColor.windowBackgroundColor
        scrollView.borderType = .noBorder
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 0.5
        scrollView.maxMagnification = 2.5
        scrollView.documentView = canvas
        scrollView.contentView.postsBoundsChangedNotifications = true

        ruler.controller = controller
        ruler.canvas = canvas
        ruler.scrollView = scrollView

        addSubview(ruler)
        addSubview(scrollView)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshRuler),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshRuler),
            name: .canvasGeometryChanged,
            object: canvas
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }

    override var isFlipped: Bool { true }

    @objc private func refreshRuler() {
        ruler.needsDisplay = true
    }

    func setRulerVisible(_ visible: Bool) {
        guard visible != showRuler else { return }
        showRuler = visible
        ruler.isHidden = !visible
        needsLayout = true
    }

    override func layout() {
        super.layout()
        let rulerHeight: CGFloat = showRuler ? 22 : 0
        ruler.frame = NSRect(x: 0, y: 0, width: bounds.width, height: rulerHeight)
        scrollView.frame = NSRect(x: 0, y: rulerHeight, width: bounds.width, height: bounds.height - rulerHeight)
    }
}

struct PagedEditor: NSViewRepresentable {
    @ObservedObject var controller: DocumentController

    func makeNSView(context: Context) -> EditorCanvasView {
        let view = EditorCanvasView(controller: controller)
        DispatchQueue.main.async {
            view.canvas.applyConfig(controller.config, options: controller.canvasOptions)
            view.setRulerVisible(controller.canvasOptions.showRuler)
            controller.focusEditor()
        }
        return view
    }

    func updateNSView(_ nsView: EditorCanvasView, context: Context) {
        nsView.canvas.applyConfig(controller.config, options: controller.canvasOptions)
        nsView.setRulerVisible(controller.canvasOptions.showRuler)
        nsView.ruler.needsDisplay = true
    }
}
