import SwiftUI
import AppKit

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.openWindow) private var openWindow
    @State private var frameworkDraft = ""

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section("Spoofing") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Bundle ID Wordlist")
                        .font(.headline)
                    Text("Set a custom wordlist for random bundle ID generation.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack {
                        Text(settings.bundleIDWordlist.isEmpty
                             ? "Using built-in random segments"
                             : "\(settings.bundleIDWordlist.count) word(s) saved")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Create Wordlist…") {
                            openWindow(id: "wordlist")
                        }
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Targeted Frameworks List")
                        .font(.headline)
                    Text("Frameworks that will be removed when detected by the \"Remove frameworks\" option in the menu. By default packageSpoofer will look for /Contents/Frameworks in your app and delete that entire folder.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack {
                        TextField("Framework name or dylib", text: $frameworkDraft)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { addFrameworkDraft() }
                        Button("Add") { addFrameworkDraft() }
                            .disabled(frameworkDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Button("Browse…") { pickFramework() }
                    }

                    if settings.targetedFrameworks.isEmpty {
                        Text("No targeted frameworks — entire Frameworks folder will be removed.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        List {
                            ForEach(settings.targetedFrameworks, id: \.self) { item in
                                HStack {
                                    Text(item)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Spacer()
                                    Button(role: .destructive) {
                                        settings.targetedFrameworks.removeAll { $0 == item }
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                        .frame(minHeight: 80, maxHeight: 140)
                    }
                }
            }

            Section("Security") {
                settingRow(
                    title: "Auto Delete Terminal Logs",
                    description: "Automatically permanently deletes all Terminal logs made by the app if it occurs."
                ) {
                    Picker("", selection: $settings.autoDeleteTerminalLogs) {
                        Text("Yes (default)").tag(true)
                        Text("No (not recommended)").tag(false)
                    }
                    .labelsHidden()
                    .pickerStyle(.radioGroup)
                }

                settingRow(
                    title: "Hide Verbose Output",
                    description: "Hides the verbose output shown when running the packageSpoofer exploit. You will still be notified if there is an error or if the exploit completes successfully."
                ) {
                    Picker("", selection: $settings.hideVerboseOutput) {
                        Text("No (default)").tag(false)
                        Text("Yes").tag(true)
                    }
                    .labelsHidden()
                    .pickerStyle(.radioGroup)
                }

                settingRow(
                    title: "Allow Modification of macOS Settings from Command Line",
                    description: "Allows packageSpoofer to modify parts of macOS if needed by a setting. Required for \"Bypass Gatekeeper\" and \"Hide File After Signing\" option to work properly."
                ) {
                    Picker("", selection: $settings.allowMacOSModification) {
                        Text("Yes (default)").tag(true)
                        Text("No (not recommended)").tag(false)
                    }
                    .labelsHidden()
                    .pickerStyle(.radioGroup)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 560, height: 560)
        .background(WindowConfigurator(lockToContentSize: true))
    }

    @ViewBuilder
    private func settingRow<Content: View>(
        title: String,
        description: String,
        @ViewBuilder control: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            control()
        }
        .padding(.vertical, 4)
    }

    private func addFrameworkDraft() {
        let value = frameworkDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        if !settings.targetedFrameworks.contains(value) {
            settings.targetedFrameworks.append(value)
        }
        frameworkDraft = ""
    }

    private func pickFramework() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        panel.message = "Choose framework folders or framework/dylib executables to target."
        panel.begin { response in
            guard response == .OK else { return }
            for url in panel.urls {
                let name = url.lastPathComponent
                if !settings.targetedFrameworks.contains(name) {
                    settings.targetedFrameworks.append(name)
                }
            }
        }
    }
}
