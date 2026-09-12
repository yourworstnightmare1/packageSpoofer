import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let appMenuTitle = "packageSpoofer"

    func applicationWillFinishLaunching(_ notification: Notification) {
        applyAppMenuTitle()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        applyAppMenuTitle()
        DispatchQueue.main.async { [weak self] in
            self?.applyAppMenuTitle()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func applyAppMenuTitle() {
        NSApp.mainMenu?.items.first?.title = appMenuTitle
    }
}
