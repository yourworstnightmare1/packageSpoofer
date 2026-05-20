import SwiftUI

@main
struct PackagespooferApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var patchOptions = PatchOptions()

    var body: some Scene {
        Window("packageSpoofer", id: "main") {
            ContentView()
                .environment(patchOptions)
        }
        .windowResizability(.contentSize)
        .commands {
            MainMenuCommands(patchOptions: patchOptions)
        }

        Window("About packageSpoofer", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
    }
}
