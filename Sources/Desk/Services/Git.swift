import Foundation

/// Runs `/usr/bin/git` in the vault with Jose's existing credentials. The only network access Desk has.
struct Git: Sendable {
    let root: URL

    struct Failure: Error, LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    @discardableResult
    func run(_ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", root.path] + arguments
        var environment = ProcessInfo.processInfo.environment
        // Never stop to ask for a password: a missing credential is a failure, shown in the banner.
        environment["GIT_TERMINAL_PROMPT"] = "0"
        process.environment = environment
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        process.standardInput = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            throw Failure(message: "git could not start: \(error.localizedDescription)")
        }
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let lines = output.split(whereSeparator: \.isNewline).map(String.init)
            let reason = lines.last { $0.hasPrefix("fatal:") || $0.hasPrefix("error:") } ?? lines.last ?? "exit \(process.terminationStatus)"
            throw Failure(message: "git \(arguments.first ?? ""): \(reason)")
        }
        return output
    }
}

/// The vault's git queue: one operation at a time, off the main thread.
actor VaultGit {
    private let git: Git

    init(root: URL) { git = Git(root: root) }

    /// Launch, every 15 minutes and ⌘R.
    func pull() throws {
        try git.run(["pull", "--ff-only"])
    }

    /// After a write to one of Jose's files: commit that file, `pull --rebase`, `push`.
    func commitAndSync(path: String, message: String) throws {
        precondition(VaultWriter.isCommitted(path), "Desk never commits \(path)")
        if try !git.run(["status", "--porcelain", "--", path]).isEmpty {
            try git.run(["add", "--", path])
            try git.run(["commit", "-m", message, "--", path])
        }
        do {
            try git.run(["pull", "--rebase", "--autostash"])
        } catch {
            // Leave the vault as it was rather than half-way through a rebase.
            _ = try? git.run(["rebase", "--abort"])
            throw error
        }
        try git.run(["push"])
    }
}
