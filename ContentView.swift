import SwiftUI
import AppKit

struct ContentView: View {
    @Environment(PatchOptions.self) private var patchOptions
    @Environment(AppSettings.self) private var settings
    @State private var bundleID = ""
    @State private var originalBundleID = ""
    @State private var plistPath = ""
    @State private var categoryType = ""
    @State private var appPath = ""
    @State private var selectedURL: URL?
    @State private var panelError: String?
    @State private var outputText = ""
    @State private var statusMessage: String?
    @State private var usedExistingBundleID = false
    @State private var pickedExistingBundleID = ""

    private var trimmedCategoryType: String {
        categoryType.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var showsInvalidCategoryWarning: Bool {
        !trimmedCategoryType.isEmpty && !AppCategory.isValid(trimmedCategoryType)
    }

    private var showsMetalHUDExistingBundleIDWarning: Bool {
        patchOptions.forceMetalHUD && usedExistingBundleID
    }

    var body: some View {
        @Bindable var patchOptions = patchOptions

        VStack(spacing: 0) {
            Form {
                Section("Options") {
                    TextField(" Bundle ID", text: $bundleID)
                        .textFieldStyle(.roundedBorder)
                        .help("""
                            The identifier string the app uses to tell macOS what is running. When changed, we can bypass standard app blockers as most blockers go by bundle/package ID lists.
                            """)

                    TextField(" Info.plist", text: $plistPath)
                        .textFieldStyle(.roundedBorder)
                        .help("""
                            Path to the Info.plist whose CFBundleIdentifier will be updated. Autofilled when you select an app; change it only if the plist lives somewhere unusual.
                            """)

                    TextField(" Category", text: $categoryType)
                        .textFieldStyle(.roundedBorder)
                        .help("LSApplicationCategoryType value written to the Info.plist when Category Spoofer is enabled.")
                        .disabled(!patchOptions.applyCategorySpoofer)

                    if showsInvalidCategoryWarning {
                        Text("This is not a valid application category. This does not affect how the app runs but it may cause it to be more easily detectable by algorithms that use category-based blocking.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack {
                        Button("Generate Bundle ID") {
                            usedExistingBundleID = false
                            pickedExistingBundleID = ""
                            bundleID = generateRandomBundleID()
                        }

                        Button("Existing Bundle ID…") {
                            pickExistingBundleID()
                        }
                        .help("Choose another app and use its CFBundleIdentifier.")
                        .disabled(patchOptions.forceMetalHUD)
                    }

                    if showsMetalHUDExistingBundleIDWarning {
                        Text("Duplicated bundle IDs conflicts with the Metal HUD patch, which will cause both apps to display the HUD unintentionally. Please use your own bundle ID or generate one.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(alignment: .top, spacing: 24) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Pre-Patch")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Toggle("Clone Before Spoofing", isOn: $patchOptions.cloneBeforeSpoofing)
                                .help("""
                                    packageSpoofer will make a clone of the app before spoofing it. Useful if the target app is known to have issues when spoofed or if you don't have another way to obtain this app anymore.
                                    """)

                            Toggle(isOn: $patchOptions.removeFrameworks) {
                                Text("Remove Frameworks")
                                    .foregroundStyle(.orange)
                            }
                            .help("""
                                (Not Recommended) Removes bundled frameworks from the application contents. This can cause apps to behave strangely or not run at all. Please use at your own risk.
                                """)

                            Toggle("Make Executable", isOn: $patchOptions.applyBinaryFix)
                                .help("""
                                    Makes the application executable using the chmod +x command if it already isn't. This should only be used if the app crashes on startup or shows "This app can't be opened".
                                    """)

                            Toggle("Category Spoofer", isOn: $patchOptions.applyCategorySpoofer)
                                .help("""
                                    Changes the app category the app reports. This is useful if a blocker seems to also grab application categories to target apps more easily.
                                    """)

                            if patchOptions.applyCategorySpoofer {
                                Picker("Category", selection: categoryPickerSelection) {
                                    Text("Custom").tag("")
                                    ForEach(AppCategory.knownValues, id: \.self) { value in
                                        Text(AppCategory.displayName(for: value)).tag(value)
                                    }
                                }
                                .labelsHidden()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
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

                            Toggle("Bypass Gatekeeper", isOn: $patchOptions.bypassGatekeeper)
                                .help("""
                                    Bypasses the "This app can't be verified" message by running a command that tells macOS to ignore the app from Gatekeeper restrictions.
                                    """)
                                .disabled(!settings.allowMacOSModification)

                            Toggle("Hide File After Signing", isOn: $patchOptions.hideFileAfterSigning)
                                .help("Marks the app (and launch shortcut, if created) as hidden in Finder after signing.")
                                .disabled(!settings.allowMacOSModification)

                            Toggle("Open App on Completion", isOn: $patchOptions.openAppOnCompletion)
                                .help("Opens app once all post patch scripts complete.")

                            Toggle("Force Metal HUD", isOn: $patchOptions.forceMetalHUD)
                                .help("""
                                    Forces the target app to launch with the Metal HUD, which shows frametime and system details on 3D graphics in the app. This only works for apps that render 3D assets using Metal.
                                    """)

                            if !settings.allowMacOSModification {
                                Text("Enable “Allow Modification of macOS Settings from Command Line” in Settings for these options.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
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
                            .lineLimit(2)
                            .textSelection(.enabled)
                    }

                    if let error = panelError {
                        Text("Error: \(error)")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }

                    if let statusMessage, settings.hideVerboseOutput {
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if !appPath.isEmpty {
                        PathStatusView(path: appPath)
                    }

                    if !outputText.isEmpty && !settings.hideVerboseOutput {
                        Text("Output:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ScrollView {
                            Text(outputText)
                                .font(.system(.body, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        .frame(height: 100)
                        .padding(8)
                        .background(Color(nsColor: .textBackgroundColor))
                        .cornerRadius(6)
                    }

                    if let url = selectedURL, FileManager.default.fileExists(atPath: url.path) {
                        Button("Reveal in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        }
                    }
                }
            }
            .padding([.horizontal, .top])
            .toggleStyle(.checkbox)

            Divider()

            HStack {
                Spacer(minLength: 0)
                Button("Run") {
                    startRun()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(appPath.isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .frame(width: 560)
        .fixedSize(horizontal: true, vertical: true)
        .background(WindowConfigurator(lockToContentSize: true))
        .onReceive(NotificationCenter.default.publisher(for: .selectApp)) { _ in
            openPanel()
        }
        .onChange(of: appPath) { oldValue, newValue in
            let url = URL(fileURLWithPath: newValue)
            updateFromSelectedApp(url)
        }
        .onChange(of: bundleID) { _, newValue in
            if usedExistingBundleID,
               newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                != pickedExistingBundleID.trimmingCharacters(in: .whitespacesAndNewlines) {
                usedExistingBundleID = false
                pickedExistingBundleID = ""
            }
        }
    }

    private var categoryPickerSelection: Binding<String> {
        Binding(
            get: {
                AppCategory.knownSet.contains(trimmedCategoryType) ? trimmedCategoryType : ""
            },
            set: { newValue in
                if !newValue.isEmpty {
                    categoryType = newValue
                }
            }
        )
    }

    private func generateRandomBundleID() -> String {
        let wordlist = settings.bundleIDWordlist
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && BundleIDWordlistValidation.isAcceptableForSave($0) }

        if wordlist.count >= 2 {
            let first = wordlist.randomElement()!
            var second = wordlist.randomElement()!
            if wordlist.count > 1 {
                while second == first { second = wordlist.randomElement()! }
            }
            return "com.\(first).\(second)"
        }
        if let only = wordlist.first {
            return "com.\(only)"
        }

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
            updateFromSelectedApp(url)
            panelError = nil
        }
    }

    private func pickExistingBundleID() {
        AppSelectionPanel.present(retainAccess: false) { url in
            guard let appURL = enclosingAppBundleURL(startingAt: url),
                  let bundle = Bundle(url: appURL),
                  let id = bundle.bundleIdentifier else {
                panelError = "Couldn't read a bundle ID from the selected item."
                return
            }
            usedExistingBundleID = true
            pickedExistingBundleID = id
            bundleID = id
            panelError = nil
        }
    }

    private func updateFromSelectedApp(_ url: URL) {
        guard let appURL = enclosingAppBundleURL(startingAt: url) else { return }
        let patchURL = AppBundleResolver.patchAppURL(from: appURL)
        let infoPlistURL = patchURL.appendingPathComponent("Contents/Info.plist")
        if FileManager.default.fileExists(atPath: infoPlistURL.path) {
            plistPath = infoPlistURL.path
        }

        if let bundle = Bundle(url: patchURL) {
            if let id = bundle.bundleIdentifier {
                usedExistingBundleID = false
                pickedExistingBundleID = ""
                bundleID = id
                originalBundleID = id
            }
            if let category = bundle.object(forInfoDictionaryKey: "LSApplicationCategoryType") as? String {
                categoryType = category
            } else {
                categoryType = ""
            }
        }
    }

    private func updateBundleID(from url: URL) {
        updateFromSelectedApp(url)
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

    private func cloneAppBeforeSpoofing(at appURL: URL) throws -> URL {
        let parent = appURL.deletingLastPathComponent()
        let baseName = appURL.deletingPathExtension().lastPathComponent
        let ext = appURL.pathExtension.isEmpty ? "app" : appURL.pathExtension

        func candidateURL(index: Int) -> URL {
            let suffix = index == 1 ? " copy" : " copy \(index)"
            return parent.appendingPathComponent("\(baseName)\(suffix).\(ext)")
        }

        var index = 1
        var destination = candidateURL(index: index)
        while FileManager.default.fileExists(atPath: destination.path) {
            index += 1
            destination = candidateURL(index: index)
        }

        try FileManager.default.copyItem(at: appURL, to: destination)
        return destination
    }

    private func removeFrameworksIfNeeded(at appPath: String, enabled: Bool) throws {
        guard enabled else { return }
        let frameworksPath = (appPath as NSString).appendingPathComponent("Contents/Frameworks")
        guard FileManager.default.fileExists(atPath: frameworksPath) else { return }

        let targets = settings.targetedFrameworks
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if targets.isEmpty {
            try runCommand("/bin/rm", ["-rf", frameworksPath])
            return
        }

        let items = try FileManager.default.contentsOfDirectory(atPath: frameworksPath)
        for item in items {
            let matches = targets.contains { target in
                item == target
                    || item == "\(target).framework"
                    || item == "\(target).dylib"
                    || (item as NSString).deletingPathExtension == target
            }
            if matches {
                let itemPath = (frameworksPath as NSString).appendingPathComponent(item)
                try runCommand("/bin/rm", ["-rf", itemPath])
            }
        }
    }

    private func appendOutput(_ message: String) {
        if settings.hideVerboseOutput { return }
        outputText += message
    }

    @MainActor
    private func notifyCompletion(success: Bool, message: String) {
        guard settings.hideVerboseOutput else { return }
        statusMessage = message
        let alert = NSAlert()
        alert.alertStyle = success ? .informational : .warning
        alert.messageText = success ? "Finished" : "Error"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
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

    private func setBundleIdentifier(_ bundleID: String, plistAt plistPath: String) throws {
        let path = plistPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else {
            throw NSError(
                domain: "packageSpoofer",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Info.plist path is empty."]
            )
        }
        guard FileManager.default.fileExists(atPath: path) else {
            throw NSError(
                domain: "packageSpoofer",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Info.plist not found at \(path)"]
            )
        }
        try runCommand("/usr/bin/plutil", ["-replace", "CFBundleIdentifier", "-string", bundleID, path])
    }

    private func setBundleIdentifier(_ bundleID: String, forAppAt appPath: String) throws {
        let infoPlistPath = (appPath as NSString).appendingPathComponent("Contents/Info.plist")
        try setBundleIdentifier(bundleID, plistAt: infoPlistPath)
    }

    private func setCategoryType(_ category: String, forAppAt appPath: String) throws {
        let infoPlistPath = (appPath as NSString).appendingPathComponent("Contents/Info.plist")
        try setCategoryType(category, plistAt: infoPlistPath)
    }

    private func setCategoryType(_ category: String, plistAt plistPath: String) throws {
        let path = plistPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else {
            throw NSError(
                domain: "packageSpoofer",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Info.plist path is empty."]
            )
        }
        guard FileManager.default.fileExists(atPath: path) else {
            throw NSError(
                domain: "packageSpoofer",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Info.plist not found at \(path)"]
            )
        }

        // Prefer replace; insert when the key is missing.
        if runQuietCommand("/usr/bin/plutil", ["-replace", "LSApplicationCategoryType", "-string", category, path]) {
            return
        }
        try runCommand("/usr/bin/plutil", ["-insert", "LSApplicationCategoryType", "-string", category, path])
    }

    @discardableResult
    private func runQuietCommand(_ launchPath: String, _ arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
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

    private func bypassGatekeeperIfNeeded(at appPath: String, enabled: Bool) throws {
        guard enabled else { return }
        guard FileManager.default.fileExists(atPath: appPath) else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        process.arguments = ["-dr", "com.apple.quarantine", appPath]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        // Non-zero usually means quarantine was already absent; that's fine.
    }

    private func openAppOnCompletion(at resolvedPath: String) {
        let resolvedURL = URL(fileURLWithPath: resolvedPath)
        let launchURL = AppBundleResolver.patchAppURL(from: resolvedURL)
        NSWorkspace.shared.open(launchURL)
    }

    private func forceMetalHUD(forBundleID identifier: String) throws {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try runCommand("/usr/bin/defaults", ["write", trimmed, "MetalForceHudEnabled", "-bool", "YES"])
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
            statusMessage = nil
            outputText = ""
            appendOutput("Starting actions...\n")
        }

        guard let originalAppURL = enclosingAppBundleURL(startingAt: URL(fileURLWithPath: appPath)) else {
            await MainActor.run { panelError = "No enclosing .app bundle found for the given path." }
            return
        }

        let accessURL = selectedURL ?? originalAppURL
        guard SelectedAppAccess.beginAccess(for: accessURL) else {
            await MainActor.run {
                panelError = "Could not access the selected app. Use Browse or File → Select App to choose it again."
            }
            return
        }

        var appURL = originalAppURL
        do {
            if patchOptions.cloneBeforeSpoofing {
                await MainActor.run { appendOutput("[Pre-Patch] Cloning app before spoofing...\n") }
                let cloneURL = try cloneAppBeforeSpoofing(at: originalAppURL)
                appURL = cloneURL
                _ = SelectedAppAccess.beginAccess(for: cloneURL)
                await MainActor.run {
                    selectedURL = cloneURL
                    appPath = cloneURL.path
                    updateFromSelectedApp(cloneURL)
                    appendOutput("Cloned to: \(cloneURL.path)\n")
                }
            }
        } catch {
            await MainActor.run {
                panelError = error.localizedDescription
                appendOutput("Failed to clone app: \(error.localizedDescription)\n")
                notifyCompletion(success: false, message: "Failed to clone app: \(error.localizedDescription)")
            }
            return
        }

        var resolvedPath = appURL.path
        let patchAppURL = AppBundleResolver.patchAppURL(from: appURL)
        let patchPath = patchAppURL.path
        let isWrapped = AppBundleResolver.isWrappedApp(at: appURL)
        let allowMacOSModification = await MainActor.run { settings.allowMacOSModification }

        do {
            try AppWritableCheck.validateWritableAppBundle(at: appURL)
            try ensureAppBundleWritable(at: patchAppURL)
            await MainActor.run {
                appendOutput("Resolved app: \(resolvedPath)\n")
                if isWrapped {
                    appendOutput("Detected appUnblocker wrapper; patching nested app: \(patchPath)\n")
                }
            }

            if patchOptions.removeFrameworks {
                await MainActor.run { appendOutput("[Pre-Patch] Removing embedded frameworks...\n") }
                try removeFrameworksIfNeeded(at: patchPath, enabled: true)
            }

            if patchOptions.applyBinaryFix {
                await MainActor.run { appendOutput("[Pre-Patch] Making executable (chmod +x)...\n") }
                try applyBinaryFixIfNeeded(at: patchPath, enabled: true)
            }

            if !bundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let resolvedPlist = plistPath.trimmingCharacters(in: .whitespacesAndNewlines)
                await MainActor.run {
                    appendOutput("Setting bundle identifier to: \(bundleID)\n")
                    if !resolvedPlist.isEmpty {
                        appendOutput("Using Info.plist: \(resolvedPlist)\n")
                    }
                }
                if resolvedPlist.isEmpty {
                    try setBundleIdentifier(bundleID, forAppAt: patchPath)
                } else {
                    try setBundleIdentifier(bundleID, plistAt: resolvedPlist)
                }
            } else {
                await MainActor.run { appendOutput("Bundle ID empty; skipping bundle identifier update.\n") }
            }

            if patchOptions.applyCategorySpoofer {
                let category = categoryType.trimmingCharacters(in: .whitespacesAndNewlines)
                let resolvedPlist = plistPath.trimmingCharacters(in: .whitespacesAndNewlines)
                if category.isEmpty {
                    await MainActor.run { appendOutput("[Pre-Patch] Category Spoofer enabled but category is empty; skipping.\n") }
                } else {
                    await MainActor.run { appendOutput("[Pre-Patch] Setting LSApplicationCategoryType to: \(category)\n") }
                    if resolvedPlist.isEmpty {
                        try setCategoryType(category, forAppAt: patchPath)
                    } else {
                        try setCategoryType(category, plistAt: resolvedPlist)
                    }
                }
            }

            await MainActor.run { appendOutput("Signing app (ad-hoc)...\n") }
            try codesignApp(at: patchPath)

            if patchOptions.applyAppUnblocker {
                await MainActor.run { appendOutput("[Post-Patch] Applying appUnblocker...\n") }
                let wrapperURL = try AppUnblocker.apply(to: appURL)
                let nestedAppURL = AppBundleResolver.patchAppURL(from: wrapperURL)
                await MainActor.run { appendOutput("Re-signing nested app after appUnblocker...\n") }
                try codesignApp(at: nestedAppURL.path)
                resolvedPath = wrapperURL.path
                await MainActor.run {
                    selectedURL = wrapperURL
                    appPath = wrapperURL.path
                    updateBundleID(from: nestedAppURL)
                    if isWrapped {
                        appendOutput("Refreshed wrapper at \(wrapperURL.path)\n")
                    } else {
                        appendOutput("Created wrapper at \(wrapperURL.path)\n")
                    }
                    appendOutput("Launch shortcut added next to the wrapper (symlink).\n")
                }
            }

            if patchOptions.bypassGatekeeper {
                if allowMacOSModification {
                    await MainActor.run { appendOutput("[Post-Patch] Bypassing Gatekeeper (clear quarantine)...\n") }
                    try bypassGatekeeperIfNeeded(at: resolvedPath, enabled: true)
                } else {
                    await MainActor.run {
                        appendOutput("[Post-Patch] Skipping Bypass Gatekeeper — macOS modification is disabled in Settings.\n")
                    }
                }
            }

            if patchOptions.hideFileAfterSigning {
                if allowMacOSModification {
                    await MainActor.run { appendOutput("[Post-Patch] Hiding file in Finder...\n") }
                    try hideFileIfNeeded(at: resolvedPath, enabled: true)
                    try hideLaunchShortcutIfPresent(near: URL(fileURLWithPath: resolvedPath), enabled: true)
                } else {
                    await MainActor.run {
                        appendOutput("[Post-Patch] Skipping Hide File After Signing — macOS modification is disabled in Settings.\n")
                    }
                }
            }

            if patchOptions.forceMetalHUD {
                let hudBundleID = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
                if hudBundleID.isEmpty {
                    await MainActor.run {
                        appendOutput("[Post-Patch] Force Metal HUD enabled but Bundle ID is empty; skipping.\n")
                    }
                } else {
                    await MainActor.run {
                        appendOutput("[Post-Patch] Forcing Metal HUD for \(hudBundleID)...\n")
                    }
                    try forceMetalHUD(forBundleID: hudBundleID)
                }
            }

            if patchOptions.openAppOnCompletion {
                await MainActor.run { appendOutput("[Post-Patch] Opening app on completion...\n") }
                openAppOnCompletion(at: resolvedPath)
            }

            await MainActor.run {
                appendOutput("Done.\n")
                notifyCompletion(success: true, message: "packageSpoofer completed successfully.")
                TerminalLogCleaner.deleteAppTerminalLogsIfEnabled()
            }
        } catch AppWritableCheck.Failure.readOnlyVolume {
            await MainActor.run { showReadOnlyVolumeAlert() }
        } catch {
            await MainActor.run {
                panelError = error.localizedDescription
                appendOutput("Failed: \(error.localizedDescription)\n")
                notifyCompletion(success: false, message: error.localizedDescription)
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

