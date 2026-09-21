import AppKit

enum Paper: String, CaseIterable, Identifiable {
    case a4, letter, legal, a5, a3, tabloid

    var id: String { rawValue }

    var label: String {
        switch self {
        case .a4: "A4"
        case .letter: "Letter"
        case .legal: "Legal"
        case .a5: "A5"
        case .a3: "A3"
        case .tabloid: "Tabloid"
        }
    }

    /// Portrait dimensions in points.
    var portraitSize: NSSize {
        switch self {
        case .a4: NSSize(width: 595, height: 842)
        case .letter: NSSize(width: 612, height: 792)
        case .legal: NSSize(width: 612, height: 1008)
        case .a5: NSSize(width: 420, height: 595)
        case .a3: NSSize(width: 842, height: 1191)
        case .tabloid: NSSize(width: 792, height: 1224)
        }
    }

    var sizeLabel: String {
        let size = portraitSize
        return String(format: "%.1f × %.1f cm", size.width / Unit.centimeter, size.height / Unit.centimeter)
    }
}

enum PageOrientation: String, CaseIterable, Identifiable {
    case portrait, landscape

    var id: String { rawValue }

    var label: String {
        switch self {
        case .portrait: "Dọc"
        case .landscape: "Ngang"
        }
    }

    var symbol: String {
        switch self {
        case .portrait: "doc"
        case .landscape: "doc.badge.ellipsis"
        }
    }
}

enum Unit {
    static let centimeter: CGFloat = 72 / 2.54
    static let inch: CGFloat = 72

    static func centimeters(_ points: CGFloat) -> String {
        String(format: "%.2f", points / centimeter)
    }
}

struct PageMargins: Equatable {
    var top: CGFloat = 72
    var bottom: CGFloat = 72
    var left: CGFloat = 72
    var right: CGFloat = 72

    init(top: CGFloat = 72, bottom: CGFloat = 72, left: CGFloat = 72, right: CGFloat = 72) {
        self.top = top
        self.bottom = bottom
        self.left = left
        self.right = right
    }

    init(uniform: CGFloat) {
        self.init(top: uniform, bottom: uniform, left: uniform, right: uniform)
    }
}

struct MarginPreset: Identifiable {
    let label: String
    let margins: PageMargins
    var id: String { label }

    static let all: [MarginPreset] = [
        .init(label: "Hẹp — 1,27 cm", margins: PageMargins(uniform: 36)),
        .init(label: "Thường — 2,54 cm", margins: PageMargins(uniform: 72)),
        .init(label: "Rộng — 3,81 cm", margins: PageMargins(uniform: 108)),
        .init(label: "Phản chiếu — trái rộng", margins: PageMargins(top: 72, bottom: 72, left: 108, right: 72)),
    ]
}

struct PageConfig: Equatable {
    var paper: Paper = .a4
    var orientation: PageOrientation = .portrait
    var margins = PageMargins()

    var size: NSSize {
        let portrait = paper.portraitSize
        return orientation == .portrait
            ? portrait
            : NSSize(width: portrait.height, height: portrait.width)
    }

    var contentSize: NSSize {
        NSSize(
            width: max(80, size.width - margins.left - margins.right),
            height: max(80, size.height - margins.top - margins.bottom)
        )
    }

    var contentOrigin: NSPoint {
        NSPoint(x: margins.left, y: margins.top)
    }

    /// Keeps margins from swallowing the whole sheet while dragging ruler handles.
    mutating func clampMargins() {
        let limitX = size.width - 80
        let limitY = size.height - 80
        margins.left = min(max(0, margins.left), max(0, limitX - margins.right))
        margins.right = min(max(0, margins.right), max(0, limitX - margins.left))
        margins.top = min(max(0, margins.top), max(0, limitY - margins.bottom))
        margins.bottom = min(max(0, margins.bottom), max(0, limitY - margins.top))
    }
}
