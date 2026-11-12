import XCTest
@testable import Desk

/// The Classes importer, on invented notes: who each note is about, dates, initials, anonymising,
/// and what it may write.
final class ClassesImportTests: XCTestCase {
    let cal = DeskCalendar(timeZone: "Europe/Madrid")

    func day(_ iso: String) -> Date { Parse.day(iso, cal) ?? Date() }

    /// Notes puts the title on the body's first line.
    func note(_ title: String, _ body: String, folder: String? = nil, created: String = "2026-11-12") -> ClassesImport.Note {
        ClassesImport.Note(folder: folder, title: title, body: title + "\n" + body, created: day(created))
    }

    func dates(_ entries: [ClassesImport.Entry]?) -> [String] { (entries ?? []).map { cal.isoDay($0.date) } }

    func testStudentNamesFromTitles() {
        XCTAssertEqual(ClassesImport.studentName(inTitle: "Álex 12/11"), "Álex")
        XCTAssertEqual(ClassesImport.studentName(inTitle: "12/11/2026 - Carla - Física"), "Carla")
        XCTAssertEqual(ClassesImport.studentName(inTitle: "Clase con Emma, 3 nov"), "Emma")
        XCTAssertEqual(ClassesImport.studentName(inTitle: "Martes 18/11 Lucas Romero: integrales"), "Lucas Romero")
        XCTAssertEqual(ClassesImport.studentName(inTitle: "2026-11-02 Álex"), "Álex")
        XCTAssertNil(ClassesImport.studentName(inTitle: "02/11/2026"))
        XCTAssertNil(ClassesImport.studentName(inTitle: "Clase 12/11"))
    }

    func testInitialsAndCollisions() {
        let notes = [
            note("Álex Bermúdez 2/11", "Integrales."), note("Carla 4/11", "Fuerzas."),
            note("Carmen 5/11", "Óptica."), note("álex bermudez 9/11", "Examen."),
        ]
        let result = ClassesImport.run(notes, contacts: [:], cal: cal)
        XCTAssertEqual(Set(result.students.keys), ["AB", "CA", "CA2"])
        XCTAssertEqual(dates(result.students["AB"]), ["2026-11-02", "2026-11-09"])
        XCTAssertFalse(result.bySubfolder)
    }

    func testContactsGiveTheInitialsAndEveryNameGoes() throws {
        let contacts = ["XY": TutoringContact(parent: "Marta", student: "Álex", phone: "+34600000001")]
        let notes = [note("Álex 2/11", "Álex did integrals; MARTA paid. Call Marta on 600 123 456 or marta@example.com.")]
        let result = ClassesImport.run(notes, contacts: contacts, cal: cal)
        let text = try XCTUnwrap(result.students["XY"]?.first?.text)
        XCTAssertEqual(text, "XY did integrals; XY paid. Call XY on [phone] or [email].")
        // The fourth "Marta" was inside the email address, which goes as a whole.
        XCTAssertEqual(result.namesRemoved, 3)
        XCTAssertEqual(result.emailsRemoved, 1)
        XCTAssertEqual(result.phonesRemoved, 1)
    }

    func testARunningLogSplitsByDatedLines() {
        let body = "12/11: Derivadas.\n3/4 of the exercises right.\n## 2026-11-14\nIntegrales.\nMartes 18/11\nRepaso.\n- 20 nov - Examen"
        let result = ClassesImport.run([note("Emma", body)], contacts: [:], cal: cal)
        let entries = result.students["EM"] ?? []
        XCTAssertEqual(dates(entries), ["2026-11-12", "2026-11-14", "2026-11-18", "2026-11-20"])
        XCTAssertEqual(entries.map(\.text), ["Derivadas.\n3/4 of the exercises right.", "Integrales.", "Repaso.", "Examen"])
        XCTAssertEqual(result.datedByText, 4)
    }

    func testUndatedNotesUseTheCreationDateAndYearsAreInferred() {
        let notes = [note("Lucas", "Química.", created: "2026-10-30"), note("Lucas 28/12", "Repaso.", created: "2027-01-03")]
        let result = ClassesImport.run(notes, contacts: [:], cal: cal)
        XCTAssertEqual(dates(result.students["LU"]), ["2026-10-30", "2026-12-28"])
        XCTAssertEqual(result.datedByCreation, 1)
        XCTAssertEqual(result.datedByText, 1)
        XCTAssertNil(ClassesImport.handDate(in: "31/11", atStart: true).flatMap { ClassesImport.date($0, near: self.day("2026-12-01"), cal: self.cal) })
    }

