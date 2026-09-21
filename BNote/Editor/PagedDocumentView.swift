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
/// The dashed guides can be dragged to change the margins directly on the page.
final class PageView: NSView {
    let textView: PageTextView
    var pageNumber: Int
    weak var controller: DocumentController?
    private var config = PageConfig()
    private var options = CanvasOptions()

    enum MarginEdge { case left, right, top, bottom }
    private var dragEdge: MarginEdge?
    private var hoverEdge: MarginEdge?
    private static let grabTolerance: CGFloat = 6

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

    private var contentRect: NSRect {
        NSRect(origin: config.contentOrigin, size: config.contentSize)
    }

    func apply(config: PageConfig, options: CanvasOptions) {
        self.config = config
        self.options = options
        textView.frame = contentRect
        needsDisplay = true
        window?.invalidateCursorRects(for: self)
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        NSColor.textBackgroundColor.setFill()
        bounds.fill()

        let content = contentRect

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

            if let edge = dragEdge ?? hoverEdge {
                drawEdgeHighlight(edge, content: content, active: dragEdge != nil)
            }
        }
    }

    private func drawEdgeHighlight(_ edge: MarginEdge, content: NSRect, active: Bool) {
        let color = NSColor.controlAccentColor
        color.withAlphaComponent(active ? 0.9 : 0.6).setStroke()
        let line = NSBezierPath()
        line.lineWidth = active ? 2 : 1.5
        let value: CGFloat
        switch edge {
        case .left:
            line.move(to: NSPoint(x: content.minX, y: content.minY))
            line.line(to: NSPoint(x: content.minX, y: content.maxY))
            value = config.margins.left
        case .right:
            line.move(to: NSPoint(x: content.maxX, y: content.minY))
            line.line(to: NSPoint(x: content.maxX, y: content.maxY))
            value = config.margins.right
        case .top:
            line.move(to: NSPoint(x: content.minX, y: content.minY))
            line.line(to: NSPoint(x: content.maxX, y: content.minY))
            value = config.margins.top
        case .bottom:
            line.move(to: NSPoint(x: content.minX, y: content.maxY))
            line.line(to: NSPoint(x: content.maxX, y: content.maxY))
            value = config.margins.bottom
        }
        line.stroke()

        guard active else { return }
        let label = "\(Unit.centimeters(value)) cm" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let size = label.size(withAttributes: attributes)
        var origin: NSPoint
        switch edge {
        case .left: origin = NSPoint(x: content.minX + 8, y: content.minY + 8)
        case .right: origin = NSPoint(x: content.maxX - size.width - 20, y: content.minY + 8)
        case .top: origin = NSPoint(x: content.midX - size.width / 2, y: content.minY + 8)
        case .bottom: origin = NSPoint(x: content.midX - size.width / 2, y: content.maxY - size.height - 20)
        }
        let box = NSRect(origin: origin, size: size).insetBy(dx: -6, dy: -3)
        color.setFill()
        NSBezierPath(roundedRect: box, xRadius: 4, yRadius: 4).fill()
        label.draw(at: origin, withAttributes: attributes)
    }

    // MARK: - Direct manipulation

    private func edge(at point: NSPoint) -> MarginEdge? {
        guard options.showMarginGuides else { return nil }
        let c = contentRect
        let t = Self.grabTolerance
        let insideY = point.y >= c.minY - t && point.y <= c.maxY + t
        let insideX = point.x >= c.minX - t && point.x <= c.maxX + t
        if insideY, abs(point.x - c.minX) <= t { return .left }
        if insideY, abs(point.x - c.maxX) <= t { return .right }
        if insideX, abs(point.y - c.minY) <= t { return .top }
        if insideX, abs(point.y - c.maxY) <= t { return .bottom }
        return nil
    }

    /// Claims clicks that land on a guide so they do not reach the text view.
    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        if bounds.contains(local), edge(at: local) != nil { return self }
        return super.hitTest(point)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        guard options.showMarginGuides else { return }
        let c = contentRect
        let t = Self.grabTolerance
        addCursorRect(NSRect(x: c.minX - t, y: c.minY, width: t * 2, height: c.height), cursor: .resizeLeftRight)
        addCursorRect(NSRect(x: c.maxX - t, y: c.minY, width: t * 2, height: c.height), cursor: .resizeLeftRight)
        addCursorRect(NSRect(x: c.minX, y: c.minY - t, width: c.width, height: t * 2), cursor: .resizeUpDown)
        addCursorRect(NSRect(x: c.minX, y: c.maxY - t, width: c.width, height: t * 2), cursor: .resizeUpDown)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    override func mouseMoved(with event: NSEvent) {
        let edge = edge(at: convert(event.locationInWindow, from: nil))
        if edge != hoverEdge {
            hoverEdge = edge
            needsDisplay = true
        }
    }

    override func mouseExited(with event: NSEvent) {
        if hoverEdge != nil {
            hoverEdge = nil
            needsDisplay = true
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let edge = edge(at: point) else {
            super.mouseDown(with: event)
            return
        }
        dragEdge = edge
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragEdge, let controller else { return }
        let point = convert(event.locationInWindow, from: nil)
        var updated = config
        switch dragEdge {
        case .left: updated.margins.left = Unit.snap(point.x)
        case .right: updated.margins.right = Unit.snap(config.size.width - point.x)
        case .top: updated.margins.top = Unit.snap(point.y)
        case .bottom: updated.margins.bottom = Unit.snap(config.size.height - point.y)
        }
        updated.clampMargins()
        controller.config = updated
    }

    override func mouseUp(with event: NSEvent) {
        guard dragEdge != nil else {
            super.mouseUp(with: event)
            return
        }
        dragEdge = nil
        needsDisplay = true
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
        page.controller = controller
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

    private enum Edge { case left, right }
    private var drag: Edge?
    private var hover: Edge?

    private static let handleWidth: CGFloat = 16
    private static let handleHeight: CGFloat = 12

    override var isFlipped: Bool { true }

    override func resetCursorRects() {
        super.resetCursorRects()
        for edge in [Edge.left, .right] {
            addCursorRect(handleRect(edge: edge).insetBy(dx: -4, dy: -2), cursor: .resizeLeftRight)
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
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

    private func handleRect(edge: Edge) -> NSRect {
        let position = edge == .left
            ? x(forPagePoint: config.margins.left)
            : x(forPagePoint: config.size.width - config.margins.right)
        return NSRect(
            x: position - Self.handleWidth / 2,
            y: bounds.height - Self.handleHeight - 1,
            width: Self.handleWidth,
            height: Self.handleHeight
        )
    }

    private func edge(at point: NSPoint) -> Edge? {
        for edge in [Edge.left, .right] where handleRect(edge: edge).insetBy(dx: -4, dy: -4).contains(point) {
            return edge
        }
        return nil
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        bounds.fill()

        let pageStart = x(forPagePoint: 0)
        let pageEnd = x(forPagePoint: config.size.width)
        let contentStart = x(forPagePoint: config.margins.left)
        let contentEnd = x(forPagePoint: config.size.width - config.margins.right)
        let trackY = bounds.height - 9

        // Margin area darker, text area light.
        NSColor.tertiaryLabelColor.withAlphaComponent(0.22).setFill()
        NSRect(x: pageStart, y: trackY, width: pageEnd - pageStart, height: 5).fill()
        NSColor.textBackgroundColor.setFill()
        NSRect(x: contentStart, y: trackY, width: contentEnd - contentStart, height: 5).fill()

        // Ticks every half centimetre, numbered every centimetre from the text edge.
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 8),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]
        NSColor.secondaryLabelColor.setStroke()
        let ticks = NSBezierPath()
        ticks.lineWidth = 0.5

        var half = 0
        var point = config.margins.left
        while point <= config.size.width - config.margins.right + 0.5 {
            let position = x(forPagePoint: point).rounded() + 0.25
            let isWhole = half % 2 == 0
            ticks.move(to: NSPoint(x: position, y: bounds.height - 13))
            ticks.line(to: NSPoint(x: position, y: bounds.height - (isWhole ? 18 : 16)))
            if isWhole {
                let label = "\(half / 2)" as NSString
                let size = label.size(withAttributes: attributes)
                label.draw(at: NSPoint(x: position - size.width / 2, y: 1), withAttributes: attributes)
            }
            half += 1
            point += Unit.centimeter / 2
        }
        ticks.stroke()

        for edge in [Edge.left, .right] {
            drawHandle(edge)
        }
    }

    /// A small downward triangle, like the margin markers in word processors.
    private func drawHandle(_ edge: Edge) {
        let rect = handleRect(edge: edge)
        let active = drag == edge
        let lit = active || hover == edge

        let path = NSBezierPath()
        path.move(to: NSPoint(x: rect.minX, y: rect.minY))
        path.line(to: NSPoint(x: rect.maxX, y: rect.minY))
        path.line(to: NSPoint(x: rect.maxX, y: rect.minY + 5))
        path.line(to: NSPoint(x: rect.midX, y: rect.maxY))
        path.line(to: NSPoint(x: rect.minX, y: rect.minY + 5))
        path.close()

        NSColor.controlAccentColor.withAlphaComponent(lit ? 1 : 0.8).setFill()
        path.fill()
        if lit {
            NSColor.controlAccentColor.withAlphaComponent(0.5).setStroke()
            path.lineWidth = 1
            path.stroke()
        }

        guard active else { return }
        let value = edge == .left ? config.margins.left : config.margins.right
        let label = "\(Unit.centimeters(value)) cm" as NSString
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let size = label.size(withAttributes: labelAttributes)
        var origin = NSPoint(x: rect.midX - size.width / 2, y: 2)
        origin.x = min(max(6, origin.x), bounds.width - size.width - 6)
        let box = NSRect(origin: origin, size: size).insetBy(dx: -5, dy: -2)
        NSColor.controlAccentColor.setFill()
        NSBezierPath(roundedRect: box, xRadius: 4, yRadius: 4).fill()
        label.draw(at: origin, withAttributes: labelAttributes)
    }

    override func mouseMoved(with event: NSEvent) {
        let edge = edge(at: convert(event.locationInWindow, from: nil))
        if edge != hover {
            hover = edge
            needsDisplay = true
        }
    }

    override func mouseExited(with event: NSEvent) {
        if hover != nil {
            hover = nil
            needsDisplay = true
        }
    }

    override func mouseDown(with event: NSEvent) {
        drag = edge(at: convert(event.locationInWindow, from: nil))
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let drag, let controller else { return }
        let point = convert(event.locationInWindow, from: nil)
        var updated = config
        let value = pagePoint(forX: point.x)
        switch drag {
        case .left: updated.margins.left = Unit.snap(value)
        case .right: updated.margins.right = Unit.snap(config.size.width - value)
        }
        updated.clampMargins()
        controller.config = updated
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        drag = nil
        needsDisplay = true
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
