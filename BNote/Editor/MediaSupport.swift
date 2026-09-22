import AppKit
import UniformTypeIdentifiers
import WebKit

/// Recognises links worth turning into rich content.
enum MediaLink {
    static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "webp", "heic", "bmp", "tiff", "tif"]

    static func youtubeID(from url: URL) -> String? {
        guard let host = url.host?.lowercased() else { return nil }
        let path = url.path
        if host.contains("youtu.be") {
            let id = path.split(separator: "/").first.map(String.init) ?? ""
            return id.isEmpty ? nil : id
        }
        guard host.contains("youtube.com") else { return nil }
        if path.hasPrefix("/watch") {
            return URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "v" }?.value
        }
        for prefix in ["/shorts/", "/embed/", "/live/"] where path.hasPrefix(prefix) {
            let id = path.dropFirst(prefix.count).split(separator: "/").first.map(String.init) ?? ""
            return id.isEmpty ? nil : id
        }
        return nil
    }

    static func embedURL(youtubeID id: String) -> URL {
        URL(string: "https://www.youtube.com/embed/\(id)?autoplay=1&rel=0")!
    }

    static func thumbnailURL(youtubeID id: String) -> URL {
        URL(string: "https://img.youtube.com/vi/\(id)/hqdefault.jpg")!
    }

    static func isImageURL(_ url: URL) -> Bool {
        imageExtensions.contains(url.pathExtension.lowercased())
    }

    static func url(fromPastedText text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.contains(" "), !trimmed.contains("\n"),
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              url.host != nil
        else { return nil }
        return url
    }
}

enum MediaFetcher {
    static func image(from url: URL) async -> NSImage? {
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return NSImage(data: data)
    }
}

enum MediaCard {
    /// Thumbnail with a play badge, so a video link reads as a video on the page.
    static func youtube(thumbnail: NSImage, width: CGFloat) -> NSImage {
        let aspect = thumbnail.size.height / max(thumbnail.size.width, 1)
        let size = NSSize(width: width, height: (width * aspect).rounded())
        let card = NSImage(size: size)
        card.lockFocus()
        NSBezierPath(roundedRect: NSRect(origin: .zero, size: size), xRadius: 10, yRadius: 10).addClip()
        thumbnail.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .copy, fraction: 1)

        let badge = NSRect(x: size.width / 2 - 34, y: size.height / 2 - 24, width: 68, height: 48)
        NSColor(red: 0.93, green: 0.11, blue: 0.14, alpha: 0.95).setFill()
        NSBezierPath(roundedRect: badge, xRadius: 14, yRadius: 14).fill()
        let triangle = NSBezierPath()
        triangle.move(to: NSPoint(x: badge.midX - 9, y: badge.midY - 12))
        triangle.line(to: NSPoint(x: badge.midX - 9, y: badge.midY + 12))
        triangle.line(to: NSPoint(x: badge.midX + 13, y: badge.midY))
        triangle.close()
        NSColor.white.setFill()
        triangle.fill()
        card.unlockFocus()
        return card
    }
}

extension NSImage {
    /// Pixel-limits a pasted picture so documents stay small; screenshots on a
    /// Retina display are otherwise several megabytes each.
    func limited(toPixelWidth maxPixels: CGFloat = 2000) -> NSImage {
        guard let tiff = tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return self }
        let pixelWidth = CGFloat(rep.pixelsWide)
        guard pixelWidth > maxPixels else { return self }
        let scale = maxPixels / pixelWidth
        let target = NSSize(width: CGFloat(rep.pixelsWide) * scale, height: CGFloat(rep.pixelsHigh) * scale)
        guard let scaled = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(target.width), pixelsHigh: Int(target.height),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return self }
        scaled.size = target
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: scaled)
        draw(in: NSRect(origin: .zero, size: target), from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        let result = NSImage(size: target)
        result.addRepresentation(scaled)
        return result
    }
}

/// In-app browser window: YouTube embeds, image links, articles. One shared
/// window, reused for every link.
final class MediaViewerPanel: NSObject, WKNavigationDelegate {
    static let shared = MediaViewerPanel()

    private var window: NSWindow?
    private var webView: WKWebView?
    private var currentURL: URL?

    func open(_ url: URL) {
        currentURL = url
        let window = existingWindow()
        window.title = url.host ?? "View"
        if let id = MediaLink.youtubeID(from: url) {
            // YouTube refuses a bare embed URL (error 153); it wants an embedding
            // page with a referrer, so wrap the player in a page of our own.
            let html = """
            <!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1">
            <style>html,body{margin:0;height:100%;background:#000;overflow:hidden}
            iframe{position:absolute;inset:0;width:100%;height:100%;border:0}</style></head>
            <body><iframe src="https://www.youtube.com/embed/\(id)?autoplay=1&rel=0&playsinline=1"
            allow="autoplay; encrypted-media; picture-in-picture; fullscreen" allowfullscreen referrerpolicy="strict-origin-when-cross-origin"></iframe></body></html>
            """
            webView?.loadHTMLString(html, baseURL: URL(string: "https://www.youtube.com/"))
        } else {
            webView?.load(URLRequest(url: url))
        }
        window.makeKeyAndOrderFront(nil)
    }

    private func existingWindow() -> NSWindow {
        if let window { return window }

        let configuration = WKWebViewConfiguration()
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.preferences.isElementFullscreenEnabled = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"
        self.webView = webView

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("BNote.MediaViewer")
        window.toolbarStyle = .unifiedCompact

        let toolbar = NSToolbar(identifier: "MediaViewerToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        window.toolbar = toolbar
        window.contentView = webView
        self.window = window
        return window
    }

    @objc private func openInBrowser() {
        guard let currentURL else { return }
        NSWorkspace.shared.open(currentURL)
    }

    @objc private func goBack() { webView?.goBack() }
    @objc private func reload() { webView?.reload() }

    /// Videos embedded in a page may try to open new windows; keep them here.
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(.allow)
    }
}

extension MediaViewerPanel: NSToolbarDelegate {
    private enum Item {
        static let back = NSToolbarItem.Identifier("back")
        static let reload = NSToolbarItem.Identifier("reload")
        static let browser = NSToolbarItem.Identifier("browser")
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Item.back, Item.reload, .flexibleSpace, Item.browser]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier identifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.target = self
        switch identifier {
        case Item.back:
            item.label = "Back"
            item.image = NSImage(systemSymbolName: "chevron.left", accessibilityDescription: nil)
            item.action = #selector(goBack)
        case Item.reload:
            item.label = "Reload"
            item.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: nil)
            item.action = #selector(reload)
        case Item.browser:
            item.label = "Open in browser"
            item.image = NSImage(systemSymbolName: "safari", accessibilityDescription: nil)
            item.action = #selector(openInBrowser)
        default:
            return nil
        }
        return item
    }
}
