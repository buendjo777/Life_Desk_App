import XCTest
@testable import Desk

/// The Classes importer on an invented note in Jose's layout: month headings, "Name (rate): (dd/mm)x1.5",
/// month and family totals, an invoice recap, and lines to ignore. Every name and number here is made up.
final class ClassesImportTests: XCTestCase {
    let cal = DeskCalendar(timeZone: "Europe/Madrid")
    lazy var today = Parse.day("2026-01-20", cal) ?? Date()

    let settingsJSON = """
    {"rates": {"Nora": 30}, "families": {"Vidal": ["Ivo", "Eva"]}, "parents": {"Nora": "Marta"},
     "ignore": ["Tom"], "paid_through": "2025-10", "current_months": 2}
    """

    let note = """
    Classes
    Pablo Ruiz Gómez
    IBAN ES00 1234 5678 9012 3456 7890
    2025:
    September:
    IB HL:
    * Lucas Moreno (50): (03/09), (10/09)x1.5
    * Nora: ((04/09), 11/09)
    Total for September: 185€
    October:
    Lucas: (01/10), (08/10), (15/10)x0.5
    Tom: (09/10)
    Nora (40): (02/10)
    Ivo Vidal: (35/40): (06/10), (13/10)
    Total for October: 235€
    Eva: (29,10)
    Total for October (Vidal): 105€
    November:
    Lucas: 3 lessons
    Nora: (05/11), (12/11) 80€
    Eva: (06/11)
    TOTAL Vidal: 35€
    December:
    Lucas: (03/12)
    Total: 50€
    October:
    Lucas: (01/10), (08/10), (15/10)x0.5
    Nora: (02/10)
    2026:
    January:
    Nora: (08/01)x1.5
    Total for January: 60€
    """

    func sorted() -> ClassesImport.Result {
        ClassesImport.sort(ClassesImport.parse(note), settings: .load(settingsJSON), today: today, cal: cal)
    }

    func row(_ result: ClassesImport.Result, _ month: String, _ code: String) -> ClassesImport.Row? {
        result.rows.first { $0.month == month && $0.code == code }
    }

    func testReadsTheLayout() {
        let parsed = ClassesImport.parse(note)
        XCTAssertEqual(parsed.blocks.map(\.month), [9, 10, 11, 12, 10, 1])
        XCTAssertEqual(parsed.blocks.map(\.year), [2025, nil, nil, nil, nil, 2026])
        // The title, the name line and the bank line.
        XCTAssertEqual(parsed.ignored, 3)
        let october = parsed.blocks[1]
        XCTAssertEqual(october.entries.map(\.name), ["Lucas", "Tom", "Nora", "Ivo Vidal", "Eva"])
        XCTAssertEqual(october.totals.map(\.upto), [4, 5])
        XCTAssertEqual(october.totals.map(\.family), [nil, "Vidal"])
        XCTAssertEqual(parsed.blocks[2].totals.first?.family, "Vidal")
        XCTAssertEqual(parsed.blocks[0].entries.map(\.hours), [2.5, 2])
        XCTAssertEqual(parsed.blocks[0].entries.first?.group, "IB HL")
    }

    func testOddLines() throws {
        let two = try XCTUnwrap(ClassesImport.entry(from: "Omar: (65/70): (05/10)"))
        XCTAssertEqual(two.rate, 65)
        XCTAssertTrue(two.twoRates)
        let comma = try XCTUnwrap(ClassesImport.entry(from: "Lina (30): (03/02), (10/02)x1,5"))
        XCTAssertEqual(comma.rate, 30)
        XCTAssertEqual(comma.hours, 2.5)
        let counted = try XCTUnwrap(ClassesImport.entry(from: "Hugo Brand: 2 classes 50€"))
        XCTAssertEqual(counted.lessonCount, 2)
        XCTAssertEqual(counted.amount, 50)
        XCTAssertEqual(ClassesImport.entry(from: "Hugo: (+ 2 septiembre)")?.extras, 2)
        XCTAssertNil(ClassesImport.entry(from: "Hola, te escribo por lo de esta semana"))
        XCTAssertNil(ClassesImport.entry(from: "Hugo Brand y su hermana mayor: (03/02)"), "more than three words is not a name")
        XCTAssertEqual(ClassesImport.family(in: "Total for January (Brand)"), "Brand")
        XCTAssertEqual(ClassesImport.family(in: "TOTAL Brand: 150€"), "Brand")
        XCTAssertNil(ClassesImport.family(in: "Total for November+December: 300€"))
    }

