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
        XCTAssertEqual(project.doc, "Research/AF detection.md")
        XCTAssertEqual(project.items.count, 4)
        XCTAssertEqual(project.nextDate.map(cal.isoDay), "2026-11-12")
    }

    func testUniFilesAndMasterDeadlines() throws {
        XCTAssertEqual(data.unis.count, 5)
        let alpine = try XCTUnwrap(data.unis.first { $0.path == "uni/alpine-bme.md" })
        XCTAssertEqual(alpine.deadlineRow, "deadline-alpine-bme")
        XCTAssertEqual(alpine.items.filter(\.done).count, 3)
        XCTAssertEqual(data.masterDeadlines.count, 5)
        let master = try XCTUnwrap(data.masterDeadline(for: alpine))
        XCTAssertEqual(cal.isoStamp(master.date), "2026-11-30T11:59:00+01:00")
        // A bold programme cell still matches its uni file.
        let harbor = try XCTUnwrap(data.unis.first { $0.path == "uni/harbor-bme.md" })
        XCTAssertEqual(data.masterDeadline(for: harbor).map { cal.isoDay($0.date) }, "2027-01-15")
        let comparison = data.docs[VaultData.comparisonDoc] ?? ""
        let section = try XCTUnwrap(Parse.section(comparison, heading: alpine.comparisonHeading))
        XCTAssertTrue(section.hasPrefix("- Structure: 90 ECTS"))
        XCTAssertFalse(section.contains("Lakeside"))
        // The wikilink in the section is plain text.
        XCTAssertTrue(section.contains("wearable sensors; see the AF project."), section)
        // The last programme of a group stops at the next "##" group heading.
        let thames = try XCTUnwrap(Parse.section(comparison, heading: "Thames College London — MSc Medical AI"))
        XCTAssertFalse(thames.contains("Section 2"))
        XCTAssertFalse(thames.contains("Harbor"))
    }

    // MARK: Jose's docs (Masters/ and project docs)

    func testProjectDocsLoadWithWikilinksAsPlainText() throws {
        let doc = try XCTUnwrap(data.docs["Research/AF detection.md"])
        XCTAssertTrue(doc.contains("overlap with the interpretability study."))
        for text in data.docs.values {
            XCTAssertFalse(text.contains("[["), "a wikilink was left in a doc")
        }
        // Every demo project's doc is found.
        for project in data.projects {
            if let path = project.doc { XCTAssertNotNil(data.docs[path], path) }
        }
    }

    func testWikilinkForms() {
        XCTAssertEqual(Parse.plainWikilinks("See [[Note]]."), "See Note.")
        XCTAssertEqual(Parse.plainWikilinks("[[Masters/Deadlines 2027|the dates]]"), "the dates")
        XCTAssertEqual(Parse.plainWikilinks("| [[Masters/Deadlines 2027\\|dates]] |"), "| dates |")
        XCTAssertEqual(Parse.plainWikilinks("[[Masters/Deadlines 2027.md]]"), "Deadlines 2027")
        XCTAssertEqual(Parse.plainWikilinks("[[Note#Heading]] and [[#Local]]"), "Note > Heading and Local")
        XCTAssertEqual(Parse.plainWikilinks("[[Note#^block1]]"), "Note")
        XCTAssertEqual(Parse.plainWikilinks("![[diagram.png]]"), "diagram.png")
        XCTAssertEqual(Parse.plainWikilinks("[[Note|]]"), "Note")
        XCTAssertEqual(Parse.plainWikilinks("no links, [single] brackets"), "no links, [single] brackets")
        XCTAssertEqual(Parse.plainWikilinks("[[a]][[b]]"), "ab")
    }

    func testTrustedDocPaths() {
        for path in ["Masters/Programme comparison.md", "Research/Aslanidi meeting.md", "ICAI/Resis retake.md", "Notes.md"] {
            XCTAssertTrue(Parse.isTrustedDoc(path), path)
        }
        for path in ["agent/drafts/x.md", "Agent/snapshot.md", "../outside.md", "/etc/x.md", "Research/../agent/x.md",
                     "Research/a.json", ".git/x.md", "Research//a.md", ""] {
            XCTAssertFalse(Parse.isTrustedDoc(path), path)
        }
        // A project whose doc points into agent/ gets no Markdown: the doc is not loaded at all.
        let reader = VaultReader(root: DemoVault.url, overlay: [
            "projects/zz-agent-doc.md": "---\ntitle: Agent doc\nstatus: idea\nnext: x\ndoc: agent/drafts/2026-11-11-maya-chen.md\n---\n",
        ])
        let data = VaultData.load(reader)
        XCTAssertNotNil(data.projects.first { $0.title == "Agent doc" })
        XCTAssertNil(data.docs["agent/drafts/2026-11-11-maya-chen.md"])
    }

    func testRealDeadlineTableFormat() throws {
        let text = """
        # Application dates — 2027 entry

        | Closes | Programme | Round | Opens | Decision |
        |---|---|---|---|---|
        | **3 Nov 2026** | Duke — MEng BME | Round 1 of 3 | open | not published |
        | **30 Nov 2026, 11:59 CET** | ETH Zürich — MSc ITET **and** MSc BME | the only window | 1 Nov 2026 | late Jan |
        | **16 Dec 2026** | **Georgia Tech — MS ECE, Atlanta** (recommended) | single date | not published | — |
        | 2027-01-06 | Thames — MSc AI | Round 2 | open | — |
        | rolling | Somewhere | — | — | — |
        """
        let deadlines = Parse.masterDeadlines(text, cal)
        XCTAssertEqual(deadlines.count, 4)
        XCTAssertEqual(deadlines[Parse.nameKey("Duke — MEng BME")].map { cal.isoDay($0.date) }, "2026-11-03")
        let eth = try XCTUnwrap(deadlines[Parse.nameKey("ETH Zurich - MSc ITET and MSc BME")])
        XCTAssertEqual(cal.isoStamp(eth.date), "2026-11-30T11:59:00+01:00")
        XCTAssertTrue(eth.hasTime)
        XCTAssertEqual(deadlines[Parse.nameKey("Thames — MSc AI")].map { cal.isoDay($0.date) }, "2027-01-06")
        XCTAssertNil(Parse.looseDate("31 Foo 2026", cal))
        XCTAssertNil(Parse.looseDate("32 Nov 2026", cal))
        XCTAssertNil(Parse.looseDate("3 Nov 2026, 25:00", cal))
        XCTAssertEqual(Parse.looseDate("12 dic 2026", cal).map { cal.isoDay($0.date) }, "2026-12-12")
    }

    func testSectionsByHeadingLevel() {
        let text = "# Doc\n## Group A\n### One\nalpha\n#### Detail\nmore\n### Two\nbeta\n## Group B\n### Three\ngamma"
        XCTAssertEqual(Parse.section(text, heading: "One"), "alpha\n#### Detail\nmore")
        XCTAssertEqual(Parse.section(text, heading: "two"), "beta")
        XCTAssertEqual(Parse.section(text, heading: "Group A")?.contains("Three"), false)
        XCTAssertNil(Parse.section(text, heading: "Four"))
        XCTAssertEqual(Parse.section("### **Ünï** — X\nbody", heading: "Uni - X"), "body")
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

    func testStudyLists() throws {
        let cal = DeskCalendar(timeZone: "Europe/Madrid")
        let text = """
        ---
        exam: Statics
        ---
        ## This weekend — due 2026-11-15
        ### Classes
        - [ ] Session 5 · Multiple choice · 105 min
        - [x] Session 6 · 117 min
        ### Sheets
        - [ ] Sheet 1
        ## Theory
        - [ ] T1 Statics
        ## Overdue bits
        - [ ] A loose item
        ## Notes
        Plain text, no boxes.
        """
        let study = try XCTUnwrap(Parse.study(text, cal))
        XCTAssertEqual(study.lists.map(\.title), ["This weekend", "Overdue bits"])
        XCTAssertEqual(study.lists[0].due, Parse.day("2026-11-15", cal))
        XCTAssertEqual(study.lists[0].groups.map(\.title), ["Classes", "Sheets"])
        XCTAssertEqual(study.lists[0].items.map(\.done), [false, true, false])
        // "Overdue" is not a due date, and a list without `###` is one group named like the list.
        XCTAssertNil(study.lists[1].due)
        XCTAssertEqual(study.lists[1].groups.map(\.title), ["Overdue bits"])
        XCTAssertEqual(study.theory.map(\.title), ["T1 Statics"])
        XCTAssertEqual(Derived.minutes(study.lists[0].items[0]), 105)
        XCTAssertEqual(Parse.study("## Week — due 15 Nov 2026\n- [ ] One", cal)?.lists.first?.due, Parse.day("2026-11-15", cal))
        // Checkboxes, by hand: indented, starred, or not a box at all.
        XCTAssertEqual(Parse.checkbox("  * [X] Done")?.done, true)
        XCTAssertEqual(Parse.checkbox("- [ ] Spaced  ")?.title, "Spaced")
        XCTAssertNil(Parse.checkbox("- [ ]"))
        XCTAssertNil(Parse.checkbox("- [y] No"))
        XCTAssertNil(Parse.checkbox("-[ ] No"))
    }

    func testInternshipBoardExport() throws {
        let cal = DeskCalendar(timeZone: "Europe/Madrid")
        let json = """
        {"openings": [
          {"id": "o2", "order": 2, "company": "Helix Diagnostics", "title": "Data Science Intern", "location": "Basel", "start": "Jan 2027",
           "duration": "6 months", "language": "English", "eligType": "graduate", "eligibility": "Bachelor's within 12 months",
           "fit": "Biosignals", "url": "https://example.com/helix", "status": "Applied", "notes": "Sent 3 Nov\\n[12 Nov] looks closed?"},
          {"id": "o1", "order": 1, "company": "Pulsewave", "title": "Biosignals Intern", "location": "Madrid", "eligType": "convenio",
           "url": "https://example.com/pulse", "status": "Not started"}],
         "targets": {"t1": {"name": "Corvid Lab", "city": "Zürich", "status": "Interview booked"}, "t2": {"location": "Nowhere"}}}
        """
        let targets = try XCTUnwrap(Parse.board(json, cal))
        // Openings in the board's order, then the targets; a target without a name is skipped.
        XCTAssertEqual(targets.map(\.company), ["Pulsewave", "Helix Diagnostics", "Corvid Lab"])
        XCTAssertEqual(targets.map(\.list), ["apply_now", "apply_now", "target"])
        XCTAssertEqual(targets.map(\.status), ["open", "applied", "interview"])
        XCTAssertEqual(targets[1].statusLabel, "Applied")
        XCTAssertEqual(targets[1].next, "Sent 3 Nov")
        XCTAssertEqual(targets.map(\.graduateOk), [false, true, nil])
        XCTAssertEqual(targets[1].url, "https://example.com/helix")
        XCTAssertEqual(targets[1].duration, "6 months")
        XCTAssertEqual(targets[2].id, "target-t1")
        XCTAssertNil(Parse.board("[1, 2]", cal))
    }

    func testSettingABoardStatusChangesOneLine() throws {
        let text = """
        {
          "openings": [
            {
              "company": "Helix Diagnostics",
              "id": "o1",
              "status": "Not started",
              "url": "https://example.com/helix"
            },
            {
              "company": "Pulsewave",
              "id": "o10",
              "status": "Applied"
            }
          ]
        }
        """
        let changed = try XCTUnwrap(Parse.setBoardStatus(text, id: "o1", status: "Interviewing"))
        let before = Parse.splitLines(text), after = Parse.splitLines(changed)
        XCTAssertEqual(zip(before, after).filter { $0 != $1 }.count, 1, "only the status line changes")
        XCTAssertTrue(changed.contains("\"status\": \"Interviewing\","))
        // "o1" is not "o10"; a status that is the object's last key keeps its missing comma.
        let last = try XCTUnwrap(Parse.setBoardStatus(text, id: "o10", status: "Rejected / closed"))
        XCTAssertTrue(last.contains("\"status\": \"Rejected / closed\"\n"))
        XCTAssertTrue(last.contains("\"status\": \"Not started\","))
        XCTAssertNil(Parse.setBoardStatus(text, id: "o2", status: "Applied"))
        XCTAssertEqual(Parse.board(changed, DeskCalendar(timeZone: "Europe/Madrid"))?.first?.status, "interview")
    }

    func testStudentRowAndContactsWrites() throws {
        let table = "| Initials | Level | Subject | Rate (€/h) | Pays by |\n|---|---|---|---|---|\n| AB | 2º Bach |  | 25 | Bizum |\n| CD | ESO | Physics | 22 | cash |\n"
        let changed = try XCTUnwrap(Parse.updateStudentRow(table, initials: "AB", subject: "Maths | Physics", paysBy: "bank transfer"))
        XCTAssertTrue(changed.contains("| AB | 2º Bach | Maths / Physics | 25 | bank transfer |"))
        XCTAssertTrue(changed.contains("| CD | ESO | Physics | 22 | cash |"))
        XCTAssertNil(Parse.updateStudentRow(table, initials: "ZZ", subject: "x"))
        let json = Parse.contactsJSON(["AB": TutoringContact(parent: "Ana", student: "Álex", phone: "+34 600")])
        XCTAssertEqual(Parse.json([String: TutoringContact].self, json, DeskCalendar(timeZone: "UTC"))?["AB"]?.phone, "+34 600")
    }

    func testLessonsCSV() {
        let rows = Parse.lessons("month,initials,student,lessons,hours,rate,amount\n2026-10,AB,Ana Blanco,4,4.5,30,135\n2026-09,CD,Carlos,2,2,,\nnot a row\n")
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows.first?.amount, 135)
        XCTAssertEqual(rows.first?.student, "Ana Blanco")
        XCTAssertNil(rows.last?.rate)
        XCTAssertNil(rows.last?.amount)
        let cal = DeskCalendar(timeZone: "Europe/Madrid")
        let dates = Parse.lessonDates("date,initials,hours\n2026-11-09,AB,1.5\n2026-13-01,AB,1\nnot a row\n", cal)
        XCTAssertEqual(dates.map(\.hours), [1.5])
        XCTAssertEqual(dates.first?.date, Parse.day("2026-11-09", cal))
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
            VaultData.snapshotFile: "<html>", VaultData.settingsFile: "{", VaultData.boardFile: "nope",
        ])
        let data = VaultData.load(reader)
        XCTAssertEqual(data.rows, [])
        XCTAssertNil(data.targets)
        XCTAssertEqual(data.hint(VaultData.snapshotFile), "agent/snapshot.json could not be read.")
        XCTAssertEqual(data.hint(VaultData.settingsFile), "desk/settings.json could not be read.")
        XCTAssertEqual(data.hint(VaultData.boardFile), "internships/board.json could not be read.")
    }
}
