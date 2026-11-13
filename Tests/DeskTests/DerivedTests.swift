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

    func testOneApplicationWindowShowsOnceOnTheCard() throws {
        // Two uni files can share one window (ETH BME and ITET): the agent writes a row for each.
        var shared = data
        let alpine = try XCTUnwrap(shared.rows.first { $0.id == "deadline-alpine-bme" })
        shared.rows.append(SnapshotRow(id: "deadline-alpine-twin", section: .deadline, rank: 9, title: alpine.title,
                                       when: alpine.when, source: alpine.source))
        let derived = Derived(data: shared, now: demoNow)
        XCTAssertEqual(derived.deadlines.count, 7)
        XCTAssertEqual(derived.distinctDeadlines.prefix(3).map(\.short), ["Exam", "Alpine", "Lakeside"])
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
        // Without a list in play, the target comes from the paper plan.
        var plain = data
        plain.study?.lists = []
        XCTAssertEqual(Derived(data: plain, now: demoNow).studyTarget?.headline, "Plan starts Mon 16 Nov")
        XCTAssertEqual(at("2026-11-16T09:00:00+01:00").studyTarget?.headline, "On plan")
        XCTAssertEqual(at("2026-11-17T09:00:00+01:00").studyTarget?.headline, "3 papers today")
        XCTAssertNil(d.emptyState(for: .studying))
        var none = data
        none.study = nil
        XCTAssertNotNil(Derived(data: none, now: demoNow).emptyState(for: .studying))
    }

    // MARK: Pipeline

    func testProjectsBoard() {
        XCTAssertEqual(ProjectStatus.allCases.map { d.projects($0).count }, [2, 1, 1, 3])
        XCTAssertEqual(d.projects(.active).first?.title, "AF detection from ECG")
    }

    func testInternships() {
        XCTAssertEqual(Derived.targetStatuses.map { d.targets(status: $0).count }, [3, 2, 1, 1])
        XCTAssertEqual(d.applyNow.count, 7)
        XCTAssertEqual(d.allTargets.count, 12)
        XCTAssertEqual(d.applyNow.first?.company, "Meridian Health AI")
        XCTAssertEqual(Derived.label("not_contacted"), "Not contacted")
    }

    func testUniCards() {
        let cards = d.uniCards
        XCTAssertEqual(cards.map(\.school).first, "Alpine Institute of Technology")
        XCTAssertEqual(cards.map(\.daysLeft), [19, 34, 56, 65, 81])
        XCTAssertEqual(cards[0].progress.text, "3/8")
        XCTAssertEqual(cards[0].status, "In progress")
        XCTAssertEqual(cards[4].status, "Not started")
        XCTAssertTrue(d.comparison(for: cards[0].programme)?.contains("90 ECTS") == true)
        XCTAssertEqual(Derived.personStatuses.map { d.people(status: $0).count }.reduce(0, +), d.data.people?.count)
    }

    /// Markdown is parsed in exactly one file, used only for trusted `nini/` docs.
    func testMarkdownIsParsedInOneFileOnly() throws {
        let sources = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Sources/Desk")
        let files = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil)?.compactMap { $0 as? URL } ?? []
        var offenders: [String] = []
        for file in files where file.pathExtension == "swift" && file.lastPathComponent != "MarkdownView.swift" {
            let text = try String(contentsOf: file, encoding: .utf8)
            if text.contains("AttributedString(markdown") || text.contains("LocalizedStringKey(") || text.contains("Text(.init(") {
                offenders.append(file.lastPathComponent)
            }
            // Interpolated VoiceOver labels and tooltips must be verbatim too, or they parse Markdown.
            for line in text.components(separatedBy: "\n")
            where (line.contains(".accessibilityLabel(\"") || line.contains(".help(\"")) && line.contains("\\(") {
                offenders.append("\(file.lastPathComponent): \(line.trimmingCharacters(in: .whitespaces))")
            }
        }
        XCTAssertEqual(offenders, [])
    }

    func testAListSetsTodaysShareUntilItsDueDay() throws {
        let list = try XCTUnwrap(d.openLists.first)
        XCTAssertEqual(list.title, "This week")
        XCTAssertEqual(d.daysLeft(list), 5)
        XCTAssertEqual(d.listSubtitle(list), "Due Sun 15 Nov · 5 days left · 5 to go")
        // Five days for 2 lectures and 3 sheets: one of each today, so both groups end on Sunday.
        XCTAssertEqual(d.todaysShare(list).map(\.title), ["Lecture 6 · Beam deflection · 110 min", "Sheet 2 · Torsion of shafts"])
        let target = try XCTUnwrap(d.studyTarget)
        XCTAssertEqual(target.headline, "2 items today")
        XCTAssertEqual(target.detail, "5 left, due Sunday · 1 h 50 of video today.")
        XCTAssertEqual(target.checks.count, 2)
        XCTAssertEqual(Derived.minutesLeft(list.groups[0]), 210)
        XCTAssertTrue(d.studyingSummary.map(\.text).joined().contains("This week: 2 of 7 done (due Sunday 15 Nov)."))
        // On the due day everything left is today's.
        let sunday = at("2026-11-15T09:00:00+01:00")
        XCTAssertEqual(sunday.todaysShare(list).count, 5)
        XCTAssertEqual(sunday.listSubtitle(list), "Due Sun 15 Nov · due today · 5 to go")
        // After it the list shows as late, and the paper plan sets the target again.
        let monday = at("2026-11-16T09:00:00+01:00")
        XCTAssertEqual(monday.listSubtitle(list), "Due Sun 15 Nov · 1 day late · 5 to go")
        XCTAssertEqual(monday.studyTarget?.headline, "On plan")
    }

    // MARK: Tutoring

    func testTutoringMoney() {
        XCTAssertEqual(d.thisMonth.map(\.lessons), [3, 1, 3, 1])
        XCTAssertEqual(d.thisMonth.map(\.amount), [75, 22, 135, 22])
        XCTAssertEqual(d.receivedThisMonth, 398)
        XCTAssertEqual(d.waitingForPayment.map(\.id), ["2026-10-EM"])
        XCTAssertEqual(d.pendingAmount, 405)
        XCTAssertEqual(d.monthEnd.count, 0)
        XCTAssertEqual(d.weekLessons.count, 6)
        XCTAssertEqual(d.money(13.5), "13.5 €")
        // On 1 December, November becomes a finished month that has not been sent.
        let december = at("2026-12-01T09:00:00+01:00")
        XCTAssertEqual(december.monthEnd.count, 4)
        XCTAssertEqual(december.monthEnd.first?.month, "2026-11")
        // Without the Classes note, the calendar is the record.
        var calendarOnly = data
        calendarOnly.tutoring.lessons = []
        let fromCalendar = Derived(data: calendarOnly, now: demoNow)
        XCTAssertFalse(fromCalendar.lessonsFromNote)
        XCTAssertEqual(fromCalendar.thisMonth.map(\.lessons), [3, 1, 3, 1])
        XCTAssertEqual(Derived(data: calendarOnly, now: december.now).monthEnd.count, 4)
    }

    func testHistoryFromTheClassesNote() {
        XCTAssertTrue(d.lessonsFromNote)
        XCTAssertEqual(d.allTime.amount, 15903)
        XCTAssertEqual(d.earningsByYear.map(\.key), ["2026", "2025", "2024"])
        XCTAssertEqual(d.earningsByYear.map(\.amount), [6569, 7529.5, 1804.5])
        XCTAssertEqual(d.earnings(inYear: "2026").lessons, 224)
        XCTAssertEqual(d.bestMonth?.key, "2025-02")
        XCTAssertEqual(d.historyBars.count, Derived.historyMonths)
        XCTAssertEqual(d.historyBars.first?.key, "2024-12")
        XCTAssertEqual(d.historyBars.last?.key, "2026-11")
        XCTAssertEqual(d.historyBars.last?.amount, 254)
        // August has no lessons: an empty bar, not a gap.
        XCTAssertEqual(d.historyBars.first { $0.key == "2025-08" }?.amount, 0)
        XCTAssertEqual(d.earningsByStudent.map(\.initials), ["EM", "AB", "CD", "NF", "PV", "IS", "LR"])
        XCTAssertEqual(d.earningsByStudent.filter(\.current).map(\.initials), ["EM", "AB", "CD", "LR"])
        XCTAssertEqual(d.earningsByStudent.first?.name, "Emma Martin")
        XCTAssertEqual(Derived.change(110, from: 100), "+10%")
        XCTAssertEqual(Derived.change(90, from: 100), "−10%")
        XCTAssertNil(Derived.change(90, from: 0))
    }

    func testWhatsAppMessageUsesTheTutoringLocale() throws {
        let payment = try XCTUnwrap(d.waitingForPayment.first)
        let reminder = try XCTUnwrap(d.tutoringMessage(for: payment, reminder: true))
        XCTAssertTrue(reminder.contains("octubre"))
        XCTAssertTrue(reminder.contains("405 €"))
        XCTAssertFalse(reminder.contains("{"))
        let link = try XCTUnwrap(d.whatsAppLink(for: payment, reminder: true))
        XCTAssertEqual(link.host, "wa.me")
        XCTAssertTrue(link.path.dropFirst().allSatisfy(\.isNumber))
        XCTAssertNil(d.whatsAppLink(for: Payment(month: "2026-10", initials: "ZZ", lessons: 1, hours: 1, amount: 1), reminder: true))
    }

    @MainActor
    func testMarkPaidInDemoNeverTouchesTheDisk() throws {
        let store = Store(isSnapshot: true)
        let file = DemoVault.url.appendingPathComponent(VaultData.paymentsFile)
        let before = try String(contentsOf: file, encoding: .utf8)
        store.markPaid(try XCTUnwrap(store.d.waitingForPayment.first))
        XCTAssertTrue(store.d.waitingForPayment.isEmpty)
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), before)
    }

    // MARK: Health and System

    func testHealth() {
        XCTAssertEqual(d.weekActivities.count, 3)
        XCTAssertEqual(Derived.durationText(d.weekSeconds), "2 h 37")
        XCTAssertEqual(Derived.kilometres(d.weekMetres), "32.2")
        XCTAssertEqual(d.streak.map(\.trained), [true, true, true, false, false, false, false])
        XCTAssertEqual(d.weekBars.count, 12)
        XCTAssertEqual(d.weekBars.last?.sessions, 3)
        XCTAssertEqual(d.activityList.first?.name, "Morning run")
    }

    func testSystem() {
        XCTAssertEqual(d.runHistory.count, 15)
        XCTAssertEqual(d.runStrip.map(\.state).filter { $0 == .failed }.count, 1)
        XCTAssertEqual(d.runStrip.filter { $0.state == .none }.count, 0)
        XCTAssertEqual(d.runStrip.last?.state, .ok)
        XCTAssertEqual(d.modelsUsed.map(\.model), ["sonnet", "haiku"])
        XCTAssertEqual(d.lastRun.map(Derived.runDuration), "4 min 07 s")
        XCTAssertEqual(d.failureLog.count, 2)
    }
}
