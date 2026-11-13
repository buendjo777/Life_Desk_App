import Foundation

/// The internship board and the contacts board, both exported by Jose's boards.
extension Parse {
    /// The Internship Target Board's own export (`internships/board.json`): its "openings" (live postings) become
    /// Apply now and its "targets" (companies and labs) the rest of the list. Field names follow the board's
    /// collections; anything else is ignored, and an opening needs only a company.
    static func board(_ text: String, _ cal: DeskCalendar) -> [Target]? {
        guard let root = (try? JSONSerialization.jsonObject(with: Data(text.utf8))) as? [String: Any] else { return nil }
        func docs(_ key: String) -> [[String: Any]] {
            if let list = root[key] as? [[String: Any]] { return list }
            // A collection exported as {id: document}.
            let byID = root[key] as? [String: [String: Any]] ?? [:]
            return byID.keys.sorted().map { id in byID[id, default: [:]].merging(["id": id]) { kept, _ in kept } }
        }
        func target(_ doc: [String: Any], index: Int, list: TargetList) -> Target? {
            guard let company = string(doc, "company", "name", "organisation", "organization", "org", "lab") else { return nil }
            let raw = string(doc, "status")
            let notes = string(doc, "notes", "note")
            // A target has no job title: its track and kind ("MedTech · Company") say what it is.
            let role = string(doc, "title", "role", "position")
                ?? [string(doc, "track"), string(doc, "kind")].compactMap { $0 }.joined(separator: " · ").nilIfEmpty
            return Target(
                id: "\(list.rawValue)-\(string(doc, "id") ?? String(index))", company: company,
                role: role, city: string(doc, "location", "place", "city"), country: string(doc, "country"),
                list: list, status: TargetStatus(boardWord: raw ?? ""), graduateOk: string(doc, "eligType", "elig_type").map { $0.lowercased() == "graduate" },
                deadline: string(doc, "deadline", "closes").flatMap { looseDate($0, cal) },
                next: notes.map { String($0.split(separator: "\n").first ?? "") }, url: string(doc, "url", "link", "careers", "website"),
                statusLabel: raw, start: string(doc, "start"), duration: string(doc, "duration"), language: string(doc, "language"),
                eligibility: string(doc, "eligibility"), fit: string(doc, "fit", "why"), notes: notes,
                priority: string(doc, "priority"), order: string(doc, "order", "placeOrder").flatMap(Double.init) ?? Double(index),
                sourceID: string(doc, "id"), added: string(doc, "added").flatMap { day($0, cal) }
            )
        }
        let openings = docs("openings").enumerated().compactMap { target($0.element, index: $0.offset, list: .applyNow) }
            .sorted { ($0.order ?? 0) < ($1.order ?? 0) }
        let targets = docs("targets").enumerated().compactMap { target($0.element, index: $0.offset, list: .target) }
        return openings + targets
    }

    /// Sets one entry's status in `internships/board.json` by rewriting only its `"status"` line, so the file keeps
    /// its layout and Desk's edit merges cleanly with the Monday scan's additions. `nil` when the entry is not found.
    static func setBoardStatus(_ text: String, id: String, status: String) -> String? {
        func quoted(_ value: String) -> String {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .withoutEscapingSlashes
            return (try? encoder.encode(value)).map { String(decoding: $0, as: UTF8.self) } ?? "\"\""
        }
        var lines = splitLines(text)
        let idKey = "\"id\": \(quoted(id))"
        guard let start = lines.firstIndex(where: { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed == idKey || trimmed == idKey + ","
        }) else { return nil }
        let indent = lines[start].prefix { $0 == " " }.count
        // The entry's keys sit at its indent; a shallower line closes it. Look both ways from the id.
        var range: [Int] = []
        var up = start - 1
        while up >= 0, lines[up].prefix(while: { $0 == " " }).count >= indent { range.append(up); up -= 1 }
        var down = start + 1
        while down < lines.count, lines[down].prefix(while: { $0 == " " }).count >= indent { range.append(down); down += 1 }
        guard let line = range.first(where: { lines[$0].prefix(while: { $0 == " " }).count == indent
                                         && lines[$0].trimmingCharacters(in: .whitespaces).hasPrefix("\"status\":") }) else { return nil }
        let comma = lines[line].trimmingCharacters(in: .whitespaces).hasSuffix(",") ? "," : ""
        lines[line] = String(repeating: " ", count: indent) + "\"status\": \(quoted(status))" + comma
        return lines.joined(separator: "\n")
    }

    /// The contacts board (`contacts/board.json`): one person per entry, grouped by programme (or university).
    static func contactsBoard(_ text: String, _ cal: DeskCalendar) -> [Person]? {
        guard let root = (try? JSONSerialization.jsonObject(with: Data(text.utf8))) as? [String: Any],
              let docs = root["contacts"] as? [[String: Any]] else { return nil }
        return docs.enumerated().compactMap { index, doc -> Person? in
            guard let id = string(doc, "id"), let name = string(doc, "name") else { return nil }
            let words = string(doc, "status") ?? "Not contacted"
            let notes = string(doc, "notes")
            let order = string(doc, "progOrder").flatMap(Double.init) ?? 100 + (string(doc, "uniOrder").flatMap(Double.init) ?? Double(index))
            return Person(
                id: id, name: name, programme: string(doc, "prog") ?? string(doc, "uni"), role: string(doc, "role"),
                status: PersonStatus(boardWord: words), lastContact: nil, next: notes.map { String($0.split(separator: "\n").first ?? "") },
                statusLabel: words, university: string(doc, "uni"), lab: string(doc, "lab"), why: string(doc, "why"),
                paper: string(doc, "paper"), contactRoute: string(doc, "contact"), notes: notes, url: string(doc, "url"),
                priority: string(doc, "priority"), order: order, sourceID: id
            )
        }
    }
}
