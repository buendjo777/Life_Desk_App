import SwiftUI

/// The entry point. With `--render-snapshots <dir>` Desk draws every tab to PNG and exits; with
/// `--import-classes` it imports the Classes notes and exits; otherwise it starts the app.
@main
enum Main {
    static func main() {
        let arguments = CommandLine.arguments
        if let flag = arguments.firstIndex(of: "--render-snapshots"), arguments.count > flag + 1 {
            MainActor.assumeIsolated { Snapshots.run(directory: arguments[flag + 1]) }
            return
        }
        if let flag = arguments.firstIndex(of: "--render-icon"), arguments.count > flag + 1 {
            MainActor.assumeIsolated { AppIcon.run(directory: arguments[flag + 1]) }
            return
        }
        if arguments.contains("--import-classes") {
            exit(MainActor.assumeIsolated { ImportCommand.run(arguments) })
        }
        DeskApp.main()
    }
}
