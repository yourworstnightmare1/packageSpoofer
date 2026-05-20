import Foundation

enum AppBundleResolver {
    /// Returns the real .app bundle to patch (nested app when already wrapped).
    static func patchAppURL(from url: URL) -> URL {
        let nested = url.appendingPathComponent(url.lastPathComponent, isDirectory: true)
        let nestedPlist = nested.appendingPathComponent("Contents/Info.plist")
        if FileManager.default.fileExists(atPath: nestedPlist.path) {
            return nested
        }
        return url
    }

    static func isWrappedApp(at url: URL) -> Bool {
        patchAppURL(from: url).path != url.path
    }

    static func wrapperURL(from url: URL) -> URL {
        isWrappedApp(at: url) ? url : url.deletingLastPathComponent().appendingPathComponent(url.lastPathComponent)
    }
}
