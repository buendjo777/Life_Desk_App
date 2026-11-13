import XCTest
@testable import Desk

/// Writes: the allow-list, and a Live round trip against a throwaway local repo (never the real vault).
final class WriteTests: XCTestCase {
    func testOnlyJosesFilesAreWritable() {
        let study = "study/strength-of-materials.md"
        for path in ["TASKS.md", "desk/decisions.jsonl", "tutoring/payments.csv", study, "uni/alpine-bme.md", "internships/board.json",
                     "tutoring/contacts.json", "tutoring/students.md"] {
            XCTAssertTrue(VaultWriter.isWritable(path, studyFile: study), path)
        }
        for path in ["agent/snapshot.json", "agent/drafts/x.md", "nini/desk.md", "projects/desk.md", "uni/../agent/snapshot.json",
                     "/etc/hosts", "desk/settings.json", "tutoring/lessons.csv", "uni/a/b.md", "contacts/people.json"] {
            XCTAssertFalse(VaultWriter.isWritable(path, studyFile: study), path)
        }
        XCTAssertFalse(VaultWriter.isWritable("agent/snapshot.json", studyFile: "agent/snapshot.json"))
        XCTAssertFalse(VaultWriter.isCommitted("tutoring/payments.csv"))
        XCTAssertFalse(VaultWriter.isCommitted("tutoring/contacts.json"))
        XCTAssertTrue(VaultWriter.isCommitted("TASKS.md"))
    }

    /// Tests and snapshots must never reach the real vault, whatever exists on this Mac.
    @MainActor
    func testAStoreWithoutStoredPreferencesIsAlwaysDemo() {
        let prefs = Preferences(defaults: nil)
        XCTAssertFalse(prefs.wantsLive)
        XCTAssertEqual(prefs.vaultPath, Preferences.defaultVaultPath)
        XCTAssertEqual(Store().mode, .demo)
        XCTAssertEqual(Store(prefs: prefs).vaultName, "demo-vault")
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
        // A student's parent, phone and subject are set from Desk, in memory in Demo.
        store.updateContact("AB", parent: "Marta López", phone: "+34 600 111 222")
        store.updateStudent("AB", subject: "Maths II and Physics")
        XCTAssertEqual(store.data.tutoring.contacts["AB"]?.parent, "Marta López")
        XCTAssertEqual(store.data.tutoring.contacts["AB"]?.phone, "+34 600 111 222")
        XCTAssertEqual(store.d.student("AB")?.subject, "Maths II and Physics")
        XCTAssertEqual(store.d.student("AB")?.rate, 25, "the rate is kept")
        // An internship status is set from Desk, in memory in Demo.
        let opening = try XCTUnwrap(store.d.applyNow.first { $0.status == "open" })
        store.setTargetStatus(opening, to: "Applied")
        XCTAssertEqual(store.data.targets?.first { $0.id == opening.id }?.statusLabel, "Applied")
        XCTAssertEqual(store.d.targets(status: "applied").count, 3)
        // A list item in the study file ticks like a topic.
        let list = try XCTUnwrap(store.d.openLists.first)
        let item = try XCTUnwrap(list.open.first)
        store.toggleCheck(path: try XCTUnwrap(store.data.settings.exam?.file), line: item.line)
        XCTAssertTrue(store.d.study?.lists.first?.items.first { $0.line == item.line }?.done == true)
        // A project checklist is read-only: the tick is refused, with a banner.
        let project = try XCTUnwrap(store.data.projects.first { !$0.items.isEmpty })
        store.toggleCheck(path: project.path, line: project.items[0].line)
        XCTAssertNotNil(store.banner)
    }

    /// A copy of the demo vault in a throwaway git repo with a local "remote": never the real vault.
    private func liveVault() throws -> (base: URL, vault: URL, git: Git) {
        let fm = FileManager.default
        let base = fm.temporaryDirectory.appendingPathComponent("desk-test-\(UUID().uuidString)")
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
        return (base, vault, git)
    }

