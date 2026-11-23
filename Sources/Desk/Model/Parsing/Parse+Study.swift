import Foundation

/// Jose's own files: tasks, the study file, projects, uni programmes, deadlines and agent drafts.
extension Parse {
    /// `TASKS.md`: checkboxes under `##` sections, due dates as `📅 YYYY-MM-DD`.
    static func tasks(_ text: String, _ cal: DeskCalendar) -> [TaskItem] {
        checks(splitLines(text)).map { section, check in
            var title = check.title
            var due: Date?
            if let match = title.firstMatch(of: /\s*📅\s*(\d{4}-\d{2}-\d{2})/) {
                due = day(String(match.1), cal)
                title.removeSubrange(match.range)
            }
            return TaskItem(title: title.trimmingCharacters(in: .whitespaces), section: section, done: check.done, due: due, line: check.line)
        }
    }

    /// More papers a day than anyone sits; keeps arithmetic on file content bounded.
    static let maxPlanPerDay = 50

    /// The study file: front matter, `## Theory`, `## Problems` and `## Past papers`.
    static func study(_ text: String, _ cal: DeskCalendar) -> StudyFile? {
        let lines = splitLines(text)
        let (fields, bodyStart) = frontMatter(lines)
        let all = checks(lines, from: bodyStart)
        guard !fields.isEmpty || !all.isEmpty else { return nil }
        func group(_ name: String) -> [Check] { all.filter { $0.section == name }.map(\.check) }
        let lists = studyLists(lines, from: bodyStart, cal)
        // Papers may also sit in a list, as a `### Past papers` group (numbered or not), so they show as overdue there.
        let listed = lists.flatMap(\.groups).filter(isPapersGroup).flatMap(\.items)
        let papers = (group("Past papers") + listed).map { check -> StudyFile.Paper in
            // "June 2025 — 2026-11-08 — 6.5/10"; an unticked paper is the title alone.
            let parts = check.title.components(separatedBy: " — ").map { $0.trimmingCharacters(in: .whitespaces) }
            let score = parts.dropFirst().compactMap { $0.wholeMatch(of: /([\d.]+)\s*\/\s*([\d.]+)/) }.first
            return StudyFile.Paper(
                title: parts[0], done: check.done,
                date: parts.dropFirst().compactMap { day($0, cal) }.first,
                score: score.flatMap { Double($0.1) }, outOf: score.flatMap { Double($0.2) },
                line: check.line
            )
        }
        return StudyFile(
            exam: fields["exam"] ?? "", date: day(fields["date"], cal),
            planPerDay: min(maxPlanPerDay, max(0, fields["plan_per_day"].flatMap(Int.init) ?? 0)), planStart: day(fields["plan_start"], cal),
            theory: group("Theory"), problems: group("Problems"), papers: papers,
            lists: lists,
            counts: studyCounts(fields["counts"]),
            review: studyReview(lines, from: bodyStart)
        )
    }

    /// `## Review`: each checkbox is a concept, and the indented bullets under it are its notes.
    static func studyReview(_ lines: [String], from start: Int) -> [StudyFile.Concept] {
        var concepts: [StudyFile.Concept] = []
        var inReview = false
        for index in lines.indices.dropFirst(start) {
            let line = lines[index]
            if let title = heading(line) {
                inReview = title == "Review"
            } else if inReview, let box = checkbox(line) {
                concepts.append(StudyFile.Concept(check: Check(title: box.title, done: box.done, line: index), notes: []))
            } else if inReview, !concepts.isEmpty, let note = reviewNote(line) {
                concepts[concepts.count - 1].notes.append(note)
            }
        }
        return concepts
    }

    /// "  - Practise: sheet 2" → "Practise: sheet 2". Only an indented bullet is a note.
    private static func reviewNote(_ line: String) -> String? {
        guard line.first?.isWhitespace == true else { return nil }
        let rest = line.drop(while: \.isWhitespace)
        guard let bullet = rest.first, "-*·".contains(bullet) else { return nil }
        let text = rest.dropFirst().trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? nil : text
    }

    /// More extra figures than the exam card has room for.
    static let maxStudyCounts = 4

    /// `Carnicero = Hoja, Vídeos = Sesión` → caption and title prefix pairs; malformed pairs are skipped.
    static func studyCounts(_ field: String?) -> [StudyFile.Count] {
        let pairs = (field ?? "").split(separator: ",").compactMap { pair -> StudyFile.Count? in
            let sides = pair.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard sides.count == 2, !sides[0].isEmpty, !sides[1].isEmpty else { return nil }
            return StudyFile.Count(caption: sides[0], prefix: sides[1])
        }
        return Array(pairs.prefix(maxStudyCounts))
    }

