import Foundation

/// The near-empty vault a new person starts from (Welcome → Start my own desk).
/// It is copied once into a folder they own; after that Desk treats it like any other vault.
enum StarterVault {
    static let folderName = "starter-vault"
    /// Where a new desk goes. The home folder needs no macOS permission, unlike Documents.
    static let defaultPath = "~/Desk"
    static let nameToken = "{{name}}"
    static let todayToken = "{{today}}"

    struct Failure: Error, LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static let url: URL = {
        if let bundled = Bundle.main.resourceURL?.appendingPathComponent(folderName),
           FileManager.default.fileExists(atPath: bundled.path) {
            return bundled
        }
        // Sources/Desk/Services/StarterVault.swift → the repo root.
        return URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(folderName)
    }()

    /// A folder that already holds a vault: Desk opens it instead of writing over it.
    static func isVault(_ folder: URL) -> Bool {
        FileManager.default.fileExists(atPath: folder.appendingPathComponent(VaultData.settingsFile).path)
    }

    /// Copies the starter into `folder`, which must be missing or empty, and fills in the name and today's date.
    static func create(at folder: URL, name: String, today: Date = Date(), from source: URL = url) throws {
        let files = FileManager.default
        let existing = (try? files.contentsOfDirectory(atPath: folder.path))?.filter { $0 != ".DS_Store" } ?? []
        guard existing.isEmpty else {
            throw Failure(message: "\(folder.path) already has files in it. Use “Open a folder I already have”.")
        }
        guard files.fileExists(atPath: source.path) else {
            throw Failure(message: "The starter files are missing from this copy of Desk.")
        }
        try? files.removeItem(at: folder)
        try files.createDirectory(at: folder.deletingLastPathComponent(), withIntermediateDirectories: true)
        try files.copyItem(at: source, to: folder)

        let day = DateFormatter()
        day.calendar = Calendar(identifier: .gregorian)
        day.locale = Locale(identifier: "en_US_POSIX")
        day.dateFormat = "yyyy-MM-dd"
        // The name goes into JSON, so it is escaped as JSON.
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let encoded = String(decoding: try JSONEncoder().encode(clean.isEmpty ? "there" : clean), as: UTF8.self)
        try fill(folder.appendingPathComponent(VaultData.settingsFile), "\"\(nameToken)\"", encoded)
        try fill(folder.appendingPathComponent(VaultData.tasksFile), todayToken, day.string(from: today))
    }

    private static func fill(_ file: URL, _ token: String, _ value: String) throws {
        let text = try String(contentsOf: file, encoding: .utf8)
        try text.replacingOccurrences(of: token, with: value).write(to: file, atomically: true, encoding: .utf8)
    }
}
