import Foundation

enum AppWritableCheck {
    static let readOnlyVolumeUserMessage =
        "This is a read-only volume. packageSpoofer cannot use this volume.\n\n" +
        "If you are trying to install an app from a .dmg file, move the app from the .dmg to any location on your system, then click \"Browse...\" in the app and select the app."

    enum Failure: LocalizedError {
        case bundleNotFound
        case readOnlyVolume
        case notWritable(String)

        var errorDescription: String? {
            switch self {
            case .bundleNotFound:
                return "The selected .app bundle could not be found."
            case .readOnlyVolume:
                return AppWritableCheck.readOnlyVolumeUserMessage
            case .notWritable(let path):
                return """
                The app at \(path) is not writable. packageSpoofer needs permission to change files inside the bundle.

                Copy the app to a writable folder (for example ~/Downloads) and try again.
                """
            }
        }
    }

    static func isOnReadOnlyVolume(at url: URL) -> Bool {
        let patchURL = AppBundleResolver.patchAppURL(from: url)
        let contentsURL = patchURL.appendingPathComponent("Contents", isDirectory: true)
        if FileManager.default.fileExists(atPath: contentsURL.path) {
            return isVolumeReadOnly(at: contentsURL)
        }
        return isVolumeReadOnly(at: url)
    }

    private static func isVolumeReadOnly(at url: URL) -> Bool {
        if let readOnly = try? url.resourceValues(forKeys: [.volumeIsReadOnlyKey]).volumeIsReadOnly,
           readOnly {
            return true
        }
        return false
    }

    static func validateWritableAppBundle(at appURL: URL) throws {
        try validateWritableAppBundle(at: AppBundleResolver.patchAppURL(from: appURL), resolvedFrom: appURL)
    }

    private static func validateWritableAppBundle(at patchAppURL: URL, resolvedFrom selectionURL: URL) throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: patchAppURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw Failure.bundleNotFound
        }

        let contentsURL = patchAppURL.appendingPathComponent("Contents", isDirectory: true)
        guard FileManager.default.fileExists(atPath: contentsURL.path) else {
            throw Failure.bundleNotFound
        }

        if isVolumeReadOnly(at: contentsURL) {
            throw Failure.readOnlyVolume
        }

        let testURL = contentsURL.appendingPathComponent(".packagespoofer_write_test")
        if FileManager.default.createFile(atPath: testURL.path, contents: Data()) {
            try? FileManager.default.removeItem(at: testURL)
            return
        }

        throw Failure.notWritable(selectionURL.path)
    }
}
