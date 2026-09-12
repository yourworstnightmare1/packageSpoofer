import AppKit
import Foundation

enum CLILauncher {
    @MainActor
    static func launchInTerminal() {
        guard let scriptURL = resolveCLIURL() else {
            presentMissingCLIAlert()
            return
        }

        do {
            let runnable = try prepareRunnableScript(from: scriptURL)
            let launcherURL = try makeCommandLauncher(for: runnable)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-a", "Terminal", launcherURL.path]
            try process.run()
            TerminalLogCleaner.scheduleCleanupAfterCLILaunch()
        } catch {
            presentLaunchFailedAlert(message: error.localizedDescription)
        }
    }

    @MainActor
    static func revealScriptInFinder() {
        guard let scriptURL = resolveCLIURL() else {
            presentMissingCLIAlert()
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([scriptURL])
    }

    /// Prefer the bundled `cli.sh`, then fall back to the project-adjacent copy.
    static func resolveCLIURL() -> URL? {
        if let bundled = Bundle.main.url(forResource: "cli", withExtension: "sh") {
            return bundled
        }
        if let resourceURL = Bundle.main.resourceURL?.appendingPathComponent("cli.sh"),
           FileManager.default.fileExists(atPath: resourceURL.path) {
            return resourceURL
        }

        let sourceAdjacent = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("cli.sh")
        if FileManager.default.fileExists(atPath: sourceAdjacent.path) {
            return sourceAdjacent
        }

        return nil
    }

    /// Copies `cli.sh` to a writable temp path and ensures it is executable.
    static func prepareRunnableScript(from scriptURL: URL) throws -> URL {
        let fm = FileManager.default
        let runnable = fm.temporaryDirectory.appendingPathComponent("packageSpoofer-cli.sh")
        if fm.fileExists(atPath: runnable.path) {
            try fm.removeItem(at: runnable)
        }
        try fm.copyItem(at: scriptURL, to: runnable)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: runnable.path)
        return runnable
    }

    private static func makeCommandLauncher(for scriptURL: URL) throws -> URL {
        let launcherURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("packageSpoofer-launch-cli.command")

        let escapedScriptPath = scriptURL.path.replacingOccurrences(of: "'", with: "'\\''")
        let content = """
        #!/bin/bash
        bash '\(escapedScriptPath)'
        """

        try content.write(to: launcherURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: launcherURL.path)
        return launcherURL
    }

    @MainActor
    static func presentMissingCLIAlert() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Could not find cli.sh."
        alert.informativeText = "The CLI script is missing from this build of packageSpoofer."
        alert.runModal()
    }

    @MainActor
    private static func presentLaunchFailedAlert(message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Could not launch the CLI."
        alert.informativeText = message
        alert.runModal()
    }
}
