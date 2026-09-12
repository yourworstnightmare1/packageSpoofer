import Foundation

enum TerminalLogCleaner {
    /// Removes temporary launchers created by packageSpoofer when Auto Delete Terminal Logs is enabled.
    @MainActor
    static func deleteAppTerminalLogsIfEnabled() {
        guard AppSettings.shared.autoDeleteTerminalLogs else { return }
        deleteTemporaryLaunchers()
    }

    static func deleteTemporaryLaunchers() {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory
        guard let items = try? fm.contentsOfDirectory(at: tmp, includingPropertiesForKeys: nil) else { return }
        for item in items where item.lastPathComponent.hasPrefix("packageSpoofer") {
            try? fm.removeItem(at: item)
        }
    }

    /// Schedules cleanup after Terminal has had time to start the launcher.
    @MainActor
    static func scheduleCleanupAfterCLILaunch() {
        guard AppSettings.shared.autoDeleteTerminalLogs else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
            deleteTemporaryLaunchers()
        }
    }
}
