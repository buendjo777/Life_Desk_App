import XCTest
@testable import Desk

/// The values worked out by code, at the demo clock (Wed 11 Nov 2026, 08:12).
final class DerivedTests: XCTestCase {
    let cal = DeskCalendar(timeZone: "Europe/Madrid")
    lazy var data = VaultData.load(VaultReader(root: DemoVault.url))
    lazy var demoNow = Parse.day(data.settings.demoToday, cal)!
    lazy var d = Derived(data: data, now: demoNow)

    func at(_ iso: String) -> Derived { Derived(data: data, now: Parse.stamp(iso, cal)!.date) }

    func testTodayLists() {
        XCTAssertEqual(d.focus.count, 3)
        XCTAssertEqual(d.dueToday.count, 4)
        XCTAssertEqual(d.dueList.map(\.title), ["Renew the gym membership"])
        XCTAssertEqual(d.leftovers.count, 3)
        XCTAssertEqual(d.toConfirm.count, 2)
    }

    func testDecidedProposalsLeaveTheQueue() {
        var decided = data
        decided.decisions.append(Decision(at: Stamp(date: demoNow, hasTime: true), row: "confirm-event-corvid", action: "dismiss"))
        XCTAssertEqual(Derived(data: decided, now: demoNow).toConfirm.map(\.id), ["confirm-tick-pulsewave"])
        decided.decisions.append(Decision(at: Stamp(date: demoNow.addingTimeInterval(60), hasTime: true), row: "confirm-event-corvid", action: "reopen"))
        XCTAssertEqual(Derived(data: decided, now: demoNow).toConfirm.count, 2)
    }

    func testDeadlines() {
        XCTAssertEqual(d.deadlines.prefix(3).map(\.short), ["Exam", "Alpine", "Lakeside"])
        XCTAssertEqual(d.deadlines.prefix(3).map(\.daysLeft), [16, 19, 34])
        XCTAssertEqual(d.deadlines.count, 6)
        // The master doc wins over the snapshot row for a linked programme.
        XCTAssertEqual(cal.time(d.deadlines[1].date), "11:59")
    }

    func testSummarySentence() {
        XCTAssertEqual(d.greeting, "Good morning, Jose")
        XCTAssertEqual(
            d.todaySummary.map(\.text).joined(),
            "Wednesday 11 November. 4 due today, 3 leftovers and 2 to confirm. 16 days to the exam, 19 to Alpine. Last run 06:34, all green."
        )
        XCTAssertEqual(at("2026-11-11T19:00:00+01:00").greeting, "Good evening, Jose")
    }

    func testRunStatusRule() {
        XCTAssertEqual(d.runStatus.level, .green)
        XCTAssertEqual(d.runStatus.lastRunText, "06:34")
        // Before the grace ends, yesterday's schedule is the one that counts.
        XCTAssertEqual(at("2026-11-12T07:29:00+01:00").runStatus.level, .green)
        // 06:30 plus 60 minutes of grace has passed and no new run arrived.
        XCTAssertEqual(at("2026-11-12T07:31:00+01:00").runStatus.level, .red)
        XCTAssertEqual(at("2026-11-12T07:31:00+01:00").runStatus.lastRunText, "Wed 06:34")

        var manual = data
        manual.rows = manual.rows.map { row in
            var row = row
            if row.section == .run { row.mode = "manual" }
            return row
        }
        XCTAssertEqual(Derived(data: manual, now: demoNow).runStatus.level, .amber)

        var none = data
        none.rows.removeAll { $0.section == .run }
        none.runs = []
        XCTAssertEqual(Derived(data: none, now: demoNow).runStatus.level, .red)
    }

    func testRunStatusFallsBackToRunsFile() {
        var noRow = data
        noRow.rows.removeAll { $0.section == .run }
        XCTAssertEqual(Derived(data: noRow, now: demoNow).runStatus.lastRunText, "06:34")
    }

    func testExamMode() {
        XCTAssertFalse(d.examMode)
        XCTAssertTrue(at("2026-11-16T09:00:00+01:00").examMode)
        XCTAssertTrue(at("2026-11-27T12:59:00+01:00").examMode)
        XCTAssertFalse(at("2026-11-27T13:01:00+01:00").examMode)
    }

    func testCalendarHelpers() {
        XCTAssertEqual(d.events(on: demoNow).map(d.displayTitle),
                       ["Morning run", "Deep work · Grad-CAM figures", "Call · Prof. Hanna Weber", "Tutoring · AB", "Tutoring · CD"])
        XCTAssertEqual(cal.weekNumber(demoNow), 46)
        XCTAssertEqual(cal.isoDay(cal.weekStart(demoNow)), "2026-11-09")
    }

    @MainActor
    func testStoreStartsInDemoWithThePinnedClock() {
        let store = Store()
        XCTAssertEqual(store.mode, .demo)
        XCTAssertEqual(store.cal.isoStamp(store.now), "2026-11-11T08:12:00+01:00")
        XCTAssertEqual(store.tab, .today)
        XCTAssertEqual(store.selection, .row("today-1"))
        XCTAssertEqual(store.vaultName, "demo-vault")
    }

    // MARK: Studying

    func testStudying() {
        XCTAssertEqual(d.examDaysLeft, 16)
        XCTAssertEqual(d.theoryProgress.text, "3/8")
        XCTAssertEqual(d.problemsProgress.text, "2/8")
        XCTAssertEqual(d.papersProgress.text, "3/12")
        XCTAssertEqual(d.studyProgress.percent, "29%")
        // The plan: 3 a day from 16 Nov, capped at the 12 papers.
        XCTAssertEqual(d.plannedPapers(by: demoNow), 0)
        XCTAssertEqual(at("2026-11-17T09:00:00+01:00").plannedPapers(by: Parse.day("2026-11-17", cal)!), 6)
        XCTAssertEqual(d.planChart?.plan.last, 12)
        XCTAssertEqual(d.planChart?.done.last, 3)
        XCTAssertEqual(d.studyTarget?.headline, "Plan starts Mon 16 Nov")
        XCTAssertEqual(at("2026-11-16T09:00:00+01:00").studyTarget?.headline, "On plan")
        XCTAssertEqual(at("2026-11-17T09:00:00+01:00").studyTarget?.headline, "3 papers today")
        XCTAssertNil(d.emptyState(for: .studying))
        var none = data
        none.study = nil
        XCTAssertNotNil(Derived(data: none, now: demoNow).emptyState(for: .studying))
    }
}
