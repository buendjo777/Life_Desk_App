import XCTest
@testable import Desk

/// Every parser against `demo-vault/`, plus malformed input: an empty state, never a crash.
final class ParserTests: XCTestCase {
    let cal = DeskCalendar(timeZone: "Europe/Madrid")
    lazy var data = VaultData.load(VaultReader(root: DemoVault.url))

    // MARK: Dates

    func testStampFormats() throws {
        let day = try XCTUnwrap(Parse.stamp("2026-11-12", cal))
        XCTAssertFalse(day.hasTime)
        XCTAssertEqual(cal.isoStamp(day.date), "2026-11-12T00:00:00+01:00")

        let utc = try XCTUnwrap(Parse.stamp("2026-11-18T12:30:00Z", cal))
        XCTAssertTrue(utc.hasTime)
        XCTAssertEqual(cal.time(utc.date), "13:30")

        let offset = try XCTUnwrap(Parse.stamp("2026-11-11T08:12:00+01:00", cal))
        XCTAssertEqual(cal.time(offset.date), "08:12")

        let wallClock = try XCTUnwrap(Parse.stamp("2026-11-30 11:59 CET", cal))
        XCTAssertEqual(cal.isoStamp(wallClock.date), "2026-11-30T11:59:00+01:00")

        for bad in ["", "tomorrow", "2026-13-40", "11/11/2026", "2026-11-12T25:99"] {
            XCTAssertNil(Parse.stamp(bad, cal), bad)
        }
    }

    // MARK: Demo vault, file by file

    func testDemoVaultLoadsWithoutIssues() {
        XCTAssertEqual(data.issues, [:])
    }

    func testSettings() {
        XCTAssertEqual(data.settings.name, "Jose")
        XCTAssertEqual(data.settings.timezone, "Europe/Madrid")
        XCTAssertEqual(data.settings.scheduledRunLocal, "06:30")
        XCTAssertEqual(data.settings.exam?.file, "study/strength-of-materials.md")
        XCTAssertEqual(data.settings.tutoringLocale, "es_ES")
        XCTAssertEqual(data.settings.links.runNow, "https://example.com/demo/run-now")
        XCTAssertNotNil(data.settings.demoToday)
    }

    func testSnapshotRows() throws {
        XCTAssertEqual(data.rows.count, 30)
        XCTAssertEqual(data.rows(.deadline).count, 6)
        XCTAssertEqual(data.rows(.today).map(\.id), ["today-1", "today-2", "today-3"])
        XCTAssertEqual(data.rows(.email).count, 5)
        let confirm = try XCTUnwrap(data.rows(.confirm).first)
        XCTAssertEqual(confirm.action, "add_event")
        XCTAssertEqual(confirm.event?.title, "Interview · Corvid MedTech")
        XCTAssertEqual(confirm.gmailThread, "18c2f0a1b2c3d4e5")
        XCTAssertEqual(data.rows(.run).first?.mode, "nightly")
    }

    func testGmailThreadRejectsAnythingButHex() {
        func row(_ source: String) -> SnapshotRow {
            SnapshotRow(id: "x", section: .email, title: "t", source: source)
        }
        XCTAssertNil(row("Gmail 18c2/../../evil").gmailThread)
        XCTAssertNil(row("Gmail ").gmailThread)
        XCTAssertNil(row("TASKS.md").gmailThread)
        XCTAssertEqual(row("Gmail 18c2f0").gmailThread, "18c2f0")
    }

    func testRuns() throws {
        XCTAssertEqual(data.runs.count, 15)
        XCTAssertEqual(data.runs.filter { !$0.isOK }.count, 1)
        let last = try XCTUnwrap(data.runs.last)
        XCTAssertEqual(last.messagesScanned, 23)
        XCTAssertEqual(last.agents?.count, 5)
        XCTAssertEqual(last.duration, 247)
    }

    func testDrafts() throws {
        XCTAssertEqual(data.drafts.count, 2)
        let draft = try XCTUnwrap(data.drafts.first { $0.path.hasSuffix("maya-chen.md") })
        XCTAssertEqual(draft.thread, "18c2f0a1b2c3d4e5")
        XCTAssertEqual(draft.status, "unreviewed")
        XCTAssertTrue(draft.body.hasPrefix("Hi Maya,"))
        XCTAssertTrue(draft.body.hasSuffix("Jose"))
    }

    func testStrava() {
        XCTAssertEqual(data.activities.count, 47)
        XCTAssertEqual(data.activities.last?.distanceM, 8200)
        XCTAssertNil(data.activities.first { $0.type == "Strength" }?.distanceM)
    }

