import Foundation

/// Runs `/usr/bin/git` in the vault with Jose's existing credentials. The only network access Desk has.
struct Git: Sendable {
    let root: URL
    static let timeout: TimeInterval = 90

    /// A vault that is a plain folder is never touched with git, so a Mac without git is never asked to install it.
    var isRepo: Bool { FileManager.default.fileExists(atPath: root.appendingPathComponent(".git").path) }
    /// A repository with nowhere to push: Desk commits, and leaves pull and push alone.
    var hasRemote: Bool {
        !((try? run(["remote"])) ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

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

    /// Why git must not be touched now: another tool's merge, rebase or command is under way, or HEAD is
    /// off a branch. Obsidian Git works in the same vault, so Desk waits instead of finishing or aborting it.
    func busyReason() -> String? {
        let gitDir = root.appendingPathComponent(".git")
        let markers = [("rebase-merge", "a rebase"), ("rebase-apply", "a rebase"), ("MERGE_HEAD", "a merge"),
                       ("CHERRY_PICK_HEAD", "a cherry-pick"), ("index.lock", "another git command")]
        for (name, what) in markers where FileManager.default.fileExists(atPath: gitDir.appendingPathComponent(name).path) {
            return "The vault is in the middle of \(what) (Obsidian Git or Terminal), so Desk didn't sync. Finish it there, then press ⌘R."
        }
        if (try? run(["symbolic-ref", "-q", "HEAD"])) == nil {
            return "The vault's HEAD is not on a branch, so Desk didn't sync. Check out main, then press ⌘R."
        }
        return nil
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
        guard git.isRepo else { return }
        // Checked before anything else: another tool's rebase is left alone even in a vault with no remote.
        try ensureFree()
        guard git.hasRemote else { return }
        do {
            // `--no-rebase`: with `pull.rebase` set, git refuses to pull while another tool has files staged,
            // even when there is nothing to pull. A fast-forward never touches those files.
            try git.run(["pull", "--ff-only", "--no-rebase"])
        } catch {
            let ahead = (try? git.run(["rev-list", "--count", "@{u}..HEAD"]))?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let ahead, let count = Int(ahead), count > 0 else { throw error }
            try rebaseAndPush()
        }
    }

    private func ensureFree() throws {
        if let reason = git.busyReason() { throw Git.Failure(message: reason) }
    }

    private func rebaseAndPush() throws {
        // Checked again right before: Desk only ever aborts a rebase it started itself.
        try ensureFree()
        do {
            try git.run(["pull", "--rebase", "--autostash"])
        } catch {
            // Leave the vault as it was rather than half-way through a rebase.
            _ = try? git.run(["rebase", "--abort"])
            throw error
        }
        try git.run(["push"])
    }

    /// After writes to Jose's files: commit each file that changed (one commit per file), then `pull --rebase`
    /// and `push` once.
    func commitAndSync(paths: [String]) throws {
        guard git.isRepo else { return }
        try ensureFree()
        for path in paths {
            precondition(VaultWriter.isCommitted(path), "Desk never commits \(path)")
            if try !git.run(["status", "--porcelain", "--", path]).isEmpty {
                try git.run(["add", "--", path])
                try git.run(["commit", "-m", VaultWriter.commitMessage(for: path), "--", path])
            }
        }
        if git.hasRemote { try rebaseAndPush() }
    }
}
