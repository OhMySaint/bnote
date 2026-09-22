import Foundation

/// Rolling copies of the SwiftData store, taken at launch before the store is
/// opened. Replacing the app never touches the store — it lives in the sandbox
/// container, keyed by bundle id — but a bad schema change could, so every
/// update leaves a few restore points behind.
enum StoreBackup {
    static let keep = 5
    /// At most one backup per this interval, so relaunching all day is cheap.
    static let interval: TimeInterval = 6 * 3600

    private static let pieces = ["default.store", "default.store-wal", "default.store-shm"]

    static var supportDirectory: URL? {
        try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
    }

    static var backupsDirectory: URL? {
        supportDirectory?.appendingPathComponent("Backups", isDirectory: true)
    }

    /// Copies the store aside, then prunes to the newest `keep` folders.
    @discardableResult
    static func run(now: Date = Date()) -> URL? {
        let fm = FileManager.default
        guard let support = supportDirectory, let backups = backupsDirectory else { return nil }
        let store = support.appendingPathComponent("default.store")
        guard fm.fileExists(atPath: store.path) else { return nil }

        let existing = folders()
        if let newest = existing.first,
           let date = stamp(of: newest), now.timeIntervalSince(date) < interval {
            return nil
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let folder = backups.appendingPathComponent(formatter.string(from: now), isDirectory: true)
        do {
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            for piece in pieces {
                let source = support.appendingPathComponent(piece)
                guard fm.fileExists(atPath: source.path) else { continue }
                try fm.copyItem(at: source, to: folder.appendingPathComponent(piece))
            }
        } catch {
            try? fm.removeItem(at: folder)
            return nil
        }

        for old in folders().dropFirst(keep) {
            try? fm.removeItem(at: old)
        }
        return folder
    }

    /// Newest first.
    static func folders() -> [URL] {
        guard let backups = backupsDirectory,
              let items = try? FileManager.default.contentsOfDirectory(at: backups, includingPropertiesForKeys: nil)
        else { return [] }
        return items
            .filter { $0.hasDirectoryPath && stamp(of: $0) != nil }
            .sorted { ($0.lastPathComponent) > ($1.lastPathComponent) }
    }

    static func stamp(of folder: URL) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: folder.lastPathComponent)
    }
}
