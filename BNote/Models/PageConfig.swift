import AppKit

enum Paper: String, CaseIterable, Identifiable {
    case a4, letter, legal, a5

    var id: String { rawValue }

    var label: String {
        switch self {
        case .a4: "A4"
        case .letter: "Letter"
        case .legal: "Legal"
        case .a5: "A5"
        }
    }

    var size: NSSize {
        switch self {
        case .a4: NSSize(width: 595, height: 842)
        case .letter: NSSize(width: 612, height: 792)
        case .legal: NSSize(width: 612, height: 1008)
        case .a5: NSSize(width: 420, height: 595)
        }
    }
}

struct MarginPreset: Identifiable {
    let label: String
    let value: CGFloat
    var id: String { label }

    static let all: [MarginPreset] = [
        .init(label: "Hẹp (1,27 cm)", value: 36),
        .init(label: "Thường (2,54 cm)", value: 72),
        .init(label: "Rộng (3,81 cm)", value: 108),
    ]
}

struct PageConfig: Equatable {
    var paper: Paper = .a4
    var margin: CGFloat = 72

    var size: NSSize { paper.size }

    var contentSize: NSSize {
        NSSize(
            width: max(120, size.width - margin * 2),
            height: max(120, size.height - margin * 2)
        )
    }
}
