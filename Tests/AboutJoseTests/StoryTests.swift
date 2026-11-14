import XCTest
import SwiftUI
import DeskKit
@testable import AboutJose

/// The story file, and the one thing snapshots cannot show: that the scroll view, the keys and the rail move together.
@MainActor
final class StoryTests: XCTestCase {
    private func story() throws -> Story {
        try Resources.loadStory().get()
    }

    func testTheStoryFileDecodesAndEveryChapterHasAName() throws {
        let story = try story()
        XCTAssertFalse(story.name.isEmpty)
        for chapter in Chapter.allCases { XCTAssertFalse(story.rail(chapter).isEmpty) }
        XCTAssertEqual(story.thesis.steps.count, 3)
    }

    /// Links are https only, and every Desk screen the story names exists in both schemes.
    func testLinksAreHttpsAndScreensExist() throws {
        let story = try story()
        XCTAssertNotNil(Web.url(story.thesis.repoUrl))
        XCTAssertNotNil(Web.url(story.desk.repoUrl))
        XCTAssertNil(Web.url("file:///etc/passwd"))
        XCTAssertNil(Web.url("http://example.com"))
        for contact in story.next.contact where !contact.url.isEmpty { XCTAssertNotNil(Web.url(contact.url), contact.label) }
        for screen in story.desk.screens {
            for dark in [false, true] {
                XCTAssertTrue(FileManager.default.fileExists(atPath: Resources.screen(screen.file, dark: dark).path), screen.file)
            }
        }
    }

    /// The web copy in docs/ carries the same words as the app. If this fails, run scripts/build-web.sh.
    func testTheWebCopyHasTheCurrentStory() throws {
        let root = Resources.story.deletingLastPathComponent().deletingLastPathComponent()
        let web = root.appendingPathComponent("docs/data.js")
        guard FileManager.default.fileExists(atPath: web.path) else { throw XCTSkip("docs/ has not been built") }
        let page = try String(contentsOf: web, encoding: .utf8)
        let words = try String(contentsOf: Resources.story, encoding: .utf8)
        XCTAssertTrue(page.contains(words), "docs/data.js is older than about/story.json")
        for palette in Palette.allCases { XCTAssertTrue(page.contains("\"\(palette.rawValue)\""), palette.rawValue) }
    }

    func testTheTideRisesWithTheChapters() throws {
        let reader = Reader(story: try story())
        XCTAssertEqual(reader.progress, 0)
        reader.step(-1)
        XCTAssertEqual(reader.chapter, .opening)
        for _ in Chapter.allCases { reader.step(1) }
        XCTAssertEqual(reader.chapter, .next)
        XCTAssertEqual(reader.progress, 1)
        XCTAssertTrue(reader.isLast)
    }

    /// The illustration: a normal rhythm is evenly spaced, atrial fibrillation is not.
    func testTheRhythmsDiffer() {
        func gaps(_ rhythm: Rhythm) -> [Double] {
            let spikes = rhythm.spikes(from: 0, to: 6)
            return zip(spikes.dropFirst(), spikes).map { (($0 - $1) * 100).rounded() / 100 }
        }
        XCTAssertEqual(Set(gaps(.normal)).count, 1)
        XCTAssertGreaterThan(Set(gaps(.af)).count, 4)
        XCTAssertGreaterThan(Rhythm.normal.value(at: 0), 0.9)
    }

    /// The real view tree in an offscreen window: choosing a chapter scrolls to it, and scrolling changes the chapter.
    func testChoosingAChapterScrollsAndScrollingChoosesAChapter() throws {
        let reader = Reader(story: try story())
        let size = Theme().designSize
        let window = NSWindow(contentRect: NSRect(x: -10_000, y: -10_000, width: size.width, height: size.height),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.alphaValue = 0
        window.contentView = NSHostingView(rootView: StoryView().environment(reader).environment(\.colorScheme, .dark))
        _ = NSApplication.shared
        window.orderFrontRegardless()
        defer { window.close() }
        func settle(_ seconds: Double = 0.6) { RunLoop.main.run(until: Date().addingTimeInterval(seconds)) }
        window.contentView?.layoutSubtreeIfNeeded()
        settle()

        func find(_ view: NSView) -> NSScrollView? {
            if let scroll = view as? NSScrollView { return scroll }
            return view.subviews.lazy.compactMap(find).first
        }
        let scroll = try XCTUnwrap(window.contentView.flatMap(find), "the pager is a scroll view")
        let page = scroll.contentView.bounds.height
        XCTAssertEqual(page, size.height, accuracy: 1)
        XCTAssertEqual(scroll.documentView?.frame.height ?? 0, page * CGFloat(Chapter.allCases.count), accuracy: 1)

        // The rail, the keys and the menu all do this.
        reader.chapter = .desk
        settle(1.2)
        XCTAssertEqual(scroll.contentView.bounds.origin.y, page * 2, accuracy: 2)
        XCTAssertEqual(reader.chapter, .desk, "passing over Thesis on the way must not make it the chapter")

        // The trackpad does this.
        scroll.contentView.setBoundsOrigin(NSPoint(x: 0, y: page * 4))
        scroll.reflectScrolledClipView(scroll.contentView)
        settle(1.2)
        XCTAssertEqual(reader.chapter, .next)
    }
}
