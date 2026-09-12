import Foundation
import Observation
import SwiftUI
import AppKit

@Observable
@MainActor
final class EmbeddedShellSession {
    var outputAttributed = AttributedString()
    var outputRevision = 0
    var inputText = ""
    var isRunning = false
    var didFailToStart = false
    /// When true, the hosting Embedded Shell window should close.
    var shouldCloseWindow = false

    private var ansiState = EmbeddedShellANSIStyle()
    private var process: Process?
    private var stdinHandle: FileHandle?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    private var closeRequested = false

    func start() {
        guard !isRunning else { return }
        guard let scriptURL = CLILauncher.resolveCLIURL() else {
            appendPlain("Could not find cli.sh.\n")
            didFailToStart = true
            requestCloseWindow()
            return
        }

        let runnable: URL
        do {
            runnable = try CLILauncher.prepareRunnableScript(from: scriptURL)
        } catch {
            appendPlain("Failed to prepare cli.sh: \(error.localizedDescription)\n")
            didFailToStart = true
            requestCloseWindow()
            return
        }

        let stdout = Pipe()
        let stderr = Pipe()
        let stdin = Pipe()
        stdoutPipe = stdout
        stderrPipe = stderr
        stdinHandle = stdin.fileHandleForWriting

        // Use `script` to allocate a PTY so `read -p` prompts and line-buffered
        // output from cli.sh work the same as in Terminal.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/script")
        process.arguments = ["-q", "/dev/null", "/bin/bash", runnable.path]
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr
        process.environment = ProcessInfo.processInfo.environment.merging([
            "TERM": "xterm-256color",
            "FORCE_COLOR": "1",
            "CLICOLOR": "1",
            "CLICOLOR_FORCE": "1",
        ]) { _, new in new }

        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            let chunk = EmbeddedShellANSI.decode(data)
            Task { @MainActor in
                self?.appendANSI(chunk)
            }
        }
        stderr.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            let chunk = EmbeddedShellANSI.decode(data)
            Task { @MainActor in
                self?.appendANSI(chunk)
            }
        }

        process.terminationHandler = { [weak self] proc in
            Task { @MainActor in
                self?.finish(exitCode: proc.terminationStatus)
            }
        }

        do {
            try process.run()
            self.process = process
            isRunning = true
            appendPlain("Running cli.sh…\n")
        } catch {
            appendPlain("Failed to start cli.sh: \(error.localizedDescription)\n")
            didFailToStart = true
            cleanupPipes()
            requestCloseWindow()
        }
    }

    func submitInput() {
        guard isRunning, let stdinHandle else { return }
        let line = inputText
        inputText = ""
        appendPlain(line + "\n")
        if let data = (line + "\n").data(using: .utf8) {
            try? stdinHandle.write(contentsOf: data)
        }
    }

    /// Forwards Ctrl+C to the running CLI process group.
    func interrupt() {
        guard let process, process.isRunning else {
            requestCloseWindow()
            return
        }
        let pid = process.processIdentifier
        // Send SIGINT to the process group started by `script`.
        kill(-pid, SIGINT)
        // Fallback if group signal fails.
        process.interrupt()
    }

    func stop() {
        guard let process, process.isRunning else { return }
        process.terminate()
    }

    private func finish(exitCode: Int32) {
        isRunning = false
        appendPlain("\n[Process exited with code \(exitCode)]\n")
        cleanupPipes()
        process = nil
        TerminalLogCleaner.deleteAppTerminalLogsIfEnabled()
        requestCloseWindow(after: 0.35)
    }

    private func requestCloseWindow(after delay: TimeInterval = 0) {
        guard !closeRequested else { return }
        closeRequested = true
        if delay <= 0 {
            shouldCloseWindow = true
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.shouldCloseWindow = true
        }
    }

    private func cleanupPipes() {
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        try? stdinHandle?.close()
        stdinHandle = nil
        stdoutPipe = nil
        stderrPipe = nil
    }

    private func appendANSI(_ text: String) {
        outputAttributed.append(EmbeddedShellANSI.attributed(from: text, state: &ansiState))
        outputRevision &+= 1
    }

    private func appendPlain(_ text: String) {
        var piece = AttributedString(text)
        piece.foregroundColor = .white
        piece.font = .system(size: 13, design: .monospaced)
        outputAttributed.append(piece)
        outputRevision &+= 1
    }
}
