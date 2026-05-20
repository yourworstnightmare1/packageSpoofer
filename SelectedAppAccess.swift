import Foundation

/// Retains security-scoped access for a user-selected app bundle (required when App Sandbox is on).
enum SelectedAppAccess {
    private static var activeURL: URL?
    private static var isAccessing = false

    static func beginAccess(for url: URL) -> Bool {
        if activeURL?.standardizedFileURL != url.standardizedFileURL {
            endAccess()
            activeURL = url
        }
        guard !isAccessing else { return true }
        guard url.startAccessingSecurityScopedResource() else { return false }
        isAccessing = true
        return true
    }

    static func endAccess() {
        if isAccessing, let activeURL {
            activeURL.stopAccessingSecurityScopedResource()
        }
        isAccessing = false
        activeURL = nil
    }
}
