import Foundation

/// The one place that decides what Desk may write, and writes it. One writer per file:
/// `agent/` and `nini/` belong to the agent and the Project mirror, so they are never written.
enum VaultWriter {
    static let tutoringFolder = "tutoring/"

    /// Jose's own files: ticks in `TASKS.md`, the study file and `uni/*.md`; clicks in
    /// `desk/decisions.jsonl`; `tutoring/payments.csv`. Nothing else, in either mode.
    static func isWritable(_ path: String, studyFile: String?) -> Bool {
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        guard !path.hasPrefix("/"), !parts.contains(".."), !parts.contains("") else { return false }
        if path == VaultData.tasksFile || path == VaultData.decisionsFile || path == VaultData.paymentsFile { return true }
        if let studyFile, path == studyFile, !studyFile.hasPrefix("agent/"), !studyFile.hasPrefix("nini/") { return true }
        return parts.count == 2 && parts[0] == "uni" && path.hasSuffix(".md")
    }

    /// `tutoring/` stays on the Mac: written to disk, never committed.
    static func isCommitted(_ path: String) -> Bool {
        !path.hasPrefix(tutoringFolder) && !path.hasPrefix("agent/")
    }

    /// Live mode only. Demo never reaches this: its edits stay in memory.
    static func write(_ text: String, to path: String, in root: URL, studyFile: String?) throws {
        guard isWritable(path, studyFile: studyFile) else {
            throw Git.Failure(message: "Desk does not write \(path).")
        }
        let url = root.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    static func commitMessage(for path: String) -> String {
        switch path {
        case VaultData.decisionsFile: "Desk: record a decision"
        default: "Desk: tick in \(path)"
        }
    }
}
