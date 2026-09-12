import Foundation

enum AppCategory {
    /// Known `LSApplicationCategoryType` values from Apple's Info.plist keys.
    static let knownValues: [String] = [
        "public.app-category.business",
        "public.app-category.developer-tools",
        "public.app-category.education",
        "public.app-category.entertainment",
        "public.app-category.finance",
        "public.app-category.games",
        "public.app-category.action-games",
        "public.app-category.adventure-games",
        "public.app-category.arcade-games",
        "public.app-category.board-games",
        "public.app-category.card-games",
        "public.app-category.casino-games",
        "public.app-category.dice-games",
        "public.app-category.educational-games",
        "public.app-category.family-games",
        "public.app-category.kids-games",
        "public.app-category.music-games",
        "public.app-category.puzzle-games",
        "public.app-category.racing-games",
        "public.app-category.role-playing-games",
        "public.app-category.simulation-games",
        "public.app-category.sports-games",
        "public.app-category.strategy-games",
        "public.app-category.trivia-games",
        "public.app-category.word-games",
        "public.app-category.graphics-design",
        "public.app-category.healthcare-fitness",
        "public.app-category.lifestyle",
        "public.app-category.medical",
        "public.app-category.music",
        "public.app-category.news",
        "public.app-category.photography",
        "public.app-category.productivity",
        "public.app-category.reference",
        "public.app-category.social-networking",
        "public.app-category.sports",
        "public.app-category.travel",
        "public.app-category.utilities",
        "public.app-category.video",
        "public.app-category.weather",
    ]

    static let knownSet = Set(knownValues)

    static func isValid(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        return knownSet.contains(trimmed)
    }

    static func displayName(for value: String) -> String {
        let slug = value
            .replacingOccurrences(of: "public.app-category.", with: "")
            .replacingOccurrences(of: "-", with: " ")
        return slug.split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
    }
}
