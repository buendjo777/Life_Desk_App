import Foundation

/// Runs `/usr/bin/git` in the vault with Jose's existing credentials. The only network access Desk has.
struct Git: Sendable {
    let root: URL
    static let timeout: TimeInterval = 90

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
        // A git that waits for a passphrase or a dead network must not block the queue for ever.
        let watchdog = DispatchWorkItem { if process.isRunning { process.terminate() } }
        DispatchQueue.global().asyncAfter(deadline: .now() + Self.timeout, execute: watchdog)
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        process.waitUntilExit()
        watchdog.cancel()
        if process.terminationReason == .uncaughtSignal {
            throw Failure(message: "git \(arguments.first ?? "") timed out after \(Int(Self.timeout)) s")
        }
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
    /// If an earlier push failed, the clone is ahead of the remote and a fast-forward is impossible:
    /// then the unpushed Desk commits are rebased and pushed, as after a write.
    func pull() throws {
        do {
            try git.run(["pull", "--ff-only"])
        } catch {
            let ahead = (try? git.run(["rev-list", "--count", "@{u}..HEAD"]))?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let ahead, let count = Int(ahead), count > 0 else { throw error }
            try rebaseAndPush()
        }
    }

    private func rebaseAndPush() throws {
        do {
            try git.run(["pull", "--rebase", "--autostash"])
        } catch {
            // Leave the vault as it was rather than half-way through a rebase.
            _ = try? git.run(["rebase", "--abort"])
            throw error
        }
        try git.run(["push"])
    }

    /// After a write to one of Jose's files: commit that file, `pull --rebase`, `push`.
    func commitAndSync(path: String, message: String) throws {
        precondition(VaultWriter.isCommitted(path), "Desk never commits \(path)")
        if try !git.run(["status", "--porcelain", "--", path]).isEmpty {
            try git.run(["add", "--", path])
            try git.run(["commit", "-m", message, "--", path])
        }
        try rebaseAndPush()
    }
}