    static let studySections: Set<String> = ["Theory", "Problems", "Past papers", "Review"]

    /// "Past papers", "6 · Past papers": a list group that holds the paper plan.
    static func isPapersGroup(_ group: StudyList.Group) -> Bool {
        group.title.wholeMatch(of: /(?:\d+\s*·\s*)?Past papers/) != nil
    }

    /// The study file's own lists: each other `##` section with checkboxes, its `###` headings as groups.
    /// "This weekend — due 2026-11-15" gives the title "This weekend" and the due day.
    static func studyLists(_ lines: [String], from start: Int, _ cal: DeskCalendar) -> [StudyList] {
        var lists: [StudyList] = []
        var inList = false
        for index in lines.indices.dropFirst(start) {
            let line = lines[index]
            if let title = heading(line) {
                inList = !studySections.contains(title)
                if inList { lists.append(studyList(title, line: index, cal)) }
            } else if inList, let title = heading(line, level: 3) {
                lists[lists.count - 1].groups.append(StudyList.Group(title: title, items: [], line: index))
            } else if inList, let box = checkbox(line) {
                let list = lists.count - 1
                if lists[list].groups.isEmpty {
                    lists[list].groups.append(StudyList.Group(title: lists[list].title, items: [], line: index))
                }
                lists[list].groups[lists[list].groups.count - 1].items.append(Check(title: box.title, done: box.done, line: index))
            }
        }
        return lists.compactMap { list in
            var list = list
            list.groups.removeAll { $0.items.isEmpty }
            return list.groups.isEmpty ? nil : list
        }
    }

    private static func studyList(_ heading: String, line: Int, _ cal: DeskCalendar) -> StudyList {
        guard let match = heading.firstMatch(of: /\s*[—–-]*\s*\b[Dd]ue\s+(.+)$/) else {
            return StudyList(title: heading, due: nil, groups: [], line: line)
        }
        let title = heading[..<match.range.lowerBound].trimmingCharacters(in: .whitespaces)
        return StudyList(title: title.isEmpty ? heading : title, due: looseDate(String(match.1), cal)?.date, groups: [], line: line)
    }

    static func project(path: String, _ text: String, _ cal: DeskCalendar) -> Project? {
        let lines = splitLines(text)
        let (fields, bodyStart) = frontMatter(lines)
        guard let title = fields["title"], let status = ProjectStatus(rawValue: fields["status"] ?? "") else { return nil }
        return Project(
            path: path, title: title, status: status, next: fields["next"] ?? "",
            nextDate: day(fields["next_date"], cal), doc: fields["doc"],
            items: checks(lines, from: bodyStart).map(\.check)
        )
    }

    static func uni(path: String, _ text: String) -> UniProgramme? {
        let lines = splitLines(text)
        let (fields, bodyStart) = frontMatter(lines)
        guard let title = fields["title"] else { return nil }
        return UniProgramme(
            path: path, title: title, deadlineRow: fields["deadline_row"] ?? "",
            comparisonHeading: fields["comparison_heading"] ?? "",
            items: checks(lines, from: bodyStart).map(\.check)
        )
    }

    /// `Masters/Deadlines 2027.md`: programme → deadline, keyed by `nameKey`. The date is in a "Closes"
    /// (or "Deadline") column. This doc is the master for programme deadlines.
    static func masterDeadlines(_ text: String, _ cal: DeskCalendar) -> [String: Stamp] {
        var result: [String: Stamp] = [:]
        for row in table(text) {
            guard let programme = row["Programme"], let raw = row["Closes"] ?? row["Deadline"],
                  let deadline = looseDate(raw, cal) else { continue }
            result[nameKey(programme)] = deadline
        }
        return result
    }

    /// A draft: front matter `to, thread, status, created`, then the body.
    static func draft(path: String, _ text: String, _ cal: DeskCalendar) -> Draft? {
        let lines = splitLines(text)
        let (fields, bodyStart) = frontMatter(lines)
        guard bodyStart > 0 else { return nil }
        return Draft(
            path: path, to: fields["to"] ?? "", thread: fields["thread"] ?? "",
            status: fields["status"] ?? "unreviewed", created: day(fields["created"], cal),
            body: lines[bodyStart...].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}
