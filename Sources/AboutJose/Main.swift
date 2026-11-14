import SwiftUI

/// The entry point. `--render-snapshots <dir>` draws every chapter to PNG and exits; `--render-icon <dir>`
/// writes the icon set; `--web-theme` prints the colours for the web page; otherwise the app starts.
@main
enum Main {
    static func main() {
        let arguments = CommandLine.arguments
        if let flag = arguments.firstIndex(of: "--render-snapshots"), arguments.count > flag + 1 {
            MainActor.assumeIsolated { Snapshots.run(directory: arguments[flag + 1]) }
            return
        }
        if let flag = arguments.firstIndex(of: "--render-icon"), arguments.count > flag + 1 {
            MainActor.assumeIsolated { Snapshots.icon(directory: arguments[flag + 1]) }
            return
        }
        if arguments.contains("--web-theme") {
            MainActor.assumeIsolated { WebTheme.run() }
            return
        }
        AboutApp.main()
    }
}
