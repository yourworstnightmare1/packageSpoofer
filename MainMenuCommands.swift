import SwiftUI

struct MainMenuCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Select App") {
                NotificationCenter.default.post(name: .selectApp, object: nil)
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
        }

        CommandGroup(replacing: .appInfo) {
            Button("About packageSpoofer") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "about")
            }

            Button("Settings…") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "settings")
            }
            .keyboardShortcut(",", modifiers: [.command])

            Menu("Launch CLI") {
                Button("Launch CLI in Terminal") {
                    CLILauncher.launchInTerminal()
                }

                Button("Launch CLI in Embedded Shell") {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "embedded-shell")
                }

                Divider()

                Button("Reveal Script in Finder") {
                    CLILauncher.revealScriptInFinder()
                }
            }
        }
    }
}
