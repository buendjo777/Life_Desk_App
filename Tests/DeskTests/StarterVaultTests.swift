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