    func testTasks() throws {
        XCTAssertEqual(data.tasks.count, 13)
        XCTAssertEqual(data.tasks.filter(\.done).count, 1)
        let first = try XCTUnwrap(data.tasks.first)
        XCTAssertEqual(first.title, "Send the Grad-CAM figures to the lab")
        XCTAssertEqual(first.section, "Research")
        XCTAssertEqual(first.due.map(cal.isoDay), "2026-11-11")
        XCTAssertNil(data.tasks.last?.due)
    }

    func testStudyFile() throws {
        let study = try XCTUnwrap(data.study)
        XCTAssertEqual(study.exam, "Strength of Materials — retake")
        XCTAssertEqual(study.planPerDay, 3)
        XCTAssertEqual(study.planStart.map(cal.isoDay), "2026-11-16")
        XCTAssertEqual(study.theory.count, 8)
        XCTAssertEqual(study.theory.filter(\.done).count, 3)
        XCTAssertEqual(study.problems.filter(\.done).count, 2)
        XCTAssertEqual(study.papers.count, 12)
        let paper = try XCTUnwrap(study.papers.first)
        XCTAssertEqual(paper.title, "June 2025")
        XCTAssertEqual(paper.score, 6.5)
        XCTAssertEqual(paper.outOf, 10)
        XCTAssertEqual(paper.date.map(cal.isoDay), "2026-11-08")
        XCTAssertNil(study.papers.last?.date)
    }

    func testProjects() throws {
        XCTAssertEqual(data.projects.count, 7)
        XCTAssertEqual(data.projects.filter { $0.status == .idea }.count, 3)
        let project = try XCTUnwrap(data.projects.first { $0.path == "projects/af-detection.md" })
        XCTAssertEqual(project.status, .active)
        XCTAssertEqual(project.doc, "nini/af-detection.md")
        XCTAssertEqual(project.items.count, 4)
        XCTAssertEqual(project.nextDate.map(cal.isoDay), "2026-11-12")
    }

    func testUniFilesAndMasterDeadlines() throws {
        XCTAssertEqual(data.unis.count, 5)
        let alpine = try XCTUnwrap(data.unis.first { $0.path == "uni/alpine-bme.md" })
        XCTAssertEqual(alpine.deadlineRow, "deadline-alpine-bme")
        XCTAssertEqual(alpine.items.filter(\.done).count, 3)
        XCTAssertEqual(data.masterDeadlines.count, 5)
        let master = try XCTUnwrap(data.masterDeadlines[alpine.comparisonHeading])
        XCTAssertEqual(cal.isoStamp(master.date), "2026-11-30T11:59:00+01:00")
        let section = try XCTUnwrap(Parse.section(data.docs[VaultData.comparisonDoc] ?? "", heading: alpine.comparisonHeading))
        XCTAssertTrue(section.hasPrefix("- Structure: 90 ECTS"))
        XCTAssertFalse(section.contains("Lakeside"))
    }

    func testBoards() {
        XCTAssertEqual(data.targets?.count, 12)
        XCTAssertEqual(data.targets?.filter { $0.list == "apply_now" }.count, 7)
        XCTAssertEqual(data.people?.count, 10)
        XCTAssertEqual(data.people?.first?.lastContact.map { cal.isoDay($0.date) }, "2026-11-10")
    }

    func testDecisionsAndEvents() {
        XCTAssertEqual(data.decisions.map(\.action), ["confirm", "add", "dismiss"])
        XCTAssertEqual(data.events.count, 47)
        XCTAssertEqual(data.events.filter { $0.calendar == "Tutoring" }.count, 36)
    }

    func testTutoring() throws {
        let tutoring = data.tutoring
        XCTAssertEqual(tutoring.students.map(\.initials), ["AB", "CD", "EM", "LR"])
        XCTAssertEqual(tutoring.students.first?.rate, 25)
        XCTAssertEqual(tutoring.students.first?.paysBy, "Bizum")
        XCTAssertEqual(tutoring.payments.count, 7)
        let unpaid = tutoring.payments.filter { $0.status == .sent }
        XCTAssertEqual(unpaid.map(\.id), ["2026-10-EM"])
        XCTAssertEqual(unpaid.first?.hours, 13.5)
        XCTAssertEqual(tutoring.contacts["AB"]?.phone, "+34600000001")
        XCTAssertEqual(tutoring.notes["AB"]?.count, 3)
        XCTAssertEqual(tutoring.notes["AB"]?.last.map { cal.isoDay($0.date) }, "2026-11-09")
        XCTAssertTrue(tutoring.template.contains("{parent}"))
        XCTAssertTrue(tutoring.reminderTemplate.contains("{amount}"))
    }

    func testPaymentsRoundTrip() {
        let csv = Parse.paymentsCSV(data.tutoring.payments, cal)
        XCTAssertEqual(Parse.payments(csv, cal), data.tutoring.payments)
        XCTAssertTrue(csv.contains("2026-10,EM,9,13.5,405,2026-10-31,\n"))
    }

    // MARK: Markdown building blocks

