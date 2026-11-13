import XCTest
@testable import Desk

/// A read-only look at the live vault, run by hand:
/// `DESK_LIVE_VAULT=~/jose-brain swift test --filter LiveVaultCheck`. Skipped otherwise.
/// It loads and derives what the tabs would show; it never writes or runs git.
final class LiveVaultCheck: XCTestCase {
    func testWhatTheLiveVaultShows() throws {
        guard let path = ProcessInfo.processInfo.environment["DESK_LIVE_VAULT"] else {
            throw XCTSkip("Set DESK_LIVE_VAULT to the vault folder to run this check.")
        }
        let root = URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true)
        let data = VaultData.load(VaultReader(root: root))
        let d = Derived(data: data, now: Date())
        print("LIVE greeting: \(d.greeting)")
        print("LIVE summary: \(d.todaySummary.map(\.text).joined())")
        print("LIVE run status: \(d.runStatus.level.word) · last run \(d.runStatus.lastRunText ?? "none")")
        print("LIVE today: focus \(d.focus.count), due \(d.dueToday.count), leftovers \(d.leftovers.count), to confirm \(d.toConfirm.count)")
        print("LIVE deadlines: \(d.deadlines.prefix(5).map { "\($0.short) \($0.daysLeft) d" })")
        print("LIVE uni cards with a deadline: \(d.uniCards.filter { $0.deadline != nil }.count) of \(d.uniCards.count)")
        print("LIVE comparison sections found: \(data.unis.filter { d.comparison(for: $0) != nil }.count) of \(data.unis.count)")
        let linked = data.projects.compactMap(\.doc)
        print("LIVE project docs found: \(linked.filter { data.docs[$0] != nil }.count) of \(linked.count)")
        print("LIVE wikilinks left in docs: \(data.docs.values.filter { $0.contains("[[") }.count)")
        print("LIVE study: \(data.study.map { "\($0.theory.filter(\.done).count + $0.problems.filter(\.done).count) topic ticks" } ?? "none")")
        for list in data.study?.lists ?? [] {
            print("LIVE list: \(list.title) · \(d.listSubtitle(list)) · groups \(list.groups.map { "\($0.title) \($0.items.count)" }) · today \(d.todaysShare(list).count)")
        }
        print("LIVE study target: \(d.studyTarget.map { "\($0.headline) — \($0.detail)" } ?? "none")")
        print("LIVE missing or unreadable: \(data.issues.keys.sorted())")
        // What one tick costs on the main thread: re-reading the vault and deriving the Studying tab.
        let runs = 10
        var start = Date()
        for _ in 0..<runs { _ = VaultData.load(VaultReader(root: root)) }
        let load = Date().timeIntervalSince(start) / Double(runs) * 1000
        start = Date()
        for _ in 0..<runs {
            let again = Derived(data: data, now: Date())
            _ = (again.studyProgress, again.planChart?.total, again.studyTarget?.headline, again.studyingSummary.count)
        }
        let derive = Date().timeIntervalSince(start) / Double(runs) * 1000
        var copy = data
        start = Date()
        if let file = data.settings.exam?.file {
            for _ in 0..<runs { _ = copy.refresh(file, from: VaultReader(root: root)) }
        }
        let tick = Date().timeIntervalSince(start) / Double(runs) * 1000
        print("LIVE reload: \(Int(load)) ms to read the vault, \(Int(derive)) ms to derive Studying, \(String(format: "%.1f", tick)) ms to re-read the study file after a tick")
    }
}
