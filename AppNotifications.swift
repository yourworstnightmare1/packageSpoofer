import AppKit
import Foundation

extension Notification.Name {
    static let selectApp = Notification.Name("packageSpoofer.selectApp")
}

enum AppSelectionPanel {
    static func present(onSelect: @escaping (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            _ = SelectedAppAccess.beginAccess(for: url)
            onSelect(url)
        }
    }
}
