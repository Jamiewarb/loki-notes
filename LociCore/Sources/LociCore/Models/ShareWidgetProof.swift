import Foundation

/// Linux-testable notes for Share extension + Home Screen widget (PR37).
///
/// UIKit / WidgetKit / AppIntents stay in `App/Platform/iOS`. Tests and
/// DevHarness exercise `ShareInboxFactory` + `LociDeepLink` + these flags.
public struct ShareWidgetProof: Hashable, Sendable, Equatable, Codable {
    /// Share factory mapped text-only → append-to-today.
    public var shareExtractsText: Bool
    /// Widget “Open today” uses `loci://daily/today`.
    public var widgetOpenToday: Bool
    /// Staging path is `.loci/inbox/*.json`, not an index / SQLite path.
    public var inboxNotIndex: Bool
    public var indexInsideVault: Bool

    public init(
        shareExtractsText: Bool,
        widgetOpenToday: Bool,
        inboxNotIndex: Bool,
        indexInsideVault: Bool
    ) {
        self.shareExtractsText = shareExtractsText
        self.widgetOpenToday = widgetOpenToday
        self.inboxNotIndex = inboxNotIndex
        self.indexInsideVault = indexInsideVault
    }

    public static func evaluate(
        appendItem: CaptureInboxItem,
        createItem: CaptureInboxItem,
        inboxPath: String,
        openTodayURL: String = LociDeepLink.dailyTodayAbsoluteString,
        indexInsideVault: Bool
    ) -> ShareWidgetProof {
        let extracts =
            appendItem.kind == .appendToToday
            && !appendItem.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && appendItem.source == .share
            && createItem.kind == .createObject
            && createItem.typeID == .page
            && createItem.sourceURL != nil
        return ShareWidgetProof(
            shareExtractsText: extracts,
            widgetOpenToday: LociDeepLink.parse(openTodayURL) == .dailyToday,
            inboxNotIndex: ShareWidgetNotes.isInboxNotIndex(inboxPath),
            indexInsideVault: indexInsideVault
        )
    }
}

/// Contract notes so XCTest / DevHarness never import UIKit or WidgetKit.
public enum ShareWidgetNotes: Sendable {
    public static let openTodayURL = LociDeepLink.dailyTodayAbsoluteString
    public static let captureFallbackURL = LociDeepLink.captureAbsoluteString
    public static let inboxDirectory = CaptureInbox.directory
    /// Extension process writes vault inbox JSON only.
    public static let extensionDoesNotTouchIndex = true
    /// Code-present flags (Linux reports true like `photosPickerWired`).
    public static let shareExtractsText = true
    public static let widgetOpenToday = true

    public static func isInboxNotIndex(_ relativePath: String) -> Bool {
        let p = relativePath.replacingOccurrences(of: "\\", with: "/").lowercased()
        guard CaptureInbox.isInboxPath(relativePath) else { return false }
        if p.contains("index.sqlite") || p.contains("/index/") { return false }
        if p.hasPrefix("application support") { return false }
        return p.hasPrefix("\(CaptureInbox.directory.lowercased())/") && p.hasSuffix(".json")
    }
}
