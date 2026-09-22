import AppKit
import SwiftUI

/// Built-in gradient covers, for pages without a photo.
enum CoverStyle: String, CaseIterable, Identifiable {
    case sunrise, ocean, forest, berry, dusk, slate

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sunrise: "Sunrise"
        case .ocean: "Ocean"
        case .forest: "Forest"
        case .berry: "Berry"
        case .dusk: "Sunset"
        case .slate: "Stone"
        }
    }

    var colors: [Color] {
        switch self {
        case .sunrise: [Color(red: 1.0, green: 0.62, blue: 0.35), Color(red: 1.0, green: 0.85, blue: 0.55)]
        case .ocean: [Color(red: 0.16, green: 0.45, blue: 0.85), Color(red: 0.35, green: 0.80, blue: 0.95)]
        case .forest: [Color(red: 0.13, green: 0.50, blue: 0.35), Color(red: 0.55, green: 0.80, blue: 0.45)]
        case .berry: [Color(red: 0.55, green: 0.20, blue: 0.60), Color(red: 0.95, green: 0.45, blue: 0.65)]
        case .dusk: [Color(red: 0.20, green: 0.22, blue: 0.45), Color(red: 0.85, green: 0.45, blue: 0.55)]
        case .slate: [Color(red: 0.30, green: 0.34, blue: 0.40), Color(red: 0.62, green: 0.66, blue: 0.72)]
        }
    }

    var gradient: LinearGradient {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Rasterised gradient, for exports that need a picture.
    func image(size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        let nsColors = colors.map { NSColor($0) }
        NSGradient(colors: nsColors)?.draw(in: NSRect(origin: .zero, size: size), angle: -30)
        image.unlockFocus()
        return image
    }
}

/// Cover artwork for a page: a photo, a gradient, or nothing.
struct CoverView: View {
    let note: Note
    var cornerRadius: CGFloat = 0
    /// Overrides the stored focus while the user is dragging to reposition.
    var offsetOverride: Double?

    var body: some View {
        GeometryReader { geometry in
            Group {
                if let data = note.coverData, let image = NSImage(data: data) {
                    // Cover the banner, then slide the picture vertically by the focus value.
                    let scale = max(geometry.size.width / max(image.size.width, 1), geometry.size.height / max(image.size.height, 1))
                    let fitted = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                    let overflow = max(0, fitted.height - geometry.size.height)
                    Image(nsImage: image)
                        .resizable()
                        .frame(width: fitted.width, height: fitted.height)
                        .offset(x: (geometry.size.width - fitted.width) / 2, y: -(offsetOverride ?? note.coverOffset) * overflow)
                        .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
                } else if let style = CoverStyle(rawValue: note.coverStyle) {
                    style.gradient
                } else {
                    Color.clear
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .clipShape(.rect(cornerRadius: cornerRadius))
    }
}

extension NSImage {
    /// JPEG at a sensible size for storage; covers do not need full resolution.
    func coverData(maxWidth: CGFloat = 1600) -> Data? {
        let scale = min(1, maxWidth / max(size.width, 1))
        let target = NSSize(width: size.width * scale, height: size.height * scale)
        let scaled = NSImage(size: target)
        scaled.lockFocus()
        draw(in: NSRect(origin: .zero, size: target), from: .zero, operation: .copy, fraction: 1)
        scaled.unlockFocus()
        guard let tiff = scaled.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
    }
}
