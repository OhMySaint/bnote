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

    override func insertText(_ string: Any, replacementRange: NSRange) {
        DebugLog.write("insertText \(String(describing: string).debugDescription) repl=\(replacementRange)")
        super.insertText(string, replacementRange: replacementRange)
    }

    /// Pictures, image files and media links paste as rich content.
    override func paste(_ sender: Any?) {
        if let controller = delegate as? DocumentController,
           controller.pasteFromPasteboard(NSPasteboard.general, in: self) {
            return
        }
        super.paste(sender)
    }

    /// Right-clicking a picture offers copy / save / open link.
    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event) ?? NSMenu()
        guard let controller = delegate as? DocumentController, let container = textContainer else { return menu }
        let point = convert(event.locationInWindow, from: nil)
        let index = layoutManager?.characterIndex(for: point, in: container, fractionOfDistanceBetweenInsertionPoints: nil) ?? NSNotFound
        guard index != NSNotFound, index < (textStorage?.length ?? 0) else { return menu }

        var extras: [NSMenuItem] = []
        if textStorage?.attribute(.attachment, at: index, effectiveRange: nil) is NSTextAttachment {
            let copy = NSMenuItem(title: "Sao chép ảnh", action: #selector(copyImageAction(_:)), keyEquivalent: "")
            copy.representedObject = index
            let save = NSMenuItem(title: "Lưu ảnh…", action: #selector(saveImageAction(_:)), keyEquivalent: "")
            save.representedObject = index
            extras += [copy, save]
        }
        if let url = controller.link(at: index) {
            let open = NSMenuItem(title: "Mở liên kết trong app", action: #selector(openLinkAction(_:)), keyEquivalent: "")
            open.representedObject = url
            let browser = NSMenuItem(title: "Mở bằng trình duyệt", action: #selector(openInBrowserAction(_:)), keyEquivalent: "")
            browser.representedObject = url
            extras += [open, browser]
        }
        guard !extras.isEmpty else { return menu }
        for (offset, item) in (extras + [NSMenuItem.separator()]).enumerated() {
            item.target = self
            menu.insertItem(item, at: offset)
        }
        return menu
    }

    @objc private func copyImageAction(_ sender: NSMenuItem) {
        guard let index = sender.representedObject as? Int else { return }
        (delegate as? DocumentController)?.copyImage(at: index)
    }

    @objc private func saveImageAction(_ sender: NSMenuItem) {
        guard let index = sender.representedObject as? Int else { return }
        (delegate as? DocumentController)?.saveImage(at: index)
    }

    @objc private func openLinkAction(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        MediaViewerPanel.shared.open(url)
    }

    @objc private func openInBrowserAction(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        NSWorkspace.shared.open(url)
    }

    override func doCommand(by selector: Selector) {
        DebugLog.write("textView.doCommand \(selector)")
        super.doCommand(by: selector)
    }

    /// Composition edits do not post `textDidChange`, so the menu is refreshed here.
    override func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        DebugLog.write("setMarkedText \(String(describing: string)) sel=\(selectedRange) repl=\(replacementRange)")
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

    // MARK: Picture selection, resize handles, drop

    private static let handleSize: CGFloat = 9
    private var resizing: (index: Int, startWidth: CGFloat, startX: CGFloat)?

    private var selectedPictureRect: NSRect? {
        guard let controller = delegate as? DocumentController,
              let index = controller.selectedAttachmentIndex,
              selectedRange().length == 1, selectedRange().location == index
        else { return nil }
        return controller.attachmentRect(at: index, in: self)
    }

    private func resizeHandleRect(for rect: NSRect) -> NSRect {
        let s = Self.handleSize
        return NSRect(x: rect.maxX - s / 2, y: rect.maxY - s / 2, width: s, height: s)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let controller = delegate as? DocumentController {
            if let rect = selectedPictureRect, resizeHandleRect(for: rect).insetBy(dx: -5, dy: -5).contains(point),
               let index = controller.selectedAttachmentIndex {
                resizing = (index, rect.width, point.x)
                return
            }
            if controller.handleCheckboxClick(at: point, in: self) { return }
            // A click on a picture selects the picture, not the gap beside it.
            if event.clickCount == 1, let container = textContainer, let layoutManager {
                let local = NSPoint(x: point.x - textContainerOrigin.x, y: point.y - textContainerOrigin.y)
                var fraction: CGFloat = 0
                let index = layoutManager.characterIndex(for: local, in: container, fractionOfDistanceBetweenInsertionPoints: &fraction)
                if index < (textStorage?.length ?? 0), controller.attachment(at: index)?.image != nil,
                   let rect = controller.attachmentRect(at: index, in: self), rect.contains(point) {
                    window?.makeFirstResponder(self)
                    setSelectedRange(NSRange(location: index, length: 1))
                    return
                }
            }
        }
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let resizing, let controller = delegate as? DocumentController else {
            super.mouseDragged(with: event)
            return
        }
        let point = convert(event.locationInWindow, from: nil)
        let width = resizing.startWidth + (point.x - resizing.startX)
        controller.resizeAttachment(at: resizing.index, width: width)
    }

    override func mouseUp(with event: NSEvent) {
        if resizing != nil {
            resizing = nil
            return
        }
        super.mouseUp(with: event)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        if let rect = selectedPictureRect {
            addCursorRect(resizeHandleRect(for: rect).insetBy(dx: -4, dy: -4), cursor: .crosshair)
        }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let pasteboard = sender.draggingPasteboard
        if pasteboard.canReadObject(forClasses: [NSImage.self, NSURL.self], options: nil) { return .copy }
        return super.draggingEntered(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        // Text dragged from within the document keeps AppKit's own handling.
        let external = sender.draggingSource as? NSTextView == nil
        if external, let controller = delegate as? DocumentController {
            let point = convert(sender.draggingLocation, from: nil)
            if controller.handleDrop(pasteboard, at: point, in: self) { return true }
        }
        return super.performDragOperation(sender)
    }

    /// Shown on the first page while the document is empty.
    var placeholder: String?

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if let rect = selectedPictureRect {
            NSColor.controlAccentColor.setStroke()
            let outline = NSBezierPath(rect: rect.insetBy(dx: -1, dy: -1))
            outline.lineWidth = 2
            outline.stroke()
            let handle = NSBezierPath(ovalIn: resizeHandleRect(for: rect))
            NSColor.white.setFill()
            handle.fill()
            handle.lineWidth = 1.5
            handle.stroke()
        }
        guard let placeholder,
              textStorage?.length == 0,
              layoutManager?.textContainers.first === textContainer
        else { return }
        // Drawn with the current typing font so it matches the caret height
        // (a Heading 1 caret next to a 13pt placeholder looks broken).
        let font = (typingAttributes[.font] as? NSFont) ?? EditorDefaults.bodyFont
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
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

    func apply(config: PageConfig, options: CanvasOptions, contentRect override: NSRect? = nil) {
        self.config = config
        self.options = options
        textView.frame = override ?? contentRect
        layer?.shadowOpacity = options.continuous ? 0 : 1
        layer?.cornerRadius = options.continuous ? 0 : 2
        needsDisplay = true
        window?.invalidateCursorRects(for: self)
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        NSColor.textBackgroundColor.setFill()
        bounds.fill()

        let content = contentRect
        guard !options.continuous else { return }

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
        let label = Unit.format(value) as NSString
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
    var showMarginGuides = false
    /// Notion look: one continuous column that follows the window, no pages.
    var continuous = true
    /// Notion's "Full width": let the column use the whole window instead of the reading width.
    var fullWidth = false
}

/// Stacks pages vertically and grows or shrinks the page count as the shared
/// text storage reflows.
final class PagedDocumentView: NSView {
    enum Metrics {
        static let gap: CGFloat = 26
        static let sideInset: CGFloat = 36
        /// Side gutters as a share of the window: full width keeps 3 %, the
        /// reading layout 2.5× that.
        static let fullWidthGutterRatio: CGFloat = 0.03
        static let readingGutterRatio: CGFloat = 0.075
        static let minimumGutter: CGFloat = 16
        static let minimumColumn: CGFloat = 320
        static let columnTop: CGFloat = 8
        static let tailRoom: CGFloat = 240
    }

    /// Where the text column sits, for the header overlay to line up with.
    private(set) var contentLeading: CGFloat = 0
    private(set) var contentWidth: CGFloat = 487

    weak var controller: DocumentController?
    private(set) var pages: [PageView] = []
    private(set) var config = PageConfig()
    private var options = CanvasOptions()
    private var isPaginating = false

    /// Space reserved above the first sheet for the page header, which is a
    /// SwiftUI overlay outside the magnified scroll view (in screen points).
    private var headerHeight: CGFloat = 0

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

        if options.continuous {
            // One column, one container tall enough for anything.
            while pages.count > 1 { removeLastPage() }
            layoutPages()
            controller?.notePageCountChanged()
            return
        }

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
        let modeChanged = newOptions.continuous != options.continuous
        config = newConfig
        options = newOptions
        enclosingScrollView?.superview?.needsLayout = true

        if !options.continuous {
            for page in pages {
                page.textView.textContainer?.size = config.contentSize
                page.textView.minSize = config.contentSize
                page.textView.maxSize = config.contentSize
                page.apply(config: config, options: options)
            }
        }
        if configChanged || modeChanged {
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

    func setHeaderHeight(_ height: CGFloat) {
        guard abs(height - headerHeight) > 0.5 else { return }
        headerHeight = height
        layoutPages()
    }

    /// Re-places the sheets now; `needsLayout` alone is not honoured reliably
    /// for this plain NSView inside a magnified scroll view.
    func relayout() {
        layoutPages()
    }

    // MARK: - Geometry

    private func layoutPages() {
        if options.continuous {
            layoutContinuousColumn()
        } else {
            layoutSheets()
        }
        enclosingScrollView?.backgroundColor = options.continuous ? .textBackgroundColor : .underPageBackgroundColor
        pages.first?.textView.needsDisplay = true
        needsDisplay = true
        NotificationCenter.default.post(name: .canvasGeometryChanged, object: self)
    }

    /// Notion layout: text at its natural size in a centred column whose width
    /// follows the window up to the reading width (or the whole window when
    /// "full width" is on). Nothing is scaled and nothing is paginated.
    #if DEBUG
    /// Harness instrumentation: how often the column is re-laid out.
    static var continuousLayoutCount = 0
    #endif

    private func layoutContinuousColumn() {
        guard let page = pages.first, let layoutManager else { return }
        #if DEBUG
        Self.continuousLayoutCount += 1
        #endif
        let scrollView = enclosingScrollView
        // Window size in screen points.
        let windowWidth = scrollView?.contentView.frame.width ?? bounds.width
        let windowHeight = scrollView?.contentView.frame.height ?? bounds.height

        let ratio = options.fullWidth ? Metrics.fullWidthGutterRatio : Metrics.readingGutterRatio
        let gutter = max(Metrics.minimumGutter, (windowWidth * ratio).rounded())
        let columnVisual = max(Metrics.minimumColumn, windowWidth - gutter * 2)
        let columnWidth = columnVisual.rounded()

        // Document width: the window, or the minimum column plus gutters.
        let docWidth = max(windowWidth, columnWidth + gutter * 2).rounded()
        let columnX = ((docWidth - columnWidth) / 2).rounded()
        contentLeading = columnX
        contentWidth = columnWidth
        pageOriginX = columnX - config.margins.left

        let headerInDocument = headerHeight
        let container = page.textView.textContainer
        let tall = NSSize(width: columnWidth, height: 10_000_000)
        if container?.size != tall {
            container?.size = tall
        }
        layoutManager.ensureLayout(for: container!)
        let used = layoutManager.usedRect(for: container!).height
        let textHeight = max(used, windowHeight - headerInDocument - Metrics.columnTop) + Metrics.tailRoom

        page.textView.minSize = NSSize(width: columnWidth, height: textHeight)
        page.textView.maxSize = NSSize(width: columnWidth, height: textHeight)
        let top = headerInDocument + Metrics.columnTop
        page.pageNumber = 1
        page.frame = NSRect(x: 0, y: top, width: docWidth, height: textHeight)
        page.apply(config: config, options: options, contentRect: NSRect(x: columnX, y: 0, width: columnWidth, height: textHeight))

        let newSize = NSSize(width: docWidth, height: top + textHeight)
        if frame.size != newSize { setFrameSize(newSize) }
    }

    /// Print-preview layout: real sheets, stacked, at 1:1.
    private func layoutSheets() {
        let visibleWidth = (enclosingScrollView?.contentView.bounds.width ?? bounds.width)
        let width = max(visibleWidth, config.size.width + Metrics.sideInset * 2)
        pageOriginX = ((width - config.size.width) / 2).rounded()
        contentLeading = pageOriginX + config.margins.left
        contentWidth = config.contentSize.width

        var y = headerHeight + Metrics.gap
        for (index, page) in pages.enumerated() {
            page.pageNumber = index + 1
            page.frame = NSRect(x: pageOriginX, y: y, width: config.size.width, height: config.size.height)
            page.apply(config: config, options: options)
            y += config.size.height + Metrics.gap
        }
        let newSize = NSSize(width: width, height: y)
        if frame.size != newSize { setFrameSize(newSize) }
    }

    override func layout() {
        super.layout()
        layoutPages()
    }

    /// Page numbers in the gap under each sheet (paper mode only).
    override func draw(_ dirtyRect: NSRect) {
        guard pages.count > 1, !options.continuous else { return }
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
        let target = page.textView.convert(rect, to: self)
        // Put the heading at the top of the view, not merely somewhere visible.
        if let scrollView = enclosingScrollView {
            let clip = scrollView.contentView
            let maxY = max(0, bounds.height - clip.bounds.height)
            let y = min(max(0, target.minY - 14), maxY)
            clip.scroll(to: NSPoint(x: clip.bounds.origin.x, y: y))
            scrollView.reflectScrolledClipView(clip)
        } else {
            scrollToVisible(target)
        }
        window?.makeFirstResponder(page.textView)
        page.textView.setSelectedRange(NSRange(location: index, length: 0))
    }

    func printDocument(jobTitle: String, header: ExportHeader? = nil) {
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

        let body = controller?.attributedCopy ?? NSAttributedString()
        let printView = DocumentIO.makePrintView(
            attributed: header?.prepend(to: body, contentWidth: config.contentSize.width) ?? body,
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

// MARK: - SwiftUI host

/// Hosts the scrolling canvas and keeps the header overlay informed.
final class EditorCanvasView: NSView {
    let scrollView = NSScrollView()
    let canvas: PagedDocumentView
    private var options = CanvasOptions()
    private weak var controller: DocumentController?

    init(controller: DocumentController) {
        canvas = PagedDocumentView(controller: controller)
        self.controller = controller
        super.init(frame: .zero)

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = NSColor.underPageBackgroundColor
        scrollView.borderType = .noBorder
        scrollView.allowsMagnification = false
        scrollView.documentView = canvas
        scrollView.contentView.postsBoundsChangedNotifications = true

        addSubview(scrollView)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(geometryChanged),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(geometryChanged),
            name: .canvasGeometryChanged,
            object: canvas
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }

    override var isFlipped: Bool { true }

    @objc private func geometryChanged() {
        publishHeaderLayout()
    }

    /// True while SwiftUI is inside `updateNSView`; publishing to the header
    /// model then must wait a turn, otherwise it lands in the same frame.
    var isInsideViewUpdate = false

    /// Where the header overlay (outside the scroll view) should sit. Applied
    /// synchronously so the title moves in the very frame the column does —
    /// a one-turn delay reads as a stutter when toggling full width.
    private func publishHeaderLayout() {
        guard let layout = controller?.headerLayout else { return }
        let clip = scrollView.contentView.bounds.origin
        let leading = canvas.contentLeading - clip.x
        let width = canvas.contentWidth
        let scrollOffset = clip.y
        guard abs(layout.leading - leading) > 0.5 || abs(layout.width - width) > 0.5
            || abs(layout.scrollOffset - scrollOffset) > 0.5 else { return }
        let apply = {
            layout.leading = leading
            layout.width = width
            layout.scrollOffset = scrollOffset
        }
        if isInsideViewUpdate {
            DispatchQueue.main.async(execute: apply)
        } else {
            apply()
        }
    }

    func apply(options newOptions: CanvasOptions) {
        guard newOptions != options else { return }
        options = newOptions
        needsLayout = true
    }

    override func layout() {
        super.layout()
        scrollView.frame = bounds
        // Window resizes change the visible width the column is centred in.
        canvas.relayout()
        publishHeaderLayout()
    }
}

struct PagedEditor: NSViewRepresentable {
    @ObservedObject var controller: DocumentController
    var headerHeight: CGFloat = 0

    func makeNSView(context: Context) -> EditorCanvasView {
        let view = EditorCanvasView(controller: controller)
        view.canvas.setHeaderHeight(headerHeight)
        DispatchQueue.main.async {
            view.canvas.applyConfig(controller.config, options: controller.canvasOptions)
            view.apply(options: controller.canvasOptions)
            controller.focusEditor()
        }
        return view
    }

    func updateNSView(_ nsView: EditorCanvasView, context: Context) {
        nsView.isInsideViewUpdate = true
        defer { nsView.isInsideViewUpdate = false }
        nsView.canvas.setHeaderHeight(headerHeight)
        nsView.canvas.applyConfig(controller.config, options: controller.canvasOptions)
        nsView.apply(options: controller.canvasOptions)
    }
}
