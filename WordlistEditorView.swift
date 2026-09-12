import SwiftUI

struct WordlistEditorView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var draft = ""
    @State private var entries: [String] = []

    private var draftMessages: [String] {
        BundleIDWordlistValidation.messages(for: draft)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bundle ID Wordlist")
                .font(.title3.bold())
            Text("Add strings used when generating random bundle IDs. Entries are joined as segments (for example com.word1.word2).")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                TextField("word or segment", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addDraft)
                Button("Add") { addDraft() }
                    .disabled(!canAddDraft)
            }

            if !draftMessages.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(draftMessages, id: \.self) { message in
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(isBlockingMessage(message) ? .red : .orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if entries.isEmpty {
                Text("No words yet.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
            } else {
                List {
                    ForEach(entries, id: \.self) { entry in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry)
                                ForEach(BundleIDWordlistValidation.messages(for: entry), id: \.self) { message in
                                    Text(message)
                                        .font(.caption2)
                                        .foregroundStyle(isBlockingMessage(message) ? .red : .orange)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            Spacer()
                            Button(role: .destructive) {
                                entries.removeAll { $0 == entry }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                .frame(minHeight: 180)
            }

            Spacer(minLength: 0)

            HStack {
                Button("Clear All", role: .destructive) {
                    entries.removeAll()
                }
                .disabled(entries.isEmpty)
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    settings.bundleIDWordlist = entries
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 480, height: 420)
        .background(WindowConfigurator(disableMinimize: true, lockToContentSize: true))
        .onAppear {
            entries = settings.bundleIDWordlist
        }
    }

    private var canAddDraft: Bool {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return BundleIDWordlistValidation.isAcceptableForSave(trimmed)
            && !entries.contains(trimmed)
    }

    private func isBlockingMessage(_ message: String) -> Bool {
        message == BundleIDWordlistValidation.specialCharactersMessage
            || message == BundleIDWordlistValidation.comAppleMessage
    }

    private func addDraft() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canAddDraft else { return }
        entries.append(trimmed)
        draft = ""
    }
}
