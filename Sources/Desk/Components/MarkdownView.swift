import SwiftUI

/// Renders trusted Markdown from the `nini/` mirror: headings, bullets, table rows and paragraphs.
/// This is the only file in the app that parses Markdown (a test checks it). Agent- and
/// email-derived text never comes here; it is drawn with `Text(verbatim:)`.
struct MarkdownView: View {
    @Environment(\.theme) private var t
    let text: String

    private enum Block: Hashable {
        case heading(String)
        case bullet(String)
        case paragraph(String)
    }

    private var blocks: [Block] {
        var blocks: [Block] = []
        var paragraph: [String] = []
        func flush() {
            if !paragraph.isEmpty { blocks.append(.paragraph(paragraph.joined(separator: " "))) }
            paragraph = []
        }
        for raw in Parse.splitLines(text) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                flush()
            } else if line.hasPrefix("#") {
                flush()
                blocks.append(.heading(line.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces)))
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                flush()
                blocks.append(.bullet(String(line.dropFirst(2))))
            } else if line.hasPrefix("|") {
                flush()
                let cells = line.trimmingCharacters(in: CharacterSet(charactersIn: "|")).components(separatedBy: "|")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                if !cells.allSatisfy({ $0.allSatisfy { "-: ".contains($0) } }) {
                    blocks.append(.bullet(cells.filter { !$0.isEmpty }.joined(separator: " · ")))
                }
            } else {
                paragraph.append(line)
            }
        }
        flush()
        return blocks
    }

    private func inline(_ source: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: source, options: options)) ?? AttributedString(source)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: t.sp8) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .heading(let text):
                    Text(inline(text)).style(\.bodyStrong, \.ink)
                case .bullet(let text):
                    HStack(alignment: .firstTextBaseline, spacing: t.sp8) {
                        Circle().fill(t.inkMuted).frame(width: t.sp4, height: t.sp4).offset(y: -t.sp2)
                        Text(inline(text)).style(\.body, \.ink).lineSpacing(t.sp2).fixedSize(horizontal: false, vertical: true)
                    }
                case .paragraph(let text):
                    Text(inline(text)).style(\.body, \.ink).lineSpacing(t.sp2).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
