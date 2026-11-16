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
}
