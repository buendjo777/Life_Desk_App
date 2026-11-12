import XCTest
@testable import Desk

/// The Classes importer on an invented note in Jose's layout: a heading per month, each student's name, the
/// dates of their lessons (x0.5 and x1.5 for 30 and 90 minutes) and the month's total under it.
final class ClassesImportTests: XCTestCase {
    let cal = DeskCalendar(timeZone: "Europe/Madrid")
    lazy var today = Parse.day("2026-11-12", cal) ?? Date()

    /// Invented names and numbers. September fits 30 and 25 €/h; October adds a student at 40.
    let note = """
    Classes
    Septiembre 2025
    Álex Bermúdez
    3/9, 10/9 x1.5, 17/9
    Carla
    4/9, 11/9
    Total: 155€

    Octubre
    Álex
    1, 8, 15x0,5
    Carla
    2/10 (Bizum)
    Abril
    6/10, 13/10
    Total octubre: 180 €

    Noviembre
    Álex: 5/11, 12/11
    Carla - 6/11
    Vacaciones de Carla

    Diciembre 2025
    Álex
    3/12
    Total: 47€

    Enero
    Carla
    8/1 (x1.5)
    Total: 1.250,00 €
    """

    func sorted() -> ClassesImport.Result {
        ClassesImport.sort(ClassesImport.parse(note, title: "Classes"), today: today, cal: cal)
    }

    func row(_ result: ClassesImport.Result, _ month: String, _ code: String) -> ClassesImport.Row? {
        result.rows.first { $0.month == month && $0.code == code }
    }

    func testMonthsYearsAndShape() {
        let log = ClassesImport.parse(note, title: "Classes")
        XCTAssertEqual(log.months.map(\.month), [9, 10, 11, 12, 1])
        XCTAssertEqual(ClassesImport.assignYears(log.months, today: today, cal: cal), [2025, 2025, 2025, 2025, 2026])
        XCTAssertEqual(log.shape, "MSDSDTBMSDSDSDTBMSS?BMSDTBMSDT")
        XCTAssertEqual(log.unrecognised, 1)
    }

    func testLessonsHoursAndInitials() throws {
        let result = sorted()
        XCTAssertEqual(result.students, ["AB", "AB2", "CA"])
        let september = try XCTUnwrap(row(result, "2025-09", "AB"))
        XCTAssertEqual(september.lessons, 3)
        XCTAssertEqual(september.hours, 3.5)
        // "Álex" alone is the same student as "Álex Bermúdez"; "15x0,5" is half an hour.
        XCTAssertEqual(row(result, "2025-10", "AB")?.hours, 2.5)
        XCTAssertEqual(row(result, "2025-10", "AB2")?.lessons, 2)
        XCTAssertEqual(row(result, "2026-01", "CA")?.hours, 1.5)
    }

    func testRatesAreFittedToEachMonthsTotal() {
        let result = sorted()
        XCTAssertEqual(row(result, "2025-09", "AB")?.rate, 30)
        XCTAssertEqual(row(result, "2025-09", "CA")?.rate, 25)
        XCTAssertEqual(row(result, "2025-10", "AB2")?.rate, 40)
        XCTAssertEqual(row(result, "2025-10", "AB")?.rate, 30)
        XCTAssertEqual(result.months.first { $0.month == "2025-10" }?.fits, true)
        // No total in November: last month's rates carry over.
        XCTAssertEqual(row(result, "2025-11", "AB")?.amount, 60)
        XCTAssertTrue(result.checks.contains { $0.hasPrefix("2025-11: no total under it") })
        // 47 € for one hour fits no rate: flagged, with the closest.
        XCTAssertTrue(result.checks.contains { $0.hasPrefix("2025-12: no mix") && $0.contains("closest is 50") })
        XCTAssertEqual(result.months.first { $0.month == "2025-12" }?.fits, false)
        XCTAssertTrue(result.checks.contains { $0.contains("1 lines weren't understood") })
    }

