import XCTest
@testable import Desk

/// Writes: the allow-list, and a Live round trip against a throwaway local repo (never the real vault).
final class WriteTests: XCTestCase {
    func testOnlyJosesFilesAreWritable() {
        let study = "study/strength-of-materials.md"
        for path in ["TASKS.md", "desk/decisions.jsonl", "tutoring/payments.csv", study, "uni/alpine-bme.md"] {
            XCTAssertTrue(VaultWriter.isWritable(path, studyFile: study), path)
        }
        for path in ["agent/snapshot.json", "agent/drafts/x.md", "nini/desk.md", "projects/desk.md", "uni/../agent/snapshot.json",
                     "/etc/hosts", "desk/settings.json", "tutoring/contacts.json", "uni/a/b.md", "contacts/people.json"] {
            XCTAssertFalse(VaultWriter.isWritable(path, studyFile: study), path)
        }
        XCTAssertFalse(VaultWriter.isWritable("agent/snapshot.json", studyFile: "agent/snapshot.json"))
        XCTAssertFalse(VaultWriter.isCommitted("tutoring/payments.csv"))
        XCTAssertTrue(VaultWriter.isCommitted("TASKS.md"))
    }

    @MainActor
    func testDemoTicksStayInMemory() throws {
        let store = Store()
        let file = DemoVault.url.appendingPathComponent(VaultData.tasksFile)
        let before = try String(contentsOf: file, encoding: .utf8)
        let decisions = try String(contentsOf: DemoVault.url.appendingPathComponent(VaultData.decisionsFile), encoding: .utf8)
        store.toggle(try XCTUnwrap(store.d.dueToday.first))
        XCTAssertEqual(store.d.dueToday.count, 3)
        store.dismiss(try XCTUnwrap(store.d.toConfirm.first))
        XCTAssertEqual(store.d.toConfirm.count, 1)
        store.accept(try XCTUnwrap(store.d.toConfirm.first))
        XCTAssertEqual(store.d.toConfirm.count, 0)
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), before)
        XCTAssertEqual(try String(contentsOf: DemoVault.url.appendingPathComponent(VaultData.decisionsFile), encoding: .utf8), decisions)
        // A project checklist is read-only: the tick is refused, with a banner.
        let project = try XCTUnwrap(store.data.projects.first { !$0.items.isEmpty })
        store.toggleCheck(path: project.path, line: project.items[0].line)
        XCTAssertNotNil(store.banner)
    }

    @MainActor
    func testLiveTickCommitsAndPushes() async throws {
        let fm = FileManager.default
        let base = fm.temporaryDirectory.appendingPathComponent("desk-test-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: base) }
        let remote = base.appendingPathComponent("remote.git")
        let vault = base.appendingPathComponent("vault")
        try fm.createDirectory(at: remote, withIntermediateDirectories: true)
        try Git(root: remote).run(["init", "--bare", "--initial-branch=main"])
        try fm.copyItem(at: DemoVault.url, to: vault)
        let git = Git(root: vault)
        try git.run(["init", "--initial-branch=main"])
        for (key, value) in [("user.name", "Desk Test"), ("user.email", "desk@example.invalid"), ("commit.gpgsign", "false")] {
            try git.run(["config", key, value])
        }
        try "tutoring/\n".write(to: vault.appendingPathComponent(".gitignore"), atomically: true, encoding: .utf8)
        try git.run(["add", "-A"])
        try git.run(["commit", "-m", "Seed"])
        try git.run(["remote", "add", "origin", remote.path])
        try git.run(["push", "-u", "origin", "main"])
        let snapshot = try Data(contentsOf: vault.appendingPathComponent(VaultData.snapshotFile))

        let prefs = Preferences(defaults: nil)
        prefs.vaultPath = vault.path
        let calendar = FakeCalendar()
        let store = Store(prefs: prefs, calendar: calendar)
        XCTAssertEqual(store.mode, .live)

        // Add: the event gets the proposal's title and times, and nothing else.
        let proposal = try XCTUnwrap(store.d.toConfirm.first { $0.action == "add_event" })
        store.accept(proposal)
        XCTAssertEqual(calendar.added.map(\.title), [proposal.event?.title])
        XCTAssertEqual(calendar.added.first?.start, proposal.event?.start.date)
        XCTAssertFalse(store.d.toConfirm.contains { $0.id == proposal.id })

        let task = try XCTUnwrap(store.data.tasks.first { !$0.done })
        store.toggle(task)
        if let payment = store.data.tutoring.payments.first(where: { $0.status == .sent }) { store.markPaid(payment) }
        await store.settle()
        XCTAssertNil(store.banner)

        // The tick and the click are on disk, committed and pushed; agent/ is untouched; tutoring/ is not in git.
        XCTAssertTrue(store.data.tasks.first { $0.line == task.line }?.done == true)
        XCTAssertEqual(try git.run(["status", "--porcelain"]), "")
        XCTAssertEqual(try git.run(["rev-parse", "HEAD"]), try git.run(["rev-parse", "origin/main"]))
        let log = try git.run(["log", "--format=%s"])
        XCTAssertTrue(log.contains("Desk: tick in TASKS.md"))
        XCTAssertTrue(log.contains("Desk: record a decision"))
        XCTAssertEqual(try Data(contentsOf: vault.appendingPathComponent(VaultData.snapshotFile)), snapshot)
        XCTAssertEqual(try git.run(["log", "--format=%s", "--", "agent"]).trimmingCharacters(in: .whitespacesAndNewlines), "Seed")
        XCTAssertEqual(try git.run(["ls-files", "tutoring"]), "")
        XCTAssertTrue(try String(contentsOf: vault.appendingPathComponent(VaultData.paymentsFile), encoding: .utf8).contains("2026-10,EM"))

        // A failing sync raises the banner: never a silently stale view.
        try git.run(["remote", "set-url", "origin", base.appendingPathComponent("missing.git").path])
        store.sync()
        await store.settle()
        XCTAssertTrue(store.banner?.contains("Sync failed") == true)
    }

    @MainActor
    func testCustomiseReordersAndHides() {
        let prefs = Preferences(defaults: nil)
        let ids = TabLayout.ordered(.today, prefs: nil).map(\.id)
        prefs.move(ids[1], by: -1, tab: .today, current: ids)
        prefs.setHidden(true, section: "today.health", tab: .today)
        let layout = prefs.layouts[Tab.today.rawValue]
        XCTAssertEqual(TabLayout.ordered(.today, prefs: layout).map(\.id).prefix(2), [ids[1], ids[0]])
        XCTAssertFalse(TabLayout.arranged(.today, .main, prefs: layout).contains { $0.id == "today.health" })
        XCTAssertEqual(TabLayout.arranged(.today, .rail, prefs: layout).count, 3)
        prefs.density = .comfortable
        XCTAssertEqual(Theme(density: prefs.density).rowHeight, 60)
        prefs.resetLayout()
        XCTAssertEqual(TabLayout.ordered(.today, prefs: prefs.layouts[Tab.today.rawValue]).map(\.id), ids)
        XCTAssertEqual(prefs.density, .compact)
        // Every tab lists its sections once, with unique ids.
        for tab in Tab.eight {
            let all = TabLayout.sections(for: tab).map(\.id)
            XCTAssertFalse(all.isEmpty, tab.title)
            XCTAssertEqual(Set(all).count, all.count)
        }
    }
}

@MainActor
final class FakeCalendar: CalendarSource {
    struct Added { let title: String; let start: Date; let end: Date; let allDay: Bool }
    var added: [Added] = []
    func requestAccess() async -> Bool { true }
    func events(from start: Date, to end: Date) -> [CalEvent] {
        added.map { CalEvent(id: $0.title, calendar: "Desk", title: $0.title, start: $0.start, end: $0.end, allDay: $0.allDay) }
    }
    func add(title: String, start: Date, end: Date, allDay: Bool) throws {
        added.append(Added(title: title, start: start, end: end, allDay: allDay))
    }
}
