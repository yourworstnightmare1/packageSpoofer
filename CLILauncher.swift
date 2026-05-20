import AppKit
import Foundation

enum CLILauncher {
    @MainActor
    static func launch() {
        guard let scriptURL = resolveCLIURL() else {
            presentMissingCLIAlert()
            return
        }

        do {
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
            let launcherURL = try makeCommandLauncher(for: scriptURL)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-a", "Terminal", launcherURL.path]
            try process.run()
        } catch {
            presentLaunchFailedAlert(message: error.localizedDescription)
        }
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

    private static func resolveCLIURL() -> URL? {
        if let bundled = Bundle.main.url(forResource: "cli", withExtension: "sh") {
            return bundled
        }

        let sourceAdjacent = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("cli.sh")
        if FileManager.default.fileExists(atPath: sourceAdjacent.path) {
            return sourceAdjacent
        }

        return nil
    }

    @MainActor
    private static func presentMissingCLIAlert() {
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