    func testRatesFollowTheNoteThenTheSettingsThenTheTotals() {
        let result = sorted()
        XCTAssertEqual(result.current, ["LM", "NO"])
        XCTAssertEqual(result.archived, ["IV", "EV"])
        XCTAssertEqual(result.names["LM"], "Lucas Moreno")
        // A number in the note.
        XCTAssertEqual(row(result, "2025-09", "LM")?.rate, 50)
        // Jose's rate from import.json, until the note writes one.
        XCTAssertEqual(row(result, "2025-09", "NO")?.rate, 30)
        XCTAssertEqual(row(result, "2025-10", "NO")?.rate, 40)
        // Fitted to the month's total, which counts every student above it.
        XCTAssertEqual(row(result, "2025-10", "LM")?.hours, 2.5)
        XCTAssertEqual(row(result, "2025-10", "LM")?.rate, 50)
        // Family totals: by surname (Ivo Vidal) and by import.json (Eva).
        XCTAssertEqual(row(result, "2025-10", "EV")?.rate, 35)
        XCTAssertEqual(row(result, "2025-11", "EV")?.rate, 35)
        // An amount on the line.
        XCTAssertEqual(row(result, "2025-11", "NO")?.rate, 40)
        // No total: the previous rate.
        XCTAssertEqual(row(result, "2025-11", "LM")?.amount, 150)
        XCTAssertEqual(row(result, "2026-01", "NO")?.amount, 60)
        XCTAssertEqual(result.rows.compactMap(\.amount).reduce(0, +), 830)
        XCTAssertEqual(result.rows.map(\.lessons).reduce(0, +), 19)
        // The ignored student and the recap list are left out.
        XCTAssertFalse(result.names.values.contains("Tom"))
        XCTAssertEqual(result.recaps, 1)
        XCTAssertEqual(result.checks, ["2025-10: Ivo Vidal has two rates written; 35 used."])
    }

