import Foundation

/// The words of the story, read from `about/story.json`. The layout is code; every sentence is in that file.
struct Story: Decodable {
    let name: String
    let hint: String
    /// Shown where a contact field is still empty.
    let placeholder: String
    let opening: Opening
    let thesis: Thesis
    let desk: DeskCase
    let tutoring: Tutoring
    let next: Next

    struct Figure: Decodable, Hashable {
        let value: String
        var unit: String?
        let caption: String
    }

    struct Item: Decodable, Hashable {
        let title: String
        let detail: String
        var symbol: String?
    }

    struct Opening: Decodable {
        let rail: String
        let line: String
        let degree: String
        let livedTitle: String
        let lived: [Place]
        let languagesTitle: String
        let languages: [Language]

        struct Place: Decodable, Hashable {
            let place: String
            let value: String
            var unit: String?
            let caption: String
        }

        struct Language: Decodable, Hashable {
            let code: String
            let name: String
            let level: String
        }
    }

    struct Thesis: Decodable {
        let rail: String
        let headline: String
        let context: String
        let strip: Strip
        let steps: [Item]
        let resultTitle: String
        let figures: [Figure]
        let finding: String
        let repoLabel: String
        let repoUrl: String

        struct Strip: Decodable {
            let normal: String
            let af: String
            let normalNote: String
            let afNote: String
            let disclaimer: String
        }
    }

    struct DeskCase: Decodable {
        let rail: String
        let headline: String
        let summary: String
        let figures: [Figure]
        let screensNote: String
        let screens: [Screen]
        let architectureTitle: String
        let architectureNote: String
        let architecture: [Item]
        let platformNote: String
        let repoLabel: String
        let repoUrl: String

        struct Screen: Decodable, Hashable {
            let label: String
            /// The tab's snapshot name in `design/screenshots/`, without "-light.png" or "-dark.png".
            let file: String
        }
    }

    struct Tutoring: Decodable {
        let rail: String
        let headline: String
        let figures: [Figure]
        let subjectsTitle: String
        let subjects: [Subject]
        let factsTitle: String
        let facts: [Item]

        struct Subject: Decodable, Hashable {
            let name: String
            let detail: String
            let symbol: String
        }
    }

    struct Next: Decodable {
        let rail: String
        let headline: String
        let goals: [Goal]
        let contactTitle: String
        let contact: [Contact]

        struct Goal: Decodable, Hashable {
            let title: String
            let value: String
            let detail: String
        }

        struct Contact: Decodable, Hashable {
            let label: String
            /// Empty until Jose fills it in: the row then shows the placeholder.
            let value: String
            let url: String
            let symbol: String
        }
    }

    func rail(_ chapter: Chapter) -> String {
        switch chapter {
        case .opening: opening.rail
        case .thesis: thesis.rail
        case .desk: desk.rail
        case .tutoring: tutoring.rail
        case .next: next.rail
        }
    }
}

/// The five scenes, in reading order.
enum Chapter: Int, CaseIterable, Identifiable {
    case opening, thesis, desk, tutoring, next

    var id: Int { rawValue }
    var number: String { String(format: "%02d", rawValue + 1) }
    var slug: String { String(describing: self) }
}

/// Where the story and the Desk screenshots live: inside the installed app, or in the repo when run from source.
enum Resources {
    /// Sources/AboutJose/Story.swift → the repo root.
    private static let repo = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private static func find(bundled: String, repo path: String) -> URL {
        if let url = Bundle.main.resourceURL?.appendingPathComponent(bundled), FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        return repo.appendingPathComponent(path)
    }

    static var story: URL { find(bundled: "story.json", repo: "about/story.json") }

    static func screen(_ file: String, dark: Bool) -> URL {
        let name = "\(file)-\(dark ? "dark" : "light").png"
        return find(bundled: "screens/\(name)", repo: "design/screenshots/\(name)")
    }

    /// The story, or a sentence saying what is wrong with the file.
    static func loadStory() -> Result<Story, StoryError> {
        do {
            return .success(try JSONDecoder().decode(Story.self, from: Data(contentsOf: story)))
        } catch let error as DecodingError {
            return .failure(StoryError(message: describe(error)))
        } catch {
            return .failure(StoryError(message: error.localizedDescription))
        }
    }

    private static func describe(_ error: DecodingError) -> String {
        func path(_ context: DecodingError.Context) -> String {
            context.codingPath.map { $0.intValue.map { "[\($0)]" } ?? $0.stringValue }.joined(separator: ".")
        }
        switch error {
        case .keyNotFound(let key, let context): return "Missing \"\(key.stringValue)\" in \(path(context).isEmpty ? "the top level" : path(context))."
        case .typeMismatch(_, let context), .valueNotFound(_, let context): return "Wrong kind of value at \(path(context))."
        case .dataCorrupted(let context): return "The file is not valid JSON. \(context.debugDescription)"
        @unknown default: return error.localizedDescription
        }
    }
}

struct StoryError: Error {
    let message: String
}
