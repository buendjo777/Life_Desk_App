import Foundation

/// Reads the notes in every Notes folder named "Classes" (and its subfolders) through `osascript`.
/// The text goes from osascript to Desk through a pipe and is never printed. Run from Desk.app, so macOS
/// asks once whether Desk may control Notes.
enum NotesReader {
    struct Fetched {
        var notes: [ClassesImport.Note]
        var locked: Int
    }

    struct Failure: Error, LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static let timeout: TimeInterval = 180

    static func fetch(folder: String = "Classes") throws -> Fetched {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-l", "JavaScript", "-e", script, folder]
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
        if payload.error == "no-folder" { throw Failure(message: "There is no folder named \(folder) in Notes.") }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var fetched = Fetched(notes: [], locked: 0)
        for raw in payload.notes ?? [] {
            guard raw.locked != true, let title = raw.title, let body = raw.body,
                  let created = raw.created.flatMap(formatter.date) else {
                fetched.locked += 1
                continue
            }
            fetched.notes.append(ClassesImport.Note(folder: raw.folder, title: title, body: body, created: created))
        }
        return fetched
    }

    private struct Payload: Decodable {
        var error: String?
        var notes: [Raw]?
    }

    private struct Raw: Decodable {
        var folder: String?
        var title: String?
        var body: String?
        var created: String?
        var locked: Bool?
    }

    /// JXA: finds every folder with that name in every account and returns its notes as JSON.
    /// Locked notes come back as `{locked: true}` with no content.
    static let script = #"""
    function run(argv) {
      const Notes = Application('Notes');
      const target = (argv[0] || 'Classes').toLowerCase();
      const out = [];
      const seen = {};
      let found = 0;
      function collect(folder, rel) {
        const id = folder.id();
        if (seen[id]) return;
        seen[id] = true;
        const notes = folder.notes;
        const count = notes.length;
        if (count > 0) {
          const names = notes.name();
          const created = notes.creationDate();
          const locked = notes.passwordProtected();
          let bodies = null;
          try { bodies = notes.plaintext(); } catch (e) { bodies = null; }
          for (let i = 0; i < count; i++) {
            if (locked[i]) { out.push({ folder: rel, locked: true }); continue; }
            let body = bodies ? bodies[i] : null;
            if (body === null || body === undefined) {
              try { body = notes[i].plaintext(); } catch (e) { out.push({ folder: rel, locked: true }); continue; }
            }
            out.push({ folder: rel, title: names[i], body: body, created: created[i].toISOString() });
          }
        }
        folder.folders().forEach(function (f) { collect(f, rel ? rel + '/' + f.name() : f.name()); });
      }
      function search(folder) {
        if (folder.name().toLowerCase() === target) { found += 1; collect(folder, null); return; }
        folder.folders().forEach(search);
      }
      Notes.accounts().forEach(function (a) { a.folders().forEach(search); });
      if (found === 0) return JSON.stringify({ error: 'no-folder' });
      return JSON.stringify({ notes: out });
    }
    """#
}

/// `Desk --import-classes [--dry-run] [--vault <path>]`: imports the Classes notes into `tutoring/`.
/// Run it through `open` so macOS attributes the Notes access to Desk (see README).
enum ImportCommand {
    @MainActor
    static func run(_ arguments: [String]) -> Int32 {
        let dryRun = arguments.contains("--dry-run")
        let vault: URL
        if let flag = arguments.firstIndex(of: "--vault"), arguments.count > flag + 1 {
            vault = URL(fileURLWithPath: (arguments[flag + 1] as NSString).expandingTildeInPath, isDirectory: true)
        } else {
            vault = Preferences(defaults: .standard).vaultURL
        }
        let writeCheck = ClassesImport.refusal(for: vault)
        if !dryRun, let writeCheck {
            print("Not imported: \(writeCheck)")
            return 1
        }
        let data = VaultData.load(VaultReader(root: vault))
        do {
            let fetched = try NotesReader.fetch()
            let result = ClassesImport.run(fetched.notes, locked: fetched.locked, contacts: data.tutoring.contacts, cal: data.cal)
            let written = dryRun ? nil : try ClassesImport.write(result, to: vault, cal: data.cal)
            print(ClassesImport.report(result, dryRun: dryRun, writeCheck: writeCheck, written: written, cal: data.cal))
            return 0
        } catch {
            print("Not imported: \(error.localizedDescription)")
            return 1
        }
    }
}
