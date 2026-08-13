import Foundation

/// Linux-testable notes for unlinked title mentions (PR44).
///
/// Mentions are derived UI from the local index + a pure scanner. Listing them
/// must not rewrite markdown. An explicit **Link** tap may replace the first
/// unlinked occurrence with `[[id|title]]` via `ObjectServing.save`.
public struct UnlinkedMentionProof: Hashable, Sendable, Equatable, Codable {
    public var detectsPlainTitle: Bool
    public var ignoresExistingWikiLink: Bool
    public var doesNotRewriteBody: Bool
    public var indexInsideVault: Bool

    public init(
        detectsPlainTitle: Bool,
        ignoresExistingWikiLink: Bool,
        doesNotRewriteBody: Bool,
        indexInsideVault: Bool
    ) {
        self.detectsPlainTitle = detectsPlainTitle
        self.ignoresExistingWikiLink = ignoresExistingWikiLink
        self.doesNotRewriteBody = doesNotRewriteBody
        self.indexInsideVault = indexInsideVault
    }

    /// Evaluate scanner + non-mutation proofs (no GRDB in LociCore).
    public static func evaluate(
        plainBody: String,
        wikiLinkedBody: String,
        wordBoundaryBody: String,
        title: String,
        bodyBefore: String,
        bodyAfterScan: String,
        indexInsideVault: Bool
    ) -> UnlinkedMentionProof {
        let plainHit = UnlinkedMentionScanner.mentions(plainBody, title: title)
        let wikiHit = UnlinkedMentionScanner.mentions(wikiLinkedBody, title: title)
        let workingHit = UnlinkedMentionScanner.mentions(wordBoundaryBody, title: title)
        let before = bodyBefore.trimmingCharacters(in: .whitespacesAndNewlines)
        let after = bodyAfterScan.trimmingCharacters(in: .whitespacesAndNewlines)
        return UnlinkedMentionProof(
            detectsPlainTitle: plainHit && !workingHit,
            ignoresExistingWikiLink: !wikiHit,
            doesNotRewriteBody: before == after && !bodyAfterScan.contains("[["),
            indexInsideVault: indexInsideVault
        )
    }
}

/// Contract notes so XCTest / DevHarness never import SwiftUI.
public enum UnlinkedMentionNotes: Sendable {
    public static let detectsPlainTitle = true
    public static let ignoresExistingWikiLink = true
    public static let doesNotRewriteBody = true
    public static let queryProtocol = "IndexQuerying.unlinkedMentions"
    public static let resultLimit = UnlinkedMentionScanner.resultLimit
    public static let minimumTitleLength = UnlinkedMentionScanner.minimumTitleLength
    public static let linkUsesObjectServing = true
    public static let neverOnTypingPath = true
}