    func testYearsComeFromTheNewestMonth() {
        let parsed = ClassesImport.parse("2023:\nSeptember:\nAna: (03/09)\nApril:\nAbril: (04/04), (05/04)")
        XCTAssertEqual(parsed.blocks.map(\.month), [9, 4])
        XCTAssertEqual(parsed.blocks.last?.entries.map(\.name), ["Abril"], "a student named like a month")
        let settings = ClassesImport.Settings.load(#"{"rates": {"Ana": 40, "Abril": 40}}"#)
        let result = ClassesImport.sort(parsed, settings: settings, today: Parse.day("2025-11-12", cal) ?? Date(), cal: cal)
        XCTAssertEqual(result.rows.map(\.month), ["2024-09", "2025-04"])
        XCTAssertEqual(result.checks, ["2024-09: the note writes 2023 before this month."])
    }

    func testFittingRates() throws {
        let fit = try XCTUnwrap(ClassesImport.fitRates([2, 1], 105, [nil, nil]))
        XCTAssertTrue(fit.exact)
        XCTAssertTrue(fit.ambiguous)
        XCTAssertEqual(fit.rates, [35, 35])
        // A student's previous rate breaks the tie.
        XCTAssertEqual(ClassesImport.fitRates([2, 1], 105, [40, nil])?.rates, [40, 25])
        XCTAssertEqual(ClassesImport.fitRates([1], 47, [nil])?.exact, false)
        XCTAssertNil(ClassesImport.fitRates([1, 1, 1, 1, 1, 1], 300, Array(repeating: nil, count: 6)))
    }

    func testTheReportHasNoNames() {
        let report = ClassesImport.report(sorted())
        let words = Set(ClassesImport.words(report))
        for name in ["lucas", "moreno", "nora", "ivo", "vidal", "eva", "tom", "pablo", "marta"] {
            XCTAssertFalse(words.contains(name), name)
        }
        XCTAssertTrue(report.contains("2025: 18 lessons, 770 €"))
        XCTAssertTrue(report.contains("€/h: LM 50; NO 30→40; IV 35; EV 35"))
        XCTAssertTrue(report.contains("- 2025-10: IV has two rates written; 35 used."))
        XCTAssertEqual(ClassesImport.redact("2023-02: the De la Cruz total of 120 €.", names: [:]), "2023-02: the D. la C. total of 120 €.")
    }

    func testWritesTutoringAndKeepsWhatDeskRecorded() throws {
        let fm = FileManager.default
        let vault = fm.temporaryDirectory.appendingPathComponent("desk-classes-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: vault) }
        let settings = ClassesImport.Settings.load(settingsJSON)
        func read(_ path: String) throws -> String { try String(contentsOf: vault.appendingPathComponent(path), encoding: .utf8) }
        func save(_ path: String, _ text: String) throws { try text.write(to: vault.appendingPathComponent(path), atomically: true, encoding: .utf8) }
        try ClassesImport.write(sorted(), settings: settings, to: vault, today: today, cal: cal)

        let lessons = Parse.splitLines(try read(ClassesImport.lessonsFile)).filter { !$0.isEmpty }
        XCTAssertEqual(lessons.count, 12)
        XCTAssertTrue(lessons.contains("2025-10,LM,Lucas Moreno,3,2.5,50,125"))
        // Every dated lesson on its day: not the recap, not the ignored student, not "3 lessons" without dates.
        let dates = Parse.splitLines(try read(ClassesImport.lessonDatesFile)).filter { !$0.isEmpty }
        XCTAssertEqual(dates.count, 17)
        XCTAssertEqual(dates[1], "2025-09-03,LM,1")
        XCTAssertEqual(dates.last, "2026-01-08,NO,1.5")
        XCTAssertFalse(dates.contains { $0.hasPrefix("2025-10-09") })
        let term = Parse.payments(try read(VaultData.paymentsFile), cal)
        XCTAssertEqual(term.map(\.id), ["2025-12-LM"])
        XCTAssertNil(term.first?.paid)
        let archive = Parse.payments(try read(ClassesImport.paymentsArchiveFile), cal)
        XCTAssertEqual(archive.count, 9)
        XCTAssertEqual(archive.first { $0.id == "2025-10-IV" }?.paid, Parse.day("2025-10-31", cal))
        XCTAssertNil(archive.first { $0.id == "2025-11-NO" }?.paid)
        let students = Parse.students(try read(VaultData.studentsFile))
        XCTAssertEqual(students.map(\.initials), ["LM", "NO"])
        XCTAssertEqual(students.map(\.rate), [50, 40])
        XCTAssertEqual(students.first?.level, "IB HL")
        XCTAssertTrue(try read(ClassesImport.studentsArchiveFile).contains("| Ivo Vidal | IV |"))
        var contacts = try XCTUnwrap(Parse.json([String: TutoringContact].self, try read(VaultData.tutoringContactsFile), cal))
        XCTAssertEqual(contacts["NO"], TutoringContact(parent: "Marta", student: "Nora", phone: ""))
        XCTAssertTrue(try read(ClassesImport.reviewFile).contains("| Lucas Moreno | IB HL | 2025-09 | 2025-12 |"))

        // Desk records a phone number, a payment and this month's invoice; the next import keeps all three.
        contacts["NO"]?.phone = "+34 600 000 000"
        try save(VaultData.tutoringContactsFile, String(decoding: try JSONEncoder().encode(contacts), as: UTF8.self))
        var paid = archive
        if let i = paid.firstIndex(where: { $0.id == "2025-11-NO" }) { paid[i].paid = Parse.day("2025-12-04", cal) }
        try save(ClassesImport.paymentsArchiveFile, Parse.paymentsCSV(paid, cal))
        let invoice = Payment(month: "2026-01", initials: "NO", lessons: 1, hours: 1.5, amount: 60, sent: today, paid: nil)
        try save(VaultData.paymentsFile, Parse.paymentsCSV(term + [invoice], cal))
        try ClassesImport.write(sorted(), settings: settings, to: vault, today: today, cal: cal)

        // Months before last month are settled: a different reading of the note does not rewrite them.
        var changed = sorted()
        changed.rows[0].lessons = 99
        changed.rows[changed.rows.count - 1].lessons = 7
        try ClassesImport.write(changed, settings: settings, to: vault, today: today, cal: cal)
        let again = Parse.splitLines(try read(ClassesImport.lessonsFile)).filter { !$0.isEmpty }
        XCTAssertEqual(again.count, 12)
        XCTAssertTrue(again.contains("2025-09,LM,Lucas Moreno,2,2.5,50,125"), "September stays as first written")
        XCTAssertTrue(again.contains("2026-01,NO,Nora,7,1.5,40,60"), "this month follows the note")
        XCTAssertEqual(Parse.splitLines(try read(ClassesImport.lessonDatesFile)).filter { !$0.isEmpty }.count, 17)

        let after = Parse.json([String: TutoringContact].self, try read(VaultData.tutoringContactsFile), cal)
        XCTAssertEqual(after?["NO"]?.phone, "+34 600 000 000")
        let archived = Parse.payments(try read(ClassesImport.paymentsArchiveFile), cal)
        XCTAssertEqual(archived.first { $0.id == "2025-11-NO" }?.paid, Parse.day("2025-12-04", cal))
        XCTAssertEqual(Parse.payments(try read(VaultData.paymentsFile), cal).map(\.id), ["2025-12-LM", "2026-01-NO"])
    }

    func testRefusesAVaultWhereTutoringIsNotIgnored() throws {
        let fm = FileManager.default
        let repo = fm.temporaryDirectory.appendingPathComponent("desk-ignore-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: repo) }
        try fm.createDirectory(at: repo, withIntermediateDirectories: true)
        XCTAssertNotNil(ClassesImport.refusal(for: repo), "not a git repo")
        try Git(root: repo).run(["init", "-q"])
        XCTAssertTrue(ClassesImport.refusal(for: repo)?.contains(".gitignore") == true)
        try "tutoring/\n".write(to: repo.appendingPathComponent(".gitignore"), atomically: true, encoding: .utf8)
        XCTAssertNil(ClassesImport.refusal(for: repo))
        XCTAssertNotNil(ClassesImport.refusal(for: DemoVault.url))
    }
}
