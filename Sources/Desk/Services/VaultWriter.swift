import Foundation

/// The one place that decides what Desk may write, and writes it. One writer per file:
/// `agent/` and `nini/` belong to the agent and the Project mirror, so they are never written.
enum VaultWriter {
    static let tutoringFolder = "tutoring/"

    /// Jose's own files: ticks in `TASKS.md`, the study file and `uni/*.md`; clicks in
    /// `desk/decisions.jsonl`; `tutoring/payments.csv`. Nothing else, in either mode.
    static func isWritable(_ path: String, studyFile: String?) -> Bool {
        let parts = path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        // A plain relative path: no "", "." or ".." parts, so it cannot be spelled around the checks below.
        guard !isProtected(path), !parts.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }) else { return false }
        if path == VaultData.tasksFile || path == VaultData.decisionsFile || path == VaultData.paymentsFile { return true }
        if let studyFile, path == studyFile, path.hasSuffix(".md") { return true }
        return parts.count == 2 && parts[0] == "uni" && path.hasSuffix(".md")
    }

    /// The folders Desk never writes, whatever the letter case (the Mac's file system ignores case).
    static let protectedFolders: Set<String> = ["agent", "nini", ".git"]

    static func isProtected(_ path: String) -> Bool {
        guard let first = path.split(separator: "/", omittingEmptySubsequences: false).first else { return true }
        return protectedFolders.contains(first.lowercased())
    }

    /// `tutoring/` stays on the Mac: written to disk, never committed.
    static func isCommitted(_ path: String) -> Bool {
        !path.lowercased().hasPrefix(tutoringFolder) && !isProtected(path)
    }

    /// Live mode only. Demo never reaches this: its edits stay in memory.
    static func write(_ text: String, to path: String, in root: URL, studyFile: String?) throws {
        guard isWritable(path, studyFile: studyFile) else {
            throw Git.Failure(message: "Desk does not write \(path).")
        }
        let url = root.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        // A symlinked folder must not lead the write out of the vault or into a protected folder.
        let rootPath = root.resolvingSymlinksInPath().standardizedFileURL.path
        let folder = url.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL.path
        let inside = folder == rootPath || folder.hasPrefix(rootPath + "/")
        let relative = inside && folder != rootPath ? String(folder.dropFirst(rootPath.count + 1)) : ""
        guard inside, relative.isEmpty || !isProtected(relative) else {
            throw Git.Failure(message: "Desk does not write \(path): it resolves outside Jose's own files.")
        }
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    static func commitMessage(for path: String) -> String {
        switch path {
        case VaultData.decisionsFile: "Desk: record a decision"
        default: "Desk: tick in \(path)"
        }
    }
}
