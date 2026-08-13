import Foundation

/// VoiceOver identifier + label contract for Daily / Editor / Search / Settings (PR39).
///
/// SwiftUI views apply these strings. XCTest asserts the catalog without importing SwiftUI.
public enum LociAccessibilityCatalog: Sendable {
    public static let dailyNote = "daily-note"
    public static let dailyNoteLabel = "Daily note"
    public static let objectEditor = "object-editor"
    public static let objectEditorLabel = "Object editor"
    public static let search = "search-destination"
    public static let searchLabel = "Search"
    public static let settings = "vault-settings"
    public static let settingsLabel = "Settings"

    public static let dailyTitle = "daily-title-field"
    public static let dailyTitleLabel = "Title"
    public static let editorTitle = "object-editor-title"
    public static let editorTitleLabel = "Title"
    public static let searchQuery = "search-query-field"
    public static let searchQueryLabel = "Query"
    public static let vaultPath = "vault-path-display"

    /// Screen containers that must exist for VoiceOver (Daily / Editor / Search / Settings).
    public static let screenIdentifiers: [String] = [
        dailyNote,
        objectEditor,
        search,
        settings,
    ]

    public static let screenLabels: [String] = [
        dailyNoteLabel,
        objectEditorLabel,
        searchLabel,
        settingsLabel,
    ]

    public static var screenIdentifiersAreUnique: Bool {
        Set(screenIdentifiers).count == screenIdentifiers.count
    }

    public static var hasDailyEditorSearchSettings: Bool {
        screenIdentifiers.contains(dailyNote)
            && screenIdentifiers.contains(objectEditor)
            && screenIdentifiers.contains(search)
            && screenIdentifiers.contains(settings)
            && screenIdentifiers.count == 4
    }
}
