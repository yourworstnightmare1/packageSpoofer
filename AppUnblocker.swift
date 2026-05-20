import AppKit
import Foundation

enum AppUnblocker {
    enum UnblockerError: LocalizedError {
        case notAnAppBundle
        case appNotFound
        case wrapperAlreadyExists(String)
        case operationFailed(String)

        var errorDescription: String? {
            switch self {
            case .notAnAppBundle:
                return "The selected path is not a .app bundle."
            case .appNotFound:
                return "The selected app could not be found."
            case .wrapperAlreadyExists(let path):
                return "A wrapper already exists at \(path). Remove or rename it first."
            case .operationFailed(let message):
                return message
            }
        }
    }

    /// Wraps `appURL` in a new `.app` bundle with a launch shortcut, or refreshes an existing wrapper.
    /// Returns the path to the outer wrapper bundle.
    @discardableResult
    static func apply(to appURL: URL) throws -> URL {
        let patchAppURL = AppBundleResolver.patchAppURL(from: appURL)
        if AppBundleResolver.isWrappedApp(at: appURL) {
            return try refreshWrapper(wrapperURL: appURL, nestedAppURL: patchAppURL)
        }
        return try createWrapper(for: patchAppURL)
    }

    private static func createWrapper(for appURL: URL) throws -> URL {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(atPath: appURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw UnblockerError.appNotFound
        }
        guard appURL.pathExtension.lowercased() == "app" else {
            throw UnblockerError.notAnAppBundle
        }

        let parentDirectory = appURL.deletingLastPathComponent()
        let appFileName = appURL.lastPathComponent
        let wrapperURL = parentDirectory.appendingPathComponent(appFileName)
        let tempFolderURL = parentDirectory.appendingPathComponent("appUnblocker-\(UUID().uuidString)")

        if fileManager.fileExists(atPath: wrapperURL.path), wrapperURL.standardizedFileURL != appURL.standardizedFileURL {
            throw UnblockerError.wrapperAlreadyExists(wrapperURL.path)
        }

        try fileManager.createDirectory(at: tempFolderURL, withIntermediateDirectories: false)
        let tempNestedAppURL = tempFolderURL.appendingPathComponent(appFileName)
        do {
            try fileManager.moveItem(at: appURL, to: tempNestedAppURL)
            try fileManager.moveItem(at: tempFolderURL, to: wrapperURL)
        } catch {
            try? fileManager.removeItem(at: tempFolderURL)
            throw UnblockerError.operationFailed(error.localizedDescription)
        }

        let nestedAppURL = wrapperURL.appendingPathComponent(appFileName)
        try createLaunchShortcut(in: parentDirectory, to: nestedAppURL)
        return wrapperURL
    }

    private static func refreshWrapper(wrapperURL: URL, nestedAppURL: URL) throws -> URL {
        let parentDirectory = wrapperURL.deletingLastPathComponent()
        try createLaunchShortcut(in: parentDirectory, to: nestedAppURL)
        return wrapperURL
    }

    private static func createLaunchShortcut(in parentDirectory: URL, to targetURL: URL) throws {
        let shortcutName = launchShortcutName(for: targetURL, fallback: targetURL.deletingPathExtension().lastPathComponent)
        let shortcutURL = parentDirectory.appendingPathComponent(shortcutName)

        if FileManager.default.fileExists(atPath: shortcutURL.path) {
            try FileManager.default.removeItem(at: shortcutURL)
        }

        do {
            try FileManager.default.createSymbolicLink(atPath: shortcutURL.path, withDestinationPath: targetURL.path)
        } catch {
            throw UnblockerError.operationFailed("Failed to create launch shortcut: \(error.localizedDescription)")
        }
    }

    private static func launchShortcutName(for appURL: URL, fallback: String) -> String {
        let displayName: String
        if let bundle = Bundle(url: appURL) {
            displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? fallback
        } else {
            displayName = fallback
        }
        return "Launch \(displayName).app"
    }
}
