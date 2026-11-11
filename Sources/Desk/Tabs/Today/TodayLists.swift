import SwiftUI

/// Today's list: Focus (the agent's rows) · Due · Leftovers. Worked out by code.
struct TodayList: View {
    enum ListTab: Hashable { case focus, due, leftovers }

    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    @State private var tab = ListTab.focus
    @State private var expanded = false

    var body: some View {
        let d = store.d
        VStack(alignment: .leading, spacing: t.sp8) {
            SectionHeader(title: "Today's list") {
                CountedTabs(items: [
                    .init(id: ListTab.focus, title: "Focus", count: d.focus.count),
                    .init(id: ListTab.due, title: "Due", count: d.dueList.count),
                    .init(id: ListTab.leftovers, title: "Leftovers", count: d.leftovers.count),
                ], selection: $tab)
            }
            .padding(.bottom, t.sp2)
            switch tab {
            case .focus: focusRows(d)
            case .due: taskRows(d.dueList, d, empty: "Nothing else is due today.")
            case .leftovers: taskRows(d.leftovers, d, empty: "No leftovers. Clean slate.")
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func limit(_ count: Int) -> Int { expanded ? count : min(count, t.todayRows) }

    @ViewBuilder private func focusRows(_ d: Derived) -> some View {
        if d.focus.isEmpty {
            EmptyState(line: "No focus items in the snapshot.", hint: d.data.hint(VaultData.snapshotFile))
        }
        ForEach(d.focus.prefix(limit(d.focus.count))) { row in
            FocusRow(row: row)
        }
        if d.focus.count > limit(d.focus.count) {
            MoreLine(phrases: [.init(text: "+ "), .init(text: String(d.focus.count - limit(d.focus.count)), strong: true), .init(text: " more focus items")]) { expanded = true }
        } else if !d.dueList.isEmpty || !d.leftovers.isEmpty {
            MoreLine(phrases: [
                .init(text: "+ "), .init(text: String(d.dueList.count), strong: true), .init(text: " more due today · "),
                .init(text: String(d.leftovers.count), strong: true), .init(text: " \(d.leftovers.count == 1 ? "leftover" : "leftovers") from earlier days"),
            ]) { tab = d.dueList.isEmpty ? .leftovers : .due }
        }
    }

    @ViewBuilder private func taskRows(_ tasks: [TaskItem], _ d: Derived, empty: String) -> some View {
        if tasks.isEmpty {
            EmptyState(line: empty, hint: d.data.hint(VaultData.tasksFile))
        }
        ForEach(tasks.prefix(limit(tasks.count))) { task in
            TaskRow(task: task)
        }
        if tasks.count > limit(tasks.count) {
            MoreLine(phrases: [.init(text: "+ "), .init(text: String(tasks.count - limit(tasks.count)), strong: true), .init(text: " more")]) { expanded = true }
        }
    }
}

/// A Focus row. Email items carry an Email chip; items tied to a deadline show its days left.
struct FocusRow: View {
    @Environment(Store.self) private var store
    let row: SnapshotRow

    var body: some View {
        let d = store.d
        let done = d.isDone(row)
        let deadline = d.deadlines.first { !$0.isExam && row.title.localizedCaseInsensitiveContains($0.short) }
        let leading: RowLeading =
            done ? .tick(done: true, toggle: { store.toggleFocus(row) })
            : row.gmailThread != nil ? .symbol("envelope", .rust)
            : deadline != nil ? .symbol("pencil", .ochre)
            : .tick(done: false, toggle: { store.toggleFocus(row) })
        ListRow(leading: leading, title: row.title, subtitle: row.detail,
                selected: store.selection == .row(row.id), done: done, action: { store.open(.row(row.id)) }) { selected in
            if row.gmailThread != nil {
                Chip(text: "Email", accent: .rust, onAccent: selected)
            } else if let deadline {
                Chip(text: "\(deadline.daysLeft) d", accent: .ochre, onAccent: selected)
            }
        }
    }
}

/// A `TASKS.md` row with a tick.
struct TaskRow: View {
    @Environment(Store.self) private var store
    let task: TaskItem

    var body: some View {
        let d = store.d
        let late = task.due.map { d.cal.days(from: $0, to: d.today) } ?? 0
        ListRow(leading: .tick(done: task.done, toggle: { store.toggle(task) }), title: task.title,
                subtitle: [task.section, task.due.map { "due \(d.cal.shortDay($0))" }].compactMap { $0 }.joined(separator: " · "),
                selected: store.selection == .task(task.line), done: task.done, action: { store.open(.task(task.line)) }) { selected in
            if late > 0 && !task.done {
                Chip(text: "\(late) d late", accent: .alert, onAccent: selected)
            }
        }
    }
}

/// Important emails: sender, subject, summary and tag. As of the last run, not live.
struct EmailList: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t
    @State private var tag: Derived.EmailTag?
    @State private var expanded = false

    var body: some View {
        let d = store.d
        let rows = tag.map(d.emails) ?? d.emails
        let shown = expanded ? rows.count : min(rows.count, t.todayRows)
        VStack(alignment: .leading, spacing: t.sp8) {
            SectionHeader(title: "Important emails") {
                CountedTabs(items: [
                    .init(id: Derived.EmailTag?.none, title: "All", count: d.emails.count),
                    .init(id: Derived.EmailTag?.some(.needsReply), title: "Reply", count: d.emails(.needsReply).count),
                    .init(id: Derived.EmailTag?.some(.deadline), title: "Deadline", count: d.emails(.deadline).count),
                ], selection: $tag)
            }
            .padding(.bottom, t.sp2)
            if rows.isEmpty {
                EmptyState(line: "No important email in the last scan.", hint: d.data.hint(VaultData.snapshotFile))
            }
            ForEach(rows.prefix(shown)) { row in
                EmailRow(row: row)
            }
            if rows.count > shown {
                let hidden = rows.dropFirst(shown)
                let allFYI = hidden.allSatisfy { $0.tag == Derived.EmailTag.fyi.rawValue }
                MoreLine(phrases: [
                    .init(text: "+ "), .init(text: String(hidden.count), strong: true),
                    .init(text: " \(allFYI ? "FYI" : "more") · scanned at \(d.runStatus.lastRunText ?? "—")"),
                ]) { expanded = true }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

/// One email row. Everything in it came from email, so every string is drawn verbatim.
struct EmailRow: View {
    @Environment(Store.self) private var store
    let row: SnapshotRow

    var body: some View {
        let tag = row.tag.flatMap(Derived.EmailTag.init)
        ListRow(leading: .initials(initials(of: row.title), .steel), title: row.title,
                subtitle: [row.subject, row.detail].compactMap { $0 }.joined(separator: " — "),
                selected: store.selection == .row(row.id), action: { store.open(.row(row.id)) }) { selected in
            if let tag {
                Chip(text: tag.label, accent: tag.accent, onAccent: selected)
            }
        }
    }
}

extension Derived.EmailTag {
    var accent: Accent {
        switch self {
        case .needsReply: .rust
        case .deadline: .ochre
        case .fyi: .neutral
        }
    }
}

/// Reply drafts written by the agent. Hidden in exam mode.
struct DraftList: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t

    var body: some View {
        let d = store.d
        if !d.examMode {
            VStack(alignment: .leading, spacing: t.sp8) {
                SectionHeader(title: "Drafts", subtitle: "Nothing is sent automatically")
                if d.draftRows.isEmpty {
                    EmptyState(line: "No drafts waiting for review.")
                }
                ForEach(d.draftRows) { row in
                    ListRow(leading: .symbol("square.and.pencil", .steel), title: row.title,
                            subtitle: d.draft(for: row).map { "\($0.status.capitalized) · \($0.to)" },
                            selected: store.selection == .row(row.id), action: { store.open(.row(row.id)) }) { selected in
                        Chip(text: "Draft", accent: .steel, onAccent: selected)
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }
}

/// Threads where Jose is waiting for someone else. Hidden in exam mode.
struct WaitingList: View {
    @Environment(Store.self) private var store
    @Environment(\.theme) private var t

    var body: some View {
        let d = store.d
        if !d.examMode {
            VStack(alignment: .leading, spacing: t.sp8) {
                SectionHeader(title: "Waiting", subtitle: "On someone else")
                if d.waiting.isEmpty {
                    EmptyState(line: "Not waiting on anyone.")
                }
                ForEach(d.waiting) { row in
                    ListRow(leading: .symbol("hourglass", .ochre), title: row.title, subtitle: row.detail,
                            selected: store.selection == .row(row.id), action: { store.open(.row(row.id)) }) { selected in
                        if let since = row.when?.date {
                            Chip(text: "\(d.cal.days(from: since, to: d.today)) d", accent: .ochre, onAccent: selected)
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }
}
