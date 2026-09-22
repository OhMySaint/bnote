import Foundation

/// Which build this is. The dev build ships under its own bundle identifier,
/// so macOS gives it a separate sandbox container — its pages, settings and
/// store are completely apart from the everyday app.
enum AppFlavor {
    static var isDev: Bool {
        Bundle.main.bundleIdentifier?.hasSuffix(".dev") ?? false
    }

    /// "BNote" or "BNote Dev", taken from the bundle so the two never disagree.
    static var name: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? "BNote"
    }

    static var version: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? ""
    }
}
