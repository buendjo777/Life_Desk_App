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
        let papers = group("Past papers").map { check -> StudyFile.Paper in
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
            lists: studyLists(lines, from: bodyStart, cal)
        )
    }

    static let studySections: Set<String> = ["Theory", "Problems", "Past papers"]

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
