import SwiftUI

@main
struct PackagespooferApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var patchOptions = PatchOptions()
    @State private var settings = AppSettings.shared

    var body: some Scene {
        Window("packageSpoofer", id: "main") {
            ContentView()
                .environment(patchOptions)
                .environment(settings)
        }
        .windowResizability(.contentSize)
        .commands {
            MainMenuCommands()
        }

        Window("About packageSpoofer", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)

        Window("Settings", id: "settings") {
            SettingsView()
                .environment(settings)
        }
        .windowResizability(.contentSize)

        Window("Create Wordlist", id: "wordlist") {
            WordlistEditorView()
                .environment(settings)
        }
        .windowResizability(.contentSize)

        Window("Embedded Shell", id: "embedded-shell") {
            EmbeddedShellView()
        }
        .defaultSize(width: 780, height: 480)
        .windowResizability(.automatic)
        .windowStyle(.automatic)
    }
}
