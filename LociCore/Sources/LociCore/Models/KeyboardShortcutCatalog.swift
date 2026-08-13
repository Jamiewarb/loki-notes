import Foundation

/// One macOS menu command (PR39). Strings only — Linux tests never import SwiftUI.
public struct KeyboardShortcutSpec: Hashable, Sendable, Equatable, Codable {
    public var actionID: String
    public var key: String
    public var modifiers: String
    public var title: String

    public init(actionID: String, key: String, modifiers: String, title: String) {
        self.actionID = actionID
        self.key = key
        self.modifiers = modifiers
        self.title = title
    }

    public var combo: String { "\(key)|\(modifiers)" }

    public var usesShift: Bool {
        modifiers.split(separator: "+").map(String.init).contains("shift")
    }

    public var usesCommand: Bool {
        modifiers.split(separator: "+").map(String.init).contains("command")
    }
}

/// Catalog of macOS `.commands` shortcuts. App/ wires the same action ids.
public enum KeyboardShortcutCatalog: Sendable {
    public static let newPage = KeyboardShortcutSpec(
        actionID: "newPage",
        key: "n",
        modifiers: "command",
        title: "New Page"
    )
    public static let search = KeyboardShortcutSpec(
        actionID: "search",
        key: "k",
        modifiers: "command",
        title: "Search"
    )
    public static let goToday = KeyboardShortcutSpec(
        actionID: "goToday",
        key: "t",
        modifiers: "command",
        title: "Go to Today"
    )
    public static let quickCapture = KeyboardShortcutSpec(
        actionID: "quickCapture",
        key: "n",
        modifiers: "command+shift",
        title: "Quick Capture"
    )

    public static let all: [KeyboardShortcutSpec] = [
        newPage,
        search,
        goToday,
        quickCapture,
    ]

    public static var actionIDs: [String] { all.map(\.actionID) }

    public static var combosAreUnique: Bool {
        Set(all.map(\.combo)).count == all.count
    }

    public static var actionIDsAreUnique: Bool {
        Set(actionIDs).count == all.count
    }
}
