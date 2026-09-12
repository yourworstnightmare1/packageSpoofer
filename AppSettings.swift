import Foundation
import Observation

@Observable
@MainActor
final class AppSettings {
    static let shared = AppSettings()

    private enum Keys {
        static let wordlist = "settings.bundleIDWordlist"
        static let targetedFrameworks = "settings.targetedFrameworks"
        static let autoDeleteTerminalLogs = "settings.autoDeleteTerminalLogs"
        static let hideVerboseOutput = "settings.hideVerboseOutput"
        static let allowMacOSModification = "settings.allowMacOSModification"
    }

    var bundleIDWordlist: [String] {
        didSet { UserDefaults.standard.set(bundleIDWordlist, forKey: Keys.wordlist) }
    }

    var targetedFrameworks: [String] {
        didSet { UserDefaults.standard.set(targetedFrameworks, forKey: Keys.targetedFrameworks) }
    }

    /// Automatically permanently deletes Terminal logs made by the app.
    var autoDeleteTerminalLogs: Bool {
        didSet { UserDefaults.standard.set(autoDeleteTerminalLogs, forKey: Keys.autoDeleteTerminalLogs) }
    }

    /// Hides verbose run output; still notifies on error/success.
    var hideVerboseOutput: Bool {
        didSet { UserDefaults.standard.set(hideVerboseOutput, forKey: Keys.hideVerboseOutput) }
    }

    /// Required for Bypass Gatekeeper and Hide File After Signing.
    var allowMacOSModification: Bool {
        didSet { UserDefaults.standard.set(allowMacOSModification, forKey: Keys.allowMacOSModification) }
    }

    private init() {
        let defaults = UserDefaults.standard
        bundleIDWordlist = defaults.stringArray(forKey: Keys.wordlist) ?? []
        targetedFrameworks = defaults.stringArray(forKey: Keys.targetedFrameworks) ?? []
        autoDeleteTerminalLogs = defaults.object(forKey: Keys.autoDeleteTerminalLogs) as? Bool ?? true
        hideVerboseOutput = defaults.object(forKey: Keys.hideVerboseOutput) as? Bool ?? false
        allowMacOSModification = defaults.object(forKey: Keys.allowMacOSModification) as? Bool ?? true
    }
}

enum BundleIDWordlistValidation {
    static let specialCharactersMessage =
        "You cannot use special characters in a bundle string without conflict occurring. Please remove all special characters."
    static let consecutiveDotsMessage =
        "It is not recommended to have 2 periods next to each other in a bundle string as it may cause problems in your app."
    static let comAppleMessage =
        "This bundle ID is recommended only for use on offical Apple/macOS bundle libraries to avoid conflict with real system services. Please remove com.apple from your bundle ID."
    static let tooManyDotsMessage =
        "It is recommended you only have 3 period seperations as it is standard convention and improves readability. This app will still run and in most cases without issue."

    /// Allowed characters for a wordlist segment / bundle fragment.
    private static let allowedCharacterSet = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.")

    static func messages(for string: String) -> [String] {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var messages: [String] = []

        if trimmed.unicodeScalars.contains(where: { !allowedCharacterSet.contains($0) }) {
            messages.append(specialCharactersMessage)
        }
        if trimmed.contains("..") {
            messages.append(consecutiveDotsMessage)
        }
        if trimmed.lowercased().contains("com.apple") {
            messages.append(comAppleMessage)
        }
        let dotCount = trimmed.filter { $0 == "." }.count
        if dotCount > 3 {
            messages.append(tooManyDotsMessage)
        }

        return messages
    }

    static func isAcceptableForSave(_ string: String) -> Bool {
        // Block save for special characters and com.apple; other messages are warnings.
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if trimmed.unicodeScalars.contains(where: { !allowedCharacterSet.contains($0) }) {
            return false
        }
        if trimmed.lowercased().contains("com.apple") {
            return false
        }
        return true
    }
}
