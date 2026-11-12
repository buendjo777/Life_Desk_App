import XCTest
@testable import Desk

final class ShellTests: XCTestCase {
    func testNineTabsInShortcutOrder() {
        XCTAssertEqual(Tab.sidebar.map(\.shortcut), Array(1...9))
        XCTAssertEqual(Tab.sidebar.map(\.title),
                       ["Today", "Studying", "Projects", "Internship apps", "Uni apps", "Tutoring", "History", "Health", "System"])
        XCTAssertEqual(Tab.portfolio.shortcut, 0)
    }

    func testEveryTabBelongsToOneSidebarGroup() {
        XCTAssertEqual(TabGroup.allCases.flatMap(\.tabs), Tab.sidebar)
    }
}
