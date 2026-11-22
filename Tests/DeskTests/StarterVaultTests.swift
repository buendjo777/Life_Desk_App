import XCTest
@testable import Desk

/// A new person's first vault, and a vault that is a plain folder (no git).
final class StarterVaultTests: XCTestCase {
    private func scratch() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("desk-starter-\(UUID().uuidString)", isDirectory: true)
    }

    func testStarterVaultCarriesTheNameAndLoads() throws {
        let folder = scratch().appendingPathComponent("Desk")
        defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
        let cal = DeskCalendar(timeZone: "Europe/Madrid")
        let today = try XCTUnwrap(Parse.day("2027-01-15", cal))
        try StarterVault.create(at: folder, name: "  Ana \"Quote\" ", today: today)
        XCTAssertTrue(StarterVault.isVault(folder))

        let data = VaultData.load(VaultReader(root: folder))
        XCTAssertEqual(data.settings.name, "Ana \"Quote\"")
        let tasks = try String(contentsOf: folder.appendingPathComponent(VaultData.tasksFile), encoding: .utf8)
        XCTAssertTrue(tasks.contains("📅 2027-01-15"))
        XCTAssertFalse(tasks.contains(StarterVault.todayToken))
        let derived = Derived(data: data, now: today)
        XCTAssertEqual(derived.projects(.active).count, 1)
        XCTAssertTrue(derived.greeting.contains("Ana"))
        // Studying was chosen: its sample exam is a month away and its first list is due this week.
        XCTAssertEqual(derived.examDaysLeft, StarterVault.examDays)
        XCTAssertEqual(derived.openLists.first?.title, "This week")
    }

    @MainActor func testOnlyChosenTabsGetFilesAndASidebarRow() throws {
        let folder = scratch()
        defer { try? FileManager.default.removeItem(at: folder) }
        try StarterVault.create(at: folder, name: "Ana", tabs: [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent(StarterVault.studyFolder).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent(StarterVault.projectsFolder).path))
        XCTAssertNil(VaultData.load(VaultReader(root: folder)).settings.exam)

        let store = Store()
        store.setTab(.tutoring, shown: false)
        store.setTab(.today, shown: false)
        XCTAssertFalse(store.visibleTabs.contains(.tutoring))
        XCTAssertTrue(store.visibleTabs.contains(.today))
        store.show(.projects)
        store.setTab(.projects, shown: false)
        XCTAssertEqual(store.tab, .today)
    }

    func testStarterNeverWritesOverFiles() throws {
        let folder = scratch()
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try "mine".write(to: folder.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try StarterVault.create(at: folder, name: "Ana"))
        XCTAssertEqual(try String(contentsOf: folder.appendingPathComponent("notes.txt"), encoding: .utf8), "mine")
    }

    func testPlainFolderVaultNeverRunsGit() async throws {
        let folder = scratch()
        defer { try? FileManager.default.removeItem(at: folder) }
        try StarterVault.create(at: folder, name: "Ana")
        XCTAssertFalse(Git(root: folder).isRepo)
        let git = VaultGit(root: folder)
        try await git.pull()
        try await git.commitAndSync(paths: [VaultData.tasksFile])
        XCTAssertFalse(Git(root: folder).isRepo)
    }
}

/// A list past its due day comes first, in file order, and today's papers follow it.
final class OverdueStudyTests: XCTestCase {
    func testOverdueListLeadsTheTarget() throws {
        let cal = DeskCalendar(timeZone: "Europe/Madrid")
        let text = """
        ---
        exam: Test
        date: 2026-11-27T10:30:00+01:00
        plan_per_day: 2
        plan_start: 2026-11-16
        ---
        ## Overdue — due 2026-11-15
        ### 1 · Problems
        - [ ] First
        ### 2 · Sheets
        - [ ] Second
        - [ ] Third
        - [ ] Fourth
        ## Past papers
        - [ ] Paper A
        - [ ] Paper B
        - [ ] Paper C
        """
        var data = VaultData.load(VaultReader(root: DemoVault.url))
        data.study = Parse.study(text, cal)
        let derived = Derived(data: data, now: try XCTUnwrap(Parse.stamp("2026-11-16T09:00:00+01:00", cal)).date)
        let target = try XCTUnwrap(derived.studyTarget)
        XCTAssertEqual(target.headline, "4 overdue")
        XCTAssertTrue(target.detail.hasPrefix("Next: 1 · Problems. Then 2 papers today."))
        XCTAssertEqual(target.checks.map(\.title), ["First", "Second", "Third", "Paper A", "Paper B"])
    }
    /// Papers kept as a `### Past papers` group in an overdue list: still papers, worked in the list's order, counted once.
    func testPapersInAnOverdueList() throws {
        let cal = DeskCalendar(timeZone: "Europe/Madrid")
        let text = """
        ---
        exam: Test
        date: 2026-11-27T10:30:00+01:00
        plan_per_day: 2
        plan_start: 2026-11-16
        ---
        ## Overdue — due 2026-11-15
        ### 1 · Sheets
        - [x] Sheet 1
        - [ ] Sheet 2
        ### 2 · Past papers
        - [x] Paper A — 2026-11-17 — 7/10
        - [ ] Paper B
        - [ ] Paper C
        ## Past papers
        """
        var data = VaultData.load(VaultReader(root: DemoVault.url))
        data.study = Parse.study(text, cal)
        let derived = Derived(data: data, now: try XCTUnwrap(Parse.stamp("2026-11-22T09:00:00+01:00", cal)).date)
        XCTAssertEqual(derived.study?.papers.map(\.title), ["Paper A", "Paper B", "Paper C"])
        XCTAssertEqual(derived.study?.papers.first?.score, 7)
        XCTAssertEqual(derived.papersProgress.text, "1/3")
        XCTAssertEqual(derived.listsProgress.text, "1/2")
        XCTAssertEqual(derived.studyProgress.text, "2/5")
        let target = try XCTUnwrap(derived.studyTarget)
        XCTAssertEqual(target.headline, "3 overdue")
        XCTAssertEqual(target.detail, "Next: 1 · Sheets.")
        XCTAssertEqual(target.checks.map(\.title), ["Sheet 2", "Paper B", "Paper C"])
    }
}
