import Foundation

/// The near-empty vault a new person starts from (Welcome → Start my own desk).
/// It is copied once into a folder they own; after that Desk treats it like any other vault.
enum StarterVault {
    static let folderName = "starter-vault"
    /// Where a new desk goes. The home folder needs no macOS permission, unlike Documents.
    static let defaultPath = "~/Desk"
    static let todayToken = "{{today}}"
    static let examDateToken = "{{exam_date}}"
    static let weekEndToken = "{{week_end}}"
    static let studyFile = "study/my-exam.md"
    static let studyFolder = "study"
    static let projectsFolder = "projects"
    /// The sample exam sits this many days ahead, and its first list is due in this many.
    static let examDays = 30
    static let weekDays = 6
    /// Setup → "Fill it in with Claude": the work order Claude opens with. It names the folder and the guide
    /// in it, and carries nothing about the person.
    static let claudeSeed = "Help me set up my Desk vault, the folder ~/Desk on my Mac. Its CLAUDE.md lists the file formats (also at github.com/buendjo777/Life_Desk_App, starter-vault/CLAUDE.md). Ask me what I study, my projects and my deadlines, one question at a time, then give me each file to save."

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
    static func create(at folder: URL, name: String, tabs: Set<Tab> = Tab.starter, today: Date = Date(), from source: URL = url) throws {
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
        // Settings are written as JSON, so the name is escaped as JSON.
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var settings: [String: Any] = ["name": clean.isEmpty ? "there" : clean, "currency": "EUR"]
        if tabs.contains(.studying) { settings["exam"] = ["title": "My exam", "file": studyFile] }
        try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
            .write(to: folder.appendingPathComponent(VaultData.settingsFile))
        try fill(folder.appendingPathComponent(VaultData.tasksFile), todayToken, day.string(from: today))

        // Only the tabs that were chosen get their sample files.
        if tabs.contains(.studying) {
            let study = folder.appendingPathComponent(studyFile)
            try fill(study, examDateToken, day.string(from: today.addingTimeInterval(Double(examDays) * 86_400)))
            try fill(study, weekEndToken, day.string(from: today.addingTimeInterval(Double(weekDays) * 86_400)))
        } else {
            try files.removeItem(at: folder.appendingPathComponent(studyFolder))
        }
        if !tabs.contains(.projects) { try files.removeItem(at: folder.appendingPathComponent(projectsFolder)) }
    }

    private static func fill(_ file: URL, _ token: String, _ value: String) throws {
        let text = try String(contentsOf: file, encoding: .utf8)
        try text.replacingOccurrences(of: token, with: value).write(to: file, atomically: true, encoding: .utf8)
    }
}
