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

enum MeasurementUnit: String, CaseIterable, Identifiable {
    case inch, centimeter

    var id: String { rawValue }

    var label: String {
        switch self {
        case .inch: "in"
        case .centimeter: "cm"
        }
    }

    var points: CGFloat {
        switch self {
        case .inch: 72
        case .centimeter: 72 / 2.54
        }
    }

    /// Drag snapping step: 1/8 in or 1/4 cm.
    var snapStep: CGFloat {
        switch self {
        case .inch: 72 / 8
        case .centimeter: 72 / 2.54 / 4
        }
    }
}

/// App-wide defaults for new pages; the inspector still overrides per page.
enum Defaults {
    static let unitKey = "unit"
    static let marginKey = "defaultMarginPoints"
    static let paperKey = "defaultPaper"
    static let orientationKey = "defaultOrientation"
    static let fullWidthKey = "fullWidth"
    static let gridKey = "showGrid"
    static let guidesKey = "showMarginGuides"
    static let continuousKey = "continuousLayout"

    static func register() {
        UserDefaults.standard.register(defaults: [
            unitKey: MeasurementUnit.inch.rawValue,
            marginKey: 54.0, // 0.75 in
            paperKey: Paper.a4.rawValue,
            orientationKey: PageOrientation.portrait.rawValue,
            fullWidthKey: false,
            gridKey: false,
            guidesKey: false,
            continuousKey: true,
        ])
    }

    static var unit: MeasurementUnit {
        MeasurementUnit(rawValue: UserDefaults.standard.string(forKey: unitKey) ?? "") ?? .inch
    }

    static var marginPoints: CGFloat {
        let value = UserDefaults.standard.double(forKey: marginKey)
        return value > 0 ? value : 54
    }

    static var pageConfig: PageConfig {
        PageConfig(
            paper: Paper(rawValue: UserDefaults.standard.string(forKey: paperKey) ?? "") ?? .a4,
            orientation: PageOrientation(rawValue: UserDefaults.standard.string(forKey: orientationKey) ?? "") ?? .portrait,
            margins: PageMargins(uniform: marginPoints)
        )
    }

    static var canvasOptions: CanvasOptions {
        let d = UserDefaults.standard
        return CanvasOptions(
            showGrid: d.bool(forKey: gridKey),
            showMarginGuides: d.bool(forKey: guidesKey),
            continuous: d.object(forKey: continuousKey) == nil ? true : d.bool(forKey: continuousKey),
            fullWidth: d.bool(forKey: fullWidthKey)
        )
    }
}

enum Unit {
    static let centimeter: CGFloat = 72 / 2.54
    static let inch: CGFloat = 72

    static var current: MeasurementUnit { Defaults.unit }

    /// "0,75 in" / "1,91 cm" in the unit the user chose.
    static func format(_ points: CGFloat, unit: MeasurementUnit = current) -> String {
        let value = points / unit.points
        let text = unit == .inch ? String(format: "%.2f", value) : String(format: "%.2f", value)
        return "\(text.replacingOccurrences(of: ".", with: ",")) \(unit.label)"
    }

    static func centimeters(_ points: CGFloat) -> String {
        String(format: "%.2f", points / centimeter)
    }

    /// Snaps a drag to the unit's step so values stay tidy.
    static func snap(_ points: CGFloat, unit: MeasurementUnit = current) -> CGFloat {
        let step = unit.snapStep
        return max(0, (points / step).rounded() * step)
    }
}

struct PageMargins: Equatable {
    var top: CGFloat = 54
    var bottom: CGFloat = 54
    var left: CGFloat = 54
    var right: CGFloat = 54

    init(top: CGFloat = 54, bottom: CGFloat = 54, left: CGFloat = 54, right: CGFloat = 54) {
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
    let shortLabel: String
    let label: String
    let margins: PageMargins
    var id: String { label }

    static let all: [MarginPreset] = [
        .init(shortLabel: "Hẹp", label: "Hẹp — lề 0,5 in", margins: PageMargins(uniform: 36)),
        .init(shortLabel: "Thường", label: "Thường — lề 0,75 in", margins: PageMargins(uniform: 54)),
        .init(shortLabel: "Thoáng", label: "Thoáng — lề 1 in", margins: PageMargins(uniform: 72)),
        .init(shortLabel: "Đóng gáy", label: "Đóng gáy — lề trái 1,25 in", margins: PageMargins(top: 54, bottom: 54, left: 90, right: 54)),
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