    func testToggleCheckbox() {
        let text = "## A\n- [ ] one\n- [x] two\nplain"
        XCTAssertEqual(Parse.toggleCheckbox(in: text, line: 1), "## A\n- [x] one\n- [x] two\nplain")
        XCTAssertEqual(Parse.toggleCheckbox(in: text, line: 2), "## A\n- [ ] one\n- [ ] two\nplain")
        XCTAssertNil(Parse.toggleCheckbox(in: text, line: 3))
        XCTAssertNil(Parse.toggleCheckbox(in: text, line: 99))
    }

    func testFrontMatter() {
        let (fields, start) = Parse.frontMatter(["---", "title: \"A: B\"", "next:", "---", "body"])
        XCTAssertEqual(fields, ["title": "A: B", "next": ""])
        XCTAssertEqual(start, 4)
        XCTAssertEqual(Parse.frontMatter(["no front matter"]).bodyStart, 0)
        XCTAssertEqual(Parse.frontMatter(["---", "never: closed"]).fields, [:])
    }

    // MARK: Malformed input

    func testMalformedJSONGivesEmptyValues() {
        XCTAssertNil(Parse.array(SnapshotRow.self, "{ not json", cal))
        XCTAssertNil(Parse.array(SnapshotRow.self, "{\"id\": 1}", cal))
        XCTAssertEqual(Parse.array(SnapshotRow.self, "[]", cal), [])
        XCTAssertEqual(Parse.lines(Run.self, "garbage\n\n{\"half\":", cal), [])
        XCTAssertNil(Parse.json(DeskSettings.self, "", cal))
    }

    func testOneBadRowDoesNotEmptyTheList() {
        let text = """
        [{"id": "a", "section": "today", "title": "ok", "unknown_field": 42},
         {"id": "b", "section": "not-a-section", "title": "bad section"},
         {"id": "c", "section": "today", "title": "bad date", "when": "soon"},
         {"section": "today"},
         "not an object"]
        """
        XCTAssertEqual(Parse.array(SnapshotRow.self, text, cal)?.map(\.id), ["a"])
    }

    func testMalformedMarkdownAndCSV() {
        XCTAssertEqual(Parse.tasks("", cal), [])
        XCTAssertEqual(Parse.tasks("- [ ] no section 📅 not-a-date", cal).first?.due, nil)
        XCTAssertNil(Parse.study("", cal))
        XCTAssertNil(Parse.project(path: "p.md", "no front matter", cal))
        XCTAssertNil(Parse.project(path: "p.md", "---\ntitle: T\nstatus: bogus\n---", cal))
        XCTAssertNil(Parse.uni(path: "u.md", "- [ ] only a checklist"))
        XCTAssertNil(Parse.draft(path: "d.md", "no front matter", cal))
        XCTAssertEqual(Parse.students("| Initials |\n|---|"), [])
        XCTAssertEqual(Parse.students("not a table"), [])
        XCTAssertEqual(Parse.payments("month,initials\n2026-10,AB,x,y,z,,\n,,,,,,\nshort", cal), [])
        XCTAssertEqual(Parse.notes("text before any heading\n## not a date\nmore", cal), [])
        XCTAssertEqual(Parse.masterDeadlines("| Programme | Deadline |\n|---|---|\n| X | whenever |", cal), [:])
        XCTAssertEqual(Parse.table(""), [])
    }

    func testEmptyVaultGivesHintsNotCrashes() throws {
        let empty = FileManager.default.temporaryDirectory.appendingPathComponent("desk-empty-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: empty) }
        let data = VaultData.load(VaultReader(root: empty))
        XCTAssertEqual(data.rows, [])
        XCTAssertNil(data.study)
        XCTAssertNil(data.targets)
        XCTAssertEqual(data.hint(VaultData.snapshotFile), "agent/snapshot.json is missing.")
        XCTAssertEqual(data.hint(VaultData.tasksFile), "TASKS.md is missing.")
        let derived = Derived(data: data, now: Date())
        XCTAssertEqual(derived.focus, [])
        XCTAssertEqual(derived.runStatus.level, .red)
    }

    func testMalformedFilesAreReported() {
        let reader = VaultReader(root: DemoVault.url, overlay: [
            VaultData.snapshotFile: "<html>", VaultData.settingsFile: "{", VaultData.targetsFile: "nope",
        ])
        let data = VaultData.load(reader)
        XCTAssertEqual(data.rows, [])
        XCTAssertEqual(data.targets, [])
        XCTAssertEqual(data.hint(VaultData.snapshotFile), "agent/snapshot.json could not be read.")
        XCTAssertEqual(data.hint(VaultData.settingsFile), "desk/settings.json could not be read.")
        XCTAssertEqual(data.hint(VaultData.targetsFile), "internships/targets.json could not be read.")
    }
}