    func testAmountsAndOddLines() {
        XCTAssertEqual(ClassesImport.amount("1.250,50"), 1250.5)
        XCTAssertEqual(ClassesImport.amount("1.250"), 1250)
        XCTAssertEqual(ClassesImport.amount("62.5"), 62.5)
        XCTAssertEqual(ClassesImport.splitAmount("Álex: 3/11, 5/11 = 100€").amount, 100)
        XCTAssertEqual(ClassesImport.splitAmount("€450").amount, 450)
        XCTAssertEqual(ClassesImport.lessons(in: "3/11, 5/11 x1.5, 12/11 x0,5", month: 11).lessons.map(\.hours), [1, 1.5, 0.5])
        XCTAssertEqual(ClassesImport.lessons(in: "3/10, 5/11", month: 11).outside, 1)
        XCTAssertNil(ClassesImport.monthHeading("Mar"))
        XCTAssertEqual(ClassesImport.monthHeading("Mar 2026")?.month, 3)
        XCTAssertNil(ClassesImport.monthHeading("Octubre 3"))
        XCTAssertEqual(ClassesImport.monthHeading("2026-11")?.year, 2026)
    }

    func testNewestFirstNotesGetTheRightYears() {
        let log = ClassesImport.parse("Febrero\nAna\n2/2\nEnero\nAna\n5/1\nDiciembre\nAna\n1/12")
        XCTAssertEqual(ClassesImport.assignYears(log.months, today: today, cal: cal), [2026, 2026, 2025])
    }

    func testAStudentNamedLikeAMonth() {
        let log = ClassesImport.parse("Abril\nMarta\n3/4\nAbril\n4/4, 5/4")
        XCTAssertEqual(log.months.count, 1)
        XCTAssertEqual(log.months.first?.students.map(\.name), ["Marta", "Abril"])
    }

    /// Nothing written or printed carries a name or a word of the note.
    func testNoNamesInTheReviewOrTheReport() {
        let result = sorted()
        let review = ClassesImport.review(result)
        let report = ClassesImport.report(result, notes: 1, dryRun: true, writeCheck: nil, written: nil)
        for word in ["alex", "bermudez", "carla", "abril", "vacaciones", "bizum"] {
            XCTAssertFalse(Parse.nameKey(review).contains(word), word)
            XCTAssertFalse(Parse.nameKey(report).contains(word), word)
        }
        XCTAssertTrue(review.hasPrefix(ClassesImport.marker))
    }

    func testWriteReplacesOnlyItsOwnFile() throws {
        let fm = FileManager.default
        let vault = fm.temporaryDirectory.appendingPathComponent("desk-classes-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: vault) }
        XCTAssertEqual(try ClassesImport.write(sorted(), to: vault), ClassesImport.reviewFile)
        XCTAssertEqual(try ClassesImport.write(sorted(), to: vault), ClassesImport.reviewFile)
        let url = vault.appendingPathComponent(ClassesImport.reviewFile)
        try "My own notes.\n".write(to: url, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try ClassesImport.write(sorted(), to: vault))
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "My own notes.\n")
    }

    /// The structure view hides every word and number but the generic ones.
    func testMaskHidesNamesAndNumbers() {
        XCTAssertEqual(ClassesImport.mask("Álex Bermúdez: 3/10, 5/10 x1,5"), "A A: 9/9, 9/9 x9,9")
        XCTAssertEqual(ClassesImport.mask("Octubre 2023"), "MES 9")
        XCTAssertEqual(ClassesImport.mask("Lunes 3 y martes 5"), "DIA 9 a DIA 9")
        XCTAssertEqual(ClassesImport.mask("TOTAL: 1.250 euros"), "TOTAL: 9.9 EUR")
        XCTAssertEqual(ClassesImport.mask("Mar le debe 20€"), "A a a 9€")
        // Month names show by design, so "Abril" (a month as well as a name) is not checked here.
        let report = ClassesImport.shapeReport(note, title: "Classes")
        for word in ["alex", "bermudez", "carla", "vacaciones", "bizum"] {
            XCTAssertFalse(Parse.nameKey(report).contains(word), word)
        }
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
