import Foundation

/// Reads the Notes note titled like "Classes" through `osascript`. Only the matching note's text is fetched;
/// it goes from osascript to Desk through a pipe and is never printed. Run from Desk.app, so the Notes
/// permission belongs to Desk.
enum NotesReader {
    struct Note {
        var title: String
        var body: String
    }

    struct Fetched {
        var notes: [Note]
        var locked: Int
    }

    struct Failure: Error, LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static let timeout: TimeInterval = 180

    /// With no `title`, any note called Classes, Clases, Class or Clase (ignoring case, accents and emoji,
    /// and allowing more words after it, like "Clases 2026") is read; with `title`, only that title.
    /// Notes in Recently Deleted are skipped.
    static func fetch(title: String? = nil) throws -> Fetched {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-l", "JavaScript", "-e", script] + (title.map { [$0] } ?? [])
        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors
        process.standardInput = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            throw Failure(message: "osascript could not start.")
        }
        let watchdog = DispatchWorkItem { if process.isRunning { process.terminate() } }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: watchdog)
        let data = output.fileHandleForReading.readDataToEndOfFile()
        let stderr = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        process.waitUntilExit()
        watchdog.cancel()
        guard process.terminationStatus == 0 else {
            // Only the error number is kept: osascript's message is not shown, in case it quotes a note.
            let code = stderr.firstMatch(of: /\((-?\d+)\)/).map { String($0.1) } ?? ""
            switch code {
            case "-1743":
                throw Failure(message: "macOS did not let Desk control Notes. Allow it in System Settings → Privacy & Security → Automation → Desk → Notes, then run the import again.")
            case "-1712":
                throw Failure(message: "Notes did not answer in time (the permission prompt may still be open).")
            default:
                throw Failure(message: "Reading Notes failed (osascript exit \(process.terminationStatus)\(code.isEmpty ? "" : ", error \(code)")).")
            }
        }
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            throw Failure(message: "Notes returned data Desk could not read.")
        }
        if payload.error == "no-note" {
            // Counts only: titles are note contents.
            let looked = "Looked through \(payload.checked ?? 0) notes"
            throw Failure(message: title.map { "\(looked); none is titled “\($0)”." }
                ?? "\(looked); none is titled Classes or Clases. Run again with --note \"<the note's exact title>\".")
        }
        var fetched = Fetched(notes: [], locked: 0)
        for raw in payload.notes ?? [] {
            guard raw.locked != true, let title = raw.title, let body = raw.body else {
                fetched.locked += 1
                continue
            }
            fetched.notes.append(Note(title: title, body: body))
        }
        return fetched
    }

    private struct Payload: Decodable {
        var error: String?
        var notes: [Raw]?
        var checked: Int?
    }

    private struct Raw: Decodable {
        var title: String?
        var body: String?
        var locked: Bool?
    }

    /// JXA: reads every note's title in one request, then the text of the matching notes only.
    static let script = #"""
    function run(argv) {
      const Notes = Application('Notes');
      function norm(s) {
        return String(s).normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();
      }
      const exact = argv.length > 0 ? norm(argv[0]) : null;
      const words = ['classes', 'clases', 'class', 'clase'];
      function matches(name) {
        const n = norm(name);
        if (exact !== null) return n === exact;
        return words.some(function (w) { return n === w || n.indexOf(w + ' ') === 0; });
      }
      const all = Notes.notes;
      const names = all.name();
      const out = [];
      for (let i = 0; i < names.length; i++) {
        if (!matches(names[i])) continue;
        const note = all[i];
        let folder = '';
        try { folder = norm(note.container().name()); } catch (e) { folder = ''; }
        if (folder.indexOf('deleted') >= 0 || folder.indexOf('eliminad') >= 0) continue;
        let locked = false;
        try { locked = note.passwordProtected(); } catch (e) { locked = false; }
        if (locked) { out.push({ locked: true }); continue; }
        try { out.push({ title: names[i], body: note.plaintext() }); } catch (e) { out.push({ locked: true }); }
      }
      if (out.length === 0) return JSON.stringify({ error: 'no-note', checked: names.length });
      return JSON.stringify({ notes: out });
    }
    """#
}

/// `Desk --import-classes [--dry-run] [--note <title>] [--vault <path>]`: sorts the Classes note into
/// `tutoring/classes-review.md`. Run it through `open` so macOS attributes the Notes access to Desk.
enum ImportCommand {
    @MainActor
    static func run(_ arguments: [String]) -> Int32 {
        func value(_ flag: String) -> String? {
            arguments.firstIndex(of: flag).flatMap { $0 + 1 < arguments.count ? arguments[$0 + 1] : nil }
        }
        let dryRun = arguments.contains("--dry-run")
        let vault = value("--vault").map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath, isDirectory: true) }
            ?? Preferences(defaults: .standard).vaultURL
        let writeCheck = ClassesImport.refusal(for: vault)
        if !dryRun, let writeCheck {
            print("Not imported: \(writeCheck)")
            return 1
        }
        let data = VaultData.load(VaultReader(root: vault))
        do {
            let fetched = try NotesReader.fetch(title: value("--note"))
            if arguments.contains("--shape") {
                for note in fetched.notes { print(ClassesImport.shapeReport(note.body, title: note.title)) }
                return 0
            }
            var log = ClassesImport.Log()
            for note in fetched.notes { log.append(ClassesImport.parse(note.body, title: note.title)) }
            let result = ClassesImport.sort(log, contacts: data.tutoring.contacts, today: Date(), cal: data.cal)
            let written = dryRun ? nil : try ClassesImport.write(result, to: vault)
            print(ClassesImport.report(result, notes: fetched.notes.count, dryRun: dryRun, writeCheck: writeCheck, written: written))
            if fetched.locked > 0 { print("\(fetched.locked) matching notes are locked and were skipped.") }
            return 0
        } catch {
            print("Not imported: \(error.localizedDescription)")
            return 1
        }
    }
}
