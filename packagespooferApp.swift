import SwiftUI

@main
struct PackagespooferApp: App {
    var body: some Scene  {
        mainWindow
        aboutWindow
        appCommands
    }

    // Main app window group split out to reduce type-checking complexity
    private var mainWindow: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    // Custom About window split out
    private var aboutWindow: some Scene {
        Window("About packagespoofer", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
    }

    // Commands split out
    private var appCommands: some Scene {
        WindowGroup(id: "commands-dummy") {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                AboutWindowButton()
            }
        }
    }
}

// A small helper view that opens the About window using the environment API
private struct AboutWindowButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("About packagespoofer") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "about")
        }
    }
}

