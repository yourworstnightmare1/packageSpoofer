import SwiftUI
import AppKit

struct ContentView: View {
    @State private var optionA = false
    @State private var optionB = false
    @State private var optionC = false
    @State private var bundleID = ""
    @State private var appPath = ""
    @State private var selectedURL: URL?
    @State private var panelError: String?
    @State private var outputText = ""

    var body: some View {
        Form {
            Section("Options") {
                TextField(" Bundle ID", text: $bundleID)
                    .textFieldStyle(.roundedBorder)
                Toggle("Apply binary fix", isOn: $optionB)
                    .help("""
                        Runs chmod on the app. This fixes a crash on some old macOS apps and poorly developed apps.\n\nThis also allows for the app to be run from the command line.
                        """)
                Toggle(isOn: $optionC) {
                    Text("Remove frameworks")
                        .foregroundStyle(.orange)
                }
                .help("Removes embedded frameworks from the selected app bundle.\n\nThis is known to break many apps. If an error appears relating to frameworks signing, try to use the app first before using this.")
            }

            Section("File or Folder") {
                HStack {
                    TextField(" App path", text: $appPath)
                        .textFieldStyle(.roundedBorder)

                    Button("Browse…") {
                        openPanel()
                    }
                }

                if let url = selectedURL {
                    Text("Selected: \(url.path)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let error = panelError {
                    Text("Error: \(error)")
                        .foregroundStyle(.red)
                        .font(.caption)
                }

                if !appPath.isEmpty {
                    PathStatusView(path: appPath)
                }

                // Live output window
                if !outputText.isEmpty {
                    Text("Output:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $outputText)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 120)
                        .scrollContentBackground(.hidden)
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(6)
                }

                if let url = selectedURL, FileManager.default.fileExists(atPath: url.path) {
                    Button("Reveal in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                }
                Button("Run") {
                    Task {
                        await performActions(bundleID: bundleID,
                                             appPath: appPath,
                                             applyBinaryFix: optionB,
                                             removeFrameworks: optionC)
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(appPath.isEmpty)
            }
        }
        .padding()
        .toggleStyle(.checkbox)
        .onChange(of: appPath) { oldValue, newValue in
            let url = URL(fileURLWithPath: newValue)
            updateBundleID(from: url)
        }
    }

    private func openPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        panel.begin { response in
            if response == .OK, let url = panel.url {
                selectedURL = url
                appPath = url.path
                updateBundleID(from: url)
                panelError = nil
            } else if response == .cancel {
                panelError = nil
            }
        }
    }

    private func updateBundleID(from url: URL) {
        guard let appURL = enclosingAppBundleURL(startingAt: url),
              let bundle = Bundle(url: appURL),
              let id = bundle.bundleIdentifier else { return }
        bundleID = id
    }

    private func enclosingAppBundleURL(startingAt url: URL) -> URL? {
        var current = url
        // Walk up the directory tree until we either find an .app or reach the root
        while true {
            if current.pathExtension == "app" {
                return current
            }
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path || parent.path.isEmpty {
                break
            }
            current = parent
        }
        return nil
    }

    // MARK: - Direct command execution
    private func runCommand(_ launchPath: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments

        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err

        // Read stdout progressively
        out.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8), !chunk.isEmpty else { return }
            Task { @MainActor in
                outputText += chunk
            }
        }

        try process.run()
        process.waitUntilExit()

        // Flush any remaining stdout
        let remainingOut = out.fileHandleForReading.readDataToEndOfFile()
        if let s = String(data: remainingOut, encoding: .utf8), !s.isEmpty {
            Task { @MainActor in outputText += s }
        }

        guard process.terminationStatus == 0 else {
            let errData = err.fileHandleForReading.readDataToEndOfFile()
            let errStr = String(data: errData, encoding: .utf8) ?? "Unknown error"
            Task { @MainActor in
                outputText += (outputText.hasSuffix("\n") ? "" : "\n") + errStr + "\n"
            }
            throw NSError(domain: "Command", code: Int(process.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: errStr])
        }
    }

    private func applyBinaryFixIfNeeded(at appPath: String, enabled: Bool) throws {
        guard enabled else { return }
        try runCommand("/bin/chmod", [ "+x", appPath])
    }

    private func removeFrameworksIfNeeded(at appPath: String, enabled: Bool) throws {
        guard enabled else { return }
        let frameworksPath = (appPath as NSString).appendingPathComponent("Contents/Frameworks")
        if FileManager.default.fileExists(atPath: frameworksPath) {
            try runCommand("/bin/rm", ["-rf", frameworksPath])
        }
    }

    private func setBundleIdentifier(_ bundleID: String, forAppAt appPath: String) throws {
        // Info.plist is typically at Contents/Info.plist inside the .app bundle
        let infoPlistPath = (appPath as NSString).appendingPathComponent("Contents/Info.plist")
        try runCommand("/usr/bin/plutil", ["-replace", "CFBundleIdentifier", "-string", bundleID, infoPlistPath])
    }

    private func codesignApp(at appPath: String) throws {
        // Use ad-hoc signing (-) with deep and force
        try runCommand("/usr/bin/codesign", ["--deep", "--force", "--sign", "-", appPath])
    }

    private func performActions(bundleID: String, appPath: String, applyBinaryFix: Bool, removeFrameworks: Bool) async {
        await MainActor.run {
            panelError = nil
            outputText = ""
            outputText += "Starting actions...\n"
        }

        // Resolve to the enclosing .app if user selected a nested path
        let resolvedPath: String
        if let appURL = enclosingAppBundleURL(startingAt: URL(fileURLWithPath: appPath)) {
            resolvedPath = appURL.path
        } else {
            await MainActor.run { panelError = "No enclosing .app bundle found for the given path." }
            return
        }

        do {
            await MainActor.run { outputText += "Resolved app: \(resolvedPath)\n" }

            // 1) Modify bundle identifier
            if !bundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                await MainActor.run { outputText += "Setting bundle identifier to: \(bundleID)\n" }
                try setBundleIdentifier(bundleID, forAppAt: resolvedPath)
            } else {
                await MainActor.run { outputText += "Bundle ID empty; skipping bundle identifier update.\n" }
            }

            // 2) Codesign the app (ad-hoc)
            await MainActor.run { outputText += "Signing app (ad-hoc)...\n" }
            try codesignApp(at: resolvedPath)

            // 3) Apply binary fix if requested
            if applyBinaryFix {
                await MainActor.run { outputText += "Applying binary fix (chmod)...\n" }
            }
            try applyBinaryFixIfNeeded(at: resolvedPath, enabled: applyBinaryFix)

            // 4) Remove frameworks if requested
            if removeFrameworks {
                await MainActor.run { outputText += "Removing embedded frameworks...\n" }
            }
            try removeFrameworksIfNeeded(at: resolvedPath, enabled: removeFrameworks)

            await MainActor.run { outputText += "Done.\n" }
        } catch {
            await MainActor.run {
                panelError = error.localizedDescription
                outputText += "Failed: \(error.localizedDescription)\n"
            }
        }
    }
}

struct PathStatusView: View {
    let path: String

    var body: some View {
        let status = pathStatus()
        Group {
            switch status {
            case .existsFile:
                Label("Path exists (file)", systemImage: "doc")
                    .foregroundStyle(.green)
            case .existsDirectory:
                Label("Path exists (folder)", systemImage: "folder")
                    .foregroundStyle(.green)
            case .doesNotExist:
                Label("Path not found", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
        }
        .font(.caption)
    }

    private enum Status { case existsFile, existsDirectory, doesNotExist }

    private func pathStatus() -> Status {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        if exists {
            return isDir.boolValue ? .existsDirectory : .existsFile
        } else {
            return .doesNotExist
        }
    }
}

#Preview {
    ContentView()
}

