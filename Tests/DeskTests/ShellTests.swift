import XCTest
@testable import Desk

final class ShellTests: XCTestCase {
    func testEightTabsInShortcutOrder() {
        XCTAssertEqual(Tab.eight.map(\.shortcut), Array(1...8))
        XCTAssertEqual(Tab.eight.map(\.title),
                       ["Today", "Studying", "Projects", "Internship apps", "Uni apps", "Tutoring", "Health", "System"])
    }

    func testEveryTabBelongsToOneSidebarGroup() {
        XCTAssertEqual(TabGroup.allCases.flatMap(\.tabs), Tab.eight)
    }
}
