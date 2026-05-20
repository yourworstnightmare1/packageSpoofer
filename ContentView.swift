import SwiftUI
import AppKit

struct ContentView: View {
    @Environment(PatchOptions.self) private var patchOptions
    @State private var bundleID = ""
    @State private var originalBundleID = ""
    @State private var appPath = ""
    @State private var selectedURL: URL?
    @State private var panelError: String?
    @State private var outputText = ""

    var body: some View {
        @Bindable var patchOptions = patchOptions

        Form {
            Section("Options") {
                TextField(" Bundle ID", text: $bundleID)
                    .textFieldStyle(.roundedBorder)
                    .help("""
                        The identifier string the app uses to tell macOS what is running. When changed, we can bypass standard app blockers as most blockers go by bundle/package ID lists.
                        """)

                Button("Generate Bundle ID") {
                    bundleID = generateRandomBundleID()
                }

                HStack(alignment: .top, spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Pre-Patch")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Toggle(isOn: $patchOptions.removeFrameworks) {
                            Text("Remove Frameworks")
                                .foregroundStyle(.orange)
                        }
                        .help("""
                            (Not Recommended) Removes bundled frameworks from the application contents. This can cause apps to behave strangely or not run at all. Please use at your own risk.
                            """)

                        Toggle("Apply Binary Fix", isOn: $patchOptions.applyBinaryFix)
                            .help("""
                                Makes the app able to be launched. This fixes an error that causes the app to crash when launching with the message "The app can't be opened".
                                """)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Post-Patch")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Toggle("Apply appUnblocker", isOn: $patchOptions.applyAppUnblocker)
                            .help("""
                                Runs appUnblocker on the application, which uses a trick called folder manipulation to trick macOS into thinking the application it's trying to run is a signed application.
                                """)

                        Toggle("Hide File After Signing", isOn: $patchOptions.hideFileAfterSigning)
                            .help("Marks the app (and launch shortcut, if created) as hidden in Finder after signing.")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
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
                    ScrollView {
                        Text(outputText)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(height: 120)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(6)
                }

                if let url = selectedURL, FileManager.default.fileExists(atPath: url.path) {
                    Button("Reveal in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                }
                Button("Run") {
                    startRun()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(appPath.isEmpty)
            }
        }
        .padding()
        .toggleStyle(.checkbox)
        .background(WindowConfigurator(quitOnClose: true, lockToContentSize: true))
        .onReceive(NotificationCenter.default.publisher(for: .selectApp)) { _ in
            openPanel()
        }
        .onChange(of: appPath) { oldValue, newValue in
            let url = URL(fileURLWithPath: newValue)
            updateBundleID(from: url)
        }
    }

    private func generateRandomBundleID() -> String {
        let characters = Array("abcdefghijklmnopqrstuvwxyz0123456789")

        func randomSegment(length: Int) -> String {
            String((0..<length).map { _ in characters.randomElement()! })
        }

        if Bool.random() {
            let totalLength = Int.random(in: 2...16)
            let firstLength = Int.random(in: 1...(totalLength - 1))
            let secondLength = totalLength - firstLength
            return "com.\(randomSegment(length: firstLength)).\(randomSegment(length: secondLength))"
        }

        return "com.\(randomSegment(length: Int.random(in: 1...16)))"
    }

    private func openPanel() {
        AppSelectionPanel.present { url in
            guard !AppWritableCheck.isOnReadOnlyVolume(at: url) else {
                showReadOnlyVolumeAlert()
                return
            }
            selectedURL = url
            appPath = url.path
            updateBundleID(from: url)
            panelError = nil
        }
    }

    private func updateBundleID(from url: URL) {
        guard let appURL = enclosingAppBundleURL(startingAt: url),
              let bundle = Bundle(url: appURL),
              let id = bundle.bundleIdentifier else { return }
        bundleID = id
        originalBundleID = id
    }

    @MainActor
    private func startRun() {
        guard let appURL = enclosingAppBundleURL(startingAt: URL(fileURLWithPath: appPath)) else {
            panelError = "No enclosing .app bundle found for the given path."
            return
        }
        if AppWritableCheck.isOnReadOnlyVolume(at: appURL) {
            showReadOnlyVolumeAlert()
            return
        }
        if shouldWarnAboutUnmodifiedBundleID(), !confirmUnmodifiedBundleIDWarning() {
            return
        }
        Task { await performActions() }
    }

    @MainActor
    private func showReadOnlyVolumeAlert() {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "Read-only volume"
        alert.informativeText = AppWritableCheck.readOnlyVolumeUserMessage
        alert.addButton(withTitle: "Exit")
        alert.runModal()
    }

    private func shouldWarnAboutUnmodifiedBundleID() -> Bool {
        let prePatchSelected = patchOptions.applyBinaryFix || patchOptions.removeFrameworks
        guard prePatchSelected, !originalBundleID.isEmpty else { return false }
        return bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
            == originalBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @MainActor
    private func confirmUnmodifiedBundleIDWarning() -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = """
            The bundle ID was not modified from its original. If you run the app, it may not run due to app blocking software.
            """
        alert.informativeText = """
            This message is shown to you because you selected pre-patch scripts that require modification of the app itself.
            """
        alert.addButton(withTitle: "Run Anyways")
        alert.addButton(withTitle: "Back")
        return alert.runModal() == .alertFirstButtonReturn
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
        let macOSPath = (appPath as NSString).appendingPathComponent("Contents/MacOS")
        guard FileManager.default.fileExists(atPath: macOSPath) else { return }
        let executables = try FileManager.default.contentsOfDirectory(atPath: macOSPath)
        for executable in executables {
            let executablePath = (macOSPath as NSString).appendingPathComponent(executable)
            try runCommand("/bin/chmod", ["+x", executablePath])
        }
    }

    private func removeFrameworksIfNeeded(at appPath: String, enabled: Bool) throws {
        guard enabled else { return }
        let frameworksPath = (appPath as NSString).appendingPathComponent("Contents/Frameworks")
        if FileManager.default.fileExists(atPath: frameworksPath) {
            try runCommand("/bin/rm", ["-rf", frameworksPath])
        }
    }

    private func ensureAppBundleWritable(at appURL: URL) throws {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: appURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return
        }
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: appURL.path)

        let contentsURL = appURL.appendingPathComponent("Contents", isDirectory: true)
        if fileManager.fileExists(atPath: contentsURL.path) {
            try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: contentsURL.path)
        }

        let infoPlistURL = contentsURL.appendingPathComponent("Info.plist")
        if fileManager.fileExists(atPath: infoPlistURL.path) {
            try fileManager.setAttributes([.posixPermissions: 0o644], ofItemAtPath: infoPlistURL.path)
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

    private func hideFileIfNeeded(at path: String, enabled: Bool) throws {
        guard enabled else { return }
        guard FileManager.default.fileExists(atPath: path) else { return }
        try runCommand("/usr/bin/chflags", ["hidden", path])
    }

    private func hideLaunchShortcutIfPresent(near appURL: URL, enabled: Bool) throws {
        guard enabled else { return }
        let parent = appURL.deletingLastPathComponent()
        let appBaseName = appURL.deletingPathExtension().lastPathComponent
        guard let items = try? FileManager.default.contentsOfDirectory(at: parent, includingPropertiesForKeys: nil) else {
            return
        }
        for item in items where item.lastPathComponent.hasPrefix("Launch \(appBaseName)") {
            try hideFileIfNeeded(at: item.path, enabled: true)
        }
    }

    private func performActions() async {
        await MainActor.run {
            panelError = nil
            outputText = ""
            outputText += "Starting actions...\n"
        }

        guard let appURL = enclosingAppBundleURL(startingAt: URL(fileURLWithPath: appPath)) else {
            await MainActor.run { panelError = "No enclosing .app bundle found for the given path." }
            return
        }

        let accessURL = selectedURL ?? appURL
        guard SelectedAppAccess.beginAccess(for: accessURL) else {
            await MainActor.run {
                panelError = "Could not access the selected app. Use Browse or File → Select App to choose it again."
            }
            return
        }

        var resolvedPath = appURL.path
        let patchAppURL = AppBundleResolver.patchAppURL(from: appURL)
        let patchPath = patchAppURL.path
        let isWrapped = AppBundleResolver.isWrappedApp(at: appURL)

        do {
            try AppWritableCheck.validateWritableAppBundle(at: appURL)
            try ensureAppBundleWritable(at: patchAppURL)
            await MainActor.run {
                outputText += "Resolved app: \(resolvedPath)\n"
                if isWrapped {
                    outputText += "Detected appUnblocker wrapper; patching nested app: \(patchPath)\n"
                }
            }

            if patchOptions.removeFrameworks {
                await MainActor.run { outputText += "[Pre-Patch] Removing embedded frameworks...\n" }
                try removeFrameworksIfNeeded(at: patchPath, enabled: true)
            }

            if patchOptions.applyBinaryFix {
                await MainActor.run { outputText += "[Pre-Patch] Applying binary fix (chmod)...\n" }
                try applyBinaryFixIfNeeded(at: patchPath, enabled: true)
            }

            if !bundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                await MainActor.run { outputText += "Setting bundle identifier to: \(bundleID)\n" }
                try setBundleIdentifier(bundleID, forAppAt: patchPath)
            } else {
                await MainActor.run { outputText += "Bundle ID empty; skipping bundle identifier update.\n" }
            }

            await MainActor.run { outputText += "Signing app (ad-hoc)...\n" }
            try codesignApp(at: patchPath)

            if patchOptions.applyAppUnblocker {
                await MainActor.run { outputText += "[Post-Patch] Applying appUnblocker...\n" }
                let wrapperURL = try AppUnblocker.apply(to: appURL)
                let nestedAppURL = AppBundleResolver.patchAppURL(from: wrapperURL)
                await MainActor.run { outputText += "Re-signing nested app after appUnblocker...\n" }
                try codesignApp(at: nestedAppURL.path)
                resolvedPath = wrapperURL.path
                await MainActor.run {
                    selectedURL = wrapperURL
                    appPath = wrapperURL.path
                    updateBundleID(from: nestedAppURL)
                    if isWrapped {
                        outputText += "Refreshed wrapper at \(wrapperURL.path)\n"
                    } else {
                        outputText += "Created wrapper at \(wrapperURL.path)\n"
                    }
                    outputText += "Launch shortcut added next to the wrapper (symlink).\n"
                }
            }

            if patchOptions.hideFileAfterSigning {
                await MainActor.run { outputText += "[Post-Patch] Hiding file in Finder...\n" }
                try hideFileIfNeeded(at: resolvedPath, enabled: true)
                try hideLaunchShortcutIfPresent(near: URL(fileURLWithPath: resolvedPath), enabled: true)
            }

            await MainActor.run { outputText += "Done.\n" }
        } catch AppWritableCheck.Failure.readOnlyVolume {
            await MainActor.run { showReadOnlyVolumeAlert() }
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

