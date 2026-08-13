import Foundation

/// Linux-testable notes for macOS menu bar + Safari clipper (PR38).
///
/// AppKit / SafariServices stay in `App/Platform/macOS`. Tests and DevHarness
/// exercise `MenuBarCaptureFactory` + `SafariClipFactory.clip(fromUserInfo:)` +
/// these flags. Extensions never open SQLite.
public struct MenuBarSafariProof: Hashable, Sendable, Equatable, Codable {
    /// Menu bar install + quick capture / Open today are wired (`loci://daily/today`).
    public var menuBarWired: Bool
    /// Safari `userInfo` (`url` / `title` / `selection`) mapped to a clip / inbox item.
    public var safariExtractsPage: Bool
    /// Staging path is `.loci/inbox/*.json`, not an index / SQLite path.
    public var inboxNotIndex: Bool
    public var indexInsideVault: Bool

    public init(
        menuBarWired: Bool,
        safariExtractsPage: Bool,
        inboxNotIndex: Bool,
        indexInsideVault: Bool
    ) {
        self.menuBarWired = menuBarWired
        self.safariExtractsPage = safariExtractsPage
        self.inboxNotIndex = inboxNotIndex
        self.indexInsideVault = indexInsideVault
    }

    public static func evaluate(
        menuBarItem: CaptureInboxItem,
        safariItem: CaptureInboxItem,
        inboxPath: String,
        openTodayURL: String = LociDeepLink.dailyTodayAbsoluteString,
        indexInsideVault: Bool
    ) -> MenuBarSafariProof {
        let menuWired =
            menuBarItem.kind == .appendToToday
            && menuBarItem.source == .menuBar
            && !menuBarItem.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && LociDeepLink.parse(openTodayURL) == .dailyToday
        let extracts =
            safariItem.source == .safari
            && !(safariItem.sourceURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
            && (safariItem.kind == .appendToToday || safariItem.kind == .createObject)
        return MenuBarSafariProof(
            menuBarWired: menuWired,
            safariExtractsPage: extracts,
            inboxNotIndex: ShareWidgetNotes.isInboxNotIndex(inboxPath),
            indexInsideVault: indexInsideVault
        )
    }
}

/// Pure menu-bar → inbox mapping (no AppKit). Prefer `CaptureServing.appendToToday`
/// in the main app; vault-only processes enqueue this item instead.
public enum MenuBarCaptureFactory: Sendable {
    /// Quick capture line for today’s daily (or inbox when vault-only).
    public static func inboxItem(text: String, sourceURL: String? = nil) -> CaptureInboxItem {
        CaptureInboxItem.appendLine(
            text.trimmingCharacters(in: .whitespacesAndNewlines),
            source: .menuBar,
            sourceURL: sourceURL
        )
    }

    /// Full stack → append now; vault only → enqueue; neither → skip (no crash).
    public static func route(hasCapture: Bool, hasVault: Bool) -> MenuBarCaptureRoute {
        if hasCapture { return .appendToToday }
        if hasVault { return .enqueueInbox }
        return .unavailable
    }
}

/// How the menu bar should land a capture given available services.
public enum MenuBarCaptureRoute: String, Sendable, Hashable, Codable, Equatable {
    case appendToToday
    case enqueueInbox
    case unavailable
}

/// Contract notes so XCTest / DevHarness never import AppKit or SafariServices.
public enum MenuBarSafariNotes: Sendable {
    public static let openTodayURL = LociDeepLink.dailyTodayAbsoluteString
    public static let inboxDirectory = CaptureInbox.directory
    public static let jsPayloadKeys = ["url", "title", "selection"]
    /// Extension process writes vault inbox JSON only.
    public static let extensionDoesNotTouchIndex = true
    /// Code-present flags (Linux reports true like `photosPickerWired`).
    public static let menuBarWired = true
    public static let safariExtractsPage = true

    public static func isInboxNotIndex(_ relativePath: String) -> Bool {
        ShareWidgetNotes.isInboxNotIndex(relativePath)
    }
}
