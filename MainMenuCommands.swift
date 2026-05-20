import SwiftUI

struct MainMenuCommands: Commands {
    @Bindable var patchOptions: PatchOptions
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Select App") {
                NotificationCenter.default.post(name: .selectApp, object: nil)
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
        }

        CommandMenu("Pre-Patch") {
            Toggle("Remove Frameworks", isOn: $patchOptions.removeFrameworks)
            Toggle("Apply Binary Fix", isOn: $patchOptions.applyBinaryFix)
        }

        CommandMenu("Post-Patch") {
            Toggle("Apply appUnblocker", isOn: $patchOptions.applyAppUnblocker)
            Toggle("Hide File After Signing", isOn: $patchOptions.hideFileAfterSigning)
        }

        CommandGroup(replacing: .appInfo) {
            Button("About packageSpoofer") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "about")
            }

            Button("Launch CLI") {
                CLILauncher.launch()
            }
        }
    }
}