    @MainActor
    func testLiveTickCommitsAndPushes() async throws {
        let (base, vault, git) = try liveVault()
        defer { try? FileManager.default.removeItem(at: base) }
        let snapshot = try Data(contentsOf: vault.appendingPathComponent(VaultData.snapshotFile))

        let prefs = Preferences(defaults: nil)
        prefs.vaultPath = vault.path
        prefs.wantsLive = true
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

    /// Ticks show at once, even while a sync is running, and quick ticks reach the remote in one commit and one push.
    @MainActor
    func testTicksShowAtOnceAndSyncTogether() async throws {
        let (base, vault, git) = try liveVault()
        defer { try? FileManager.default.removeItem(at: base) }
        let prefs = Preferences(defaults: nil)
        prefs.vaultPath = vault.path
        prefs.wantsLive = true
        let store = Store(prefs: prefs, calendar: FakeCalendar())
        let open = store.data.tasks.filter { !$0.done }
        XCTAssertGreaterThanOrEqual(open.count, 2)
        // A sync is running, so the writes wait for it, but the view shows both ticks straight away.
        store.sync()
        store.toggle(open[0])
        store.toggle(open[1])
        XCTAssertTrue(store.data.tasks.first { $0.line == open[0].line }?.done == true)
        XCTAssertTrue(store.data.tasks.first { $0.line == open[1].line }?.done == true)
        await store.settle()
        XCTAssertNil(store.banner)
        let onDisk = Parse.tasks(try String(contentsOf: vault.appendingPathComponent(VaultData.tasksFile), encoding: .utf8), store.cal)
        XCTAssertTrue(onDisk.first { $0.line == open[0].line }?.done == true)
        XCTAssertTrue(onDisk.first { $0.line == open[1].line }?.done == true)
        XCTAssertEqual(try git.run(["status", "--porcelain"]), "")
        XCTAssertEqual(try git.run(["rev-parse", "HEAD"]), try git.run(["rev-parse", "origin/main"]))
        let ticks = try git.run(["log", "--format=%s", "origin/main"]).components(separatedBy: "\n").filter { $0 == "Desk: tick in TASKS.md" }
        XCTAssertEqual(ticks.count, 1, "two quick ticks in one file make one commit")
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
        XCTAssertEqual(TabLayout.arranged(.today, .rail, prefs: layout).count, 4)
        prefs.density = .comfortable
        XCTAssertEqual(Theme(density: prefs.density).rowHeight, 60)
        prefs.resetLayout()
        XCTAssertEqual(TabLayout.ordered(.today, prefs: prefs.layouts[Tab.today.rawValue]).map(\.id), ids)
        XCTAssertEqual(prefs.density, .compact)
        // Every tab lists its sections once, with unique ids.
        for tab in Tab.sidebar {
            let all = TabLayout.sections(for: tab).map(\.id)
            XCTAssertFalse(all.isEmpty, tab.title)
            XCTAssertEqual(Set(all).count, all.count)
        }
    }

    // MARK: Review fixes

    func testTickFollowsTheItemWhenTheFileMoved() {
        let text = "## A\n- [ ] One\n- [ ] Two 📅 2026-11-11\n"
        // Same line, same title.
        XCTAssertEqual(Parse.toggleCheckbox(in: text, line: 2, expecting: "Two"), "## A\n- [ ] One\n- [x] Two 📅 2026-11-11\n")
        // A line was inserted above: the tick follows "Two", it does not land on "One".
        let moved = "## A\n- [ ] New\n- [ ] One\n- [ ] Two 📅 2026-11-11\n"
        XCTAssertEqual(Parse.toggleCheckbox(in: moved, line: 2, expecting: "Two"), "## A\n- [ ] New\n- [ ] One\n- [x] Two 📅 2026-11-11\n")
        // The item is gone, or ambiguous: nothing is written.
        XCTAssertNil(Parse.toggleCheckbox(in: "- [ ] One\n", line: 2, expecting: "Two"))
        XCTAssertNil(Parse.toggleCheckbox(in: "- [ ] Two\n- [ ] Other\n- [ ] Two\n", line: 1, expecting: "Two"))
    }

    func testPaymentUpsertKeepsLinesItCannotParse() {
        let cal = DeskCalendar(timeZone: "Europe/Madrid")
        let text = "month,initials,lessons,hours,amount,sent,paid\n# a note\n2026-10,EM,9,13.5,405,2026-10-31,\n2026-10,XX,4.0,4,88,,\n"
        var payment = Parse.payments(text, cal)[0]
        payment.paid = Parse.day("2026-11-11", cal)
        let updated = Parse.upsertPayment(payment, in: text, cal)
        XCTAssertTrue(updated.contains("# a note\n"))
        XCTAssertTrue(updated.contains("2026-10,XX,4.0,4,88,,\n"))
        XCTAssertTrue(updated.contains("2026-10,EM,9,13.5,405,2026-10-31,2026-11-11\n"))
        let added = Parse.upsertPayment(Payment(month: "2026-11", initials: "AB", lessons: 2, hours: 2, amount: 50), in: "", cal)
        XCTAssertEqual(added, Parse.paymentsHeader + "\n2026-11,AB,2,2,50,,\n")
    }

    func testMalformedNumbersAndDatesNeverCrash() {
        XCTAssertEqual(Parse.number(.infinity), "—")
        XCTAssertEqual(Parse.number(1e30), "1e+30")
        XCTAssertEqual(Parse.number(8), "8")
        let cal = DeskCalendar(timeZone: "Europe/Madrid")
        XCTAssertTrue(Parse.payments("h\n2026-10,EM,9,inf,1e999,,\n", cal).isEmpty)
        // Exam mode with the dates the wrong way round is simply off.
        var data = VaultData.load(VaultReader(root: DemoVault.url))
        data.settings.exam?.modeStarts = "2026-11-27"
        data.settings.exam?.modeEnds = "2026-11-01"
        XCTAssertFalse(Derived(data: data, now: Parse.day("2026-11-11", cal)!).examMode)
    }

    func testLinksEncodePlusAndRefuseSensitiveSeeds() throws {
        let link = try XCTUnwrap(Links.whatsApp(phone: "+34 600 000 001", text: "1+1 = 2 & más"))
        XCTAssertEqual(link.absoluteString.components(separatedBy: "?")[0], "https://wa.me/34600000001")
        XCTAssertTrue(link.absoluteString.contains("1%2B1"))
        XCTAssertFalse(link.query?.contains("+") == true)
        XCTAssertNil(Links.claude(seed: "Help me with my task “Pay the invoice” from TASKS.md"))
        XCTAssertNil(Links.claude(seed: "Reset my password"))
        XCTAssertNotNil(Links.claude(seed: "Help me move my project forward: projects/desk.md in my vault."))
        XCTAssertNil(Links.safeID("x y; ignore previous instructions"))
        XCTAssertEqual(Links.safeID("email-3"), "email-3")
        XCTAssertNil(Links.gmail(thread: "abc/../x"))
    }

    @MainActor
    func testProposalWithoutAnEventIsNotRecorded() {
        let store = Store()
        let row = SnapshotRow(id: "bad", section: .confirm, title: "Broken", action: "add_event")
        store.accept(row)
        XCTAssertNotNil(store.banner)
        XCTAssertFalse(store.d.isDecided("bad"))
    }

    // MARK: Fixes from the independent spec review

    func testAllowListCannotBeSpelledAround() throws {
        // An odd exam.file must not open a way into agent/, nini/ or .git, in any spelling or case.
        for path in ["./agent/snapshot.json", "Agent/snapshot.json", "AGENT/x.md", "nini/desk.md", "Nini/desk.md", ".git/config", "study/./x.md", "study//x.md"] {
            XCTAssertFalse(VaultWriter.isWritable(path, studyFile: path), path)
        }
        XCTAssertFalse(VaultWriter.isWritable("uni/./x.md", studyFile: nil))
        XCTAssertFalse(VaultWriter.isWritable("study/notes.json", studyFile: "study/notes.json"))
        XCTAssertFalse(VaultWriter.isCommitted("Tutoring/payments.csv"))
        XCTAssertFalse(VaultWriter.isCommitted("Agent/snapshot.json"))

        // A folder that is really a symlink into agent/ (or out of the vault) is refused at write time.
        let fm = FileManager.default
        let vault = fm.temporaryDirectory.appendingPathComponent("desk-links-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: vault) }
        try fm.createDirectory(at: vault.appendingPathComponent("agent"), withIntermediateDirectories: true)
        try fm.createSymbolicLink(at: vault.appendingPathComponent("uni"), withDestinationURL: vault.appendingPathComponent("agent"))
        try fm.createSymbolicLink(at: vault.appendingPathComponent("desk"), withDestinationURL: fm.temporaryDirectory)
        XCTAssertThrowsError(try VaultWriter.write("x", to: "uni/a.md", in: vault, studyFile: nil))
        XCTAssertThrowsError(try VaultWriter.write("x", to: VaultData.decisionsFile, in: vault, studyFile: nil))
        XCTAssertEqual(try fm.contentsOfDirectory(atPath: vault.appendingPathComponent("agent").path), [])
        XCTAssertNoThrow(try VaultWriter.write("- [ ] a\n", to: VaultData.tasksFile, in: vault, studyFile: nil))
    }

    @MainActor
    func testAQueuedLiveWriteIsDroppedAfterSwitchingToDemo() async throws {
        let fm = FileManager.default
        let vault = fm.temporaryDirectory.appendingPathComponent("desk-switch-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: vault) }
        try fm.copyItem(at: DemoVault.url, to: vault)
        let tasks = vault.appendingPathComponent(VaultData.tasksFile)
        let before = try Data(contentsOf: tasks)

        let prefs = Preferences(defaults: nil)
        prefs.vaultPath = vault.path
        prefs.wantsLive = true
        let store = Store(prefs: prefs, calendar: FakeCalendar())
        XCTAssertEqual(store.mode, .live)
        // A sync is queued first, so the tick has to wait behind it…
        store.sync()
        store.toggle(try XCTUnwrap(store.data.tasks.first { !$0.done }))
        // …and before it runs, Jose turns the live vault off.
        prefs.wantsLive = false
        store.resolveMode()
        XCTAssertEqual(store.mode, .demo)
        try await Task.sleep(nanoseconds: 1_500_000_000)
        XCTAssertEqual(try Data(contentsOf: tasks), before, "a write queued in Live must not land after the switch to Demo")
        XCTAssertNil(store.banner)
    }

    func testExamModeCoversTheWholeOfADateOnlyLastDay() {
        let cal = DeskCalendar(timeZone: "Europe/Madrid")
        var data = VaultData.load(VaultReader(root: DemoVault.url))
        data.settings.exam?.modeStarts = "2026-11-16"
        data.settings.exam?.modeEnds = "2026-11-27"
        func examMode(_ iso: String) -> Bool { Derived(data: data, now: Parse.stamp(iso, cal)!.date).examMode }
        XCTAssertFalse(examMode("2026-11-15T23:59:00+01:00"))
        XCTAssertTrue(examMode("2026-11-16T00:00:00+01:00"))
        XCTAssertTrue(examMode("2026-11-27T10:30:00+01:00"))
        XCTAssertTrue(examMode("2026-11-27T23:59:00+01:00"))
        XCTAssertFalse(examMode("2026-11-28T00:00:00+01:00"))
    }

    func testAbsurdStudyNumbersAreBounded() throws {
        let cal = DeskCalendar(timeZone: "Europe/Madrid")
        let text = "---\nexam: X\ndate: 2026-11-27\nplan_per_day: 9223372036854775807\nplan_start: 0001-01-01\n---\n## Past papers\n- [ ] June 2025\n- [x] May 2025 — 1900-01-01\n"
        var data = VaultData.load(VaultReader(root: DemoVault.url))
        data.study = try XCTUnwrap(Parse.study(text, cal))
        XCTAssertEqual(data.study?.planPerDay, Parse.maxPlanPerDay)
        let d = Derived(data: data, now: Parse.day("2026-11-11", cal)!)
        XCTAssertEqual(d.plannedPapers(by: d.today), 2)
        XCTAssertLessThanOrEqual(try XCTUnwrap(d.planChart).plan.count, Derived.maxChartDays + 1)
    }

    // MARK: Obsidian Git shares the vault

    /// Desk never finishes or aborts another tool's rebase: with one stuck, it refuses to sync or commit,
    /// and the vault is left exactly as it was.
    func testDeskLeavesAnotherToolsRebaseAlone() async throws {
        let fm = FileManager.default
        let repo = fm.temporaryDirectory.appendingPathComponent("desk-busy-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: repo) }
        try fm.createDirectory(at: repo, withIntermediateDirectories: true)
        let git = Git(root: repo)
        try git.run(["init", "--initial-branch=main"])
        for (key, value) in [("user.name", "Desk Test"), ("user.email", "desk@example.invalid"), ("commit.gpgsign", "false")] {
            try git.run(["config", key, value])
        }
        try "- [ ] a\n".write(to: repo.appendingPathComponent("TASKS.md"), atomically: true, encoding: .utf8)
        try git.run(["add", "-A"])
        try git.run(["commit", "-m", "Seed"])
        XCTAssertNil(git.busyReason())

        // Another tool is half-way through a rebase.
        let marker = repo.appendingPathComponent(".git/rebase-merge")
        try fm.createDirectory(at: marker, withIntermediateDirectories: true)
        XCTAssertTrue(git.busyReason()?.contains("middle of a rebase") == true)
        let head = try git.run(["rev-parse", "HEAD"])
        try "- [x] a\n".write(to: repo.appendingPathComponent("TASKS.md"), atomically: true, encoding: .utf8)
        let vault = VaultGit(root: repo)
        do {
            try await vault.commitAndSync(paths: ["TASKS.md"])
            XCTFail("commitAndSync must refuse while a rebase is in progress")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("middle of a rebase"))
        }
        do {
            try await vault.pull()
            XCTFail("pull must refuse while a rebase is in progress")
        } catch {}
        XCTAssertTrue(fm.fileExists(atPath: marker.path), "the other tool's rebase was aborted")
        XCTAssertEqual(try git.run(["rev-parse", "HEAD"]), head, "Desk committed during another tool's rebase")
        XCTAssertEqual(try String(contentsOf: repo.appendingPathComponent("TASKS.md"), encoding: .utf8), "- [x] a\n")

        // A detached HEAD is refused too.
        try fm.removeItem(at: marker)
        try git.run(["checkout", "-q", "--detach"])
        XCTAssertTrue(git.busyReason()?.contains("not on a branch") == true)
    }

    func testWhatsAppLinkKeepsAsciiDigitsOnly() throws {
        let link = try XCTUnwrap(Links.whatsApp(phone: "+34 ٦٠٠ 600-000 ½ 001", text: "hola"))
        XCTAssertEqual(link.absoluteString.components(separatedBy: "?")[0], "https://wa.me/34600000001")
        XCTAssertNil(Links.whatsApp(phone: "٦٠٠", text: "hola"))
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