    func testSubfoldersNameTheStudent() {
        let notes = [note("12/11", "Funciones.", folder: "Álex Bermúdez"), note("Sin fecha", "Repaso.", folder: "2025-26/Carla")]
        let result = ClassesImport.run(notes, contacts: [:], cal: cal)
        XCTAssertEqual(Set(result.students.keys), ["AB", "CA"])
        XCTAssertTrue(result.bySubfolder)
    }

    func testNotesWithoutAStudentAreCountedNotGuessed() {
        let result = ClassesImport.run([note("12/11", "Something."), note("Emma 1/11", "Ok.")], contacts: [:], cal: cal)
        XCTAssertEqual(result.unmatched, 1)
        XCTAssertEqual(Array(result.students.keys), ["EM"])
    }

    func testRenderRoundTripsThroughTheNotesParser() {
        let result = ClassesImport.run([note("Emma 2/11", "Límites."), note("Emma 9/11", "Derivadas.\nBien.")], contacts: [:], cal: cal)
        let file = ClassesImport.render(result.students["EM"] ?? [], cal: cal)
        XCTAssertTrue(file.hasPrefix(ClassesImport.marker))
        let parsed = Parse.notes(file, cal)
        XCTAssertEqual(parsed.map { cal.isoDay($0.date) }, ["2026-11-02", "2026-11-09"])
        XCTAssertEqual(parsed.map(\.text), ["Límites.", "Derivadas.\nBien."])
    }

    /// Nothing written or printed carries a name or a line of the notes.
    func testNoNamesInFilesOrTheReport() {
        let contacts = ["AB": TutoringContact(parent: "Marta Gómez", student: "Álex Bermúdez", phone: "+34600000001")]
        let notes = [note("Álex Bermúdez 2/11", "Marta Gómez asked about Bermúdez's exam."), note("Carla Núñez 3/11", "Carla: óptica.")]
        let result = ClassesImport.run(notes, contacts: contacts, cal: cal)
        let files = result.students.values.map { ClassesImport.render($0, cal: cal) }.joined()
        let report = ClassesImport.report(result, dryRun: true, writeCheck: nil, written: nil, cal: cal)
        for name in ["alex", "bermudez", "marta", "gomez", "carla", "nunez"] {
            XCTAssertFalse(Parse.nameKey(files).contains(name), name)
            XCTAssertFalse(Parse.nameKey(report).contains(name), name)
        }
        XCTAssertFalse(report.contains("óptica"))
    }

    func testWriteKeepsHandWrittenFilesAndCreatesStudentsOnce() throws {
        let fm = FileManager.default
        let vault = fm.temporaryDirectory.appendingPathComponent("desk-classes-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: vault) }
        let notesFolder = vault.appendingPathComponent("tutoring/notes")
        try fm.createDirectory(at: notesFolder, withIntermediateDirectories: true)
        try "## 2026-11-01\nMy own note.\n".write(to: notesFolder.appendingPathComponent("EM.md"), atomically: true, encoding: .utf8)

        let result = ClassesImport.run([note("Emma 2/11", "A."), note("Lucas 3/11", "B.")], contacts: [:], cal: cal)
        let first = try ClassesImport.write(result, to: vault, cal: cal)
        XCTAssertEqual(first.written, ["tutoring/notes/LU.md"])
        XCTAssertEqual(first.skipped, ["tutoring/notes/EM.md"])
        XCTAssertTrue(first.createdStudents)
        XCTAssertEqual(try String(contentsOf: notesFolder.appendingPathComponent("EM.md"), encoding: .utf8), "## 2026-11-01\nMy own note.\n")
        XCTAssertEqual(Parse.students(try String(contentsOf: vault.appendingPathComponent(VaultData.studentsFile), encoding: .utf8)).map(\.initials), ["EM", "LU"])

        // A second import replaces its own file and leaves students.md alone.
        let again = try ClassesImport.write(ClassesImport.run([note("Lucas 4/11", "C.")], contacts: [:], cal: cal), to: vault, cal: cal)
        XCTAssertEqual(again.written, ["tutoring/notes/LU.md"])
        XCTAssertFalse(again.createdStudents)
        XCTAssertTrue(try String(contentsOf: notesFolder.appendingPathComponent("LU.md"), encoding: .utf8).contains("## 2026-11-04"))
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
