import AppKit
import SwiftUI

/// Built-in gradient covers, for pages without a photo.
enum CoverStyle: String, CaseIterable, Identifiable {
    case sunrise, ocean, forest, berry, dusk, slate

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sunrise: "Bình minh"
        case .ocean: "Đại dương"
        case .forest: "Rừng"
        case .berry: "Mọng"
        case .dusk: "Hoàng hôn"
        case .slate: "Đá"
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
}

/// Cover artwork for a page: a photo, a gradient, or nothing.
struct CoverView: View {
    let note: Note
    var cornerRadius: CGFloat = 0

    var body: some View {
        Group {
            if let data = note.coverData, let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let style = CoverStyle(rawValue: note.coverStyle) {
                style.gradient
            } else {
                Color.clear
            }
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
