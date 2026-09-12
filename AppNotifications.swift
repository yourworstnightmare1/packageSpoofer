import AppKit
import Foundation

extension Notification.Name {
    static let selectApp = Notification.Name("packageSpoofer.selectApp")
}

enum AppSelectionPanel {
    /// - Parameter retainAccess: When true, keeps security-scoped access for later patching.
    ///   Pass false when only reading metadata (e.g. copying a bundle ID).
    static func present(retainAccess: Bool = true, onSelect: @escaping (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.message = retainAccess
            ? "Choose the app to patch."
            : "Choose an app to copy its bundle identifier."

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            if retainAccess {
                _ = SelectedAppAccess.beginAccess(for: url)
            }
            onSelect(url)
        }
    }
}
