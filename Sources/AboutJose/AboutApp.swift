import SwiftUI
import DeskKit

struct AboutApp: App {
    @NSApplicationDelegateAdaptor(AboutDelegate.self) private var delegate
    @State private var loaded = Loaded()

    /// The story is read once, at launch. A broken file shows what is wrong instead of an empty window.
    @MainActor
    private struct Loaded {
        let reader: Reader?
        let problem: String?

        init() {
            switch Resources.loadStory() {
            case .success(let story):
                reader = Reader(story: story, defaults: .standard)
                problem = nil
            case .failure(let error):
                reader = nil
                problem = error.message
            }
        }
    }

    var body: some Scene {
        Window("About Jose", id: "main") {
            Group {
                if let reader = loaded.reader {
                    StoryView().environment(reader)
                } else {
                    StoryProblem(message: loaded.problem ?? "")
                }
            }
            .frame(minWidth: Theme().minWindow.width, minHeight: Theme().minWindow.height)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(Theme().designSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            if let reader = loaded.reader {
                CommandMenu("Chapter") {
                    ForEach(Chapter.allCases) { chapter in
                        Button(reader.story.rail(chapter)) { reader.chapter = chapter }
                            .keyboardShortcut(KeyEquivalent(Character(String(chapter.rawValue + 1))), modifiers: .command)
                    }
                }
            }
        }
    }
}

final class AboutDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Needed when the binary runs outside its bundle (swift run).
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

/// Shown when `story.json` cannot be read.
struct StoryProblem: View {
    let message: String

    var body: some View {
        let t = Theme()
        VStack(alignment: .leading, spacing: t.sp12) {
            Text(verbatim: "The story file could not be read.").style(\.title, \.ink)
            Text(verbatim: message).style(\.body, \.inkMuted).textSelection(.enabled)
            Text(verbatim: Resources.story.path).style(\.mono, \.inkMuted).textSelection(.enabled)
        }
        .padding(t.sp32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(t.canvas)
        .environment(\.theme, t)
    }
}
