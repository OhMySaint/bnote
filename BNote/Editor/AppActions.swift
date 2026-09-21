import Foundation

/// Bridges menu commands to the single document window.
final class AppActions {
    static let shared = AppActions()

    var newPage: (() -> Void)?
    var newSubpage: (() -> Void)?
    var deleteCurrent: (() -> Void)?
    var importDocuments: (() -> Void)?
    var export: ((DocumentFormat) -> Void)?
    var toggleOutline: (() -> Void)?
    var showPageSetup: (() -> Void)?
    var toggleFocusMode: (() -> Void)?
    var showDashboard: (() -> Void)?
    var manageTags: (() -> Void)?
    var setCoverFromFile: (() -> Void)?
    var setCoverFromClipboard: (() -> Void)?
    var removeCover: (() -> Void)?
    /// Creates a subpage of the current page and returns its link + title.
    var createLinkedSubpage: ((String) -> (title: String, url: URL)?)?
    var openPage: ((UUID) -> Void)?
    var printDocument: (() -> Void)?
}

