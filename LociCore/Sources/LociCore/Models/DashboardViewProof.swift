import Foundation

/// Linux-testable notes for type-dashboard filter / sort / group (PR41).
///
/// The list is `IndexQuerying.execute(QueryDefinition)`. Group-by is derived UI.
/// Changing sort / filter / group must not rewrite object markdown or daily notes
/// — only `.loci/types/<slug>.json` dashboard fields may change.
public struct DashboardViewProof: Hashable, Sendable, Equatable, Codable {
    public var filterApplied: Bool
    public var sortApplied: Bool
    public var groupApplied: Bool
    /// Filter / sort / group results were not written into object or daily markdown.
    public var resultsNotWrittenToMarkdown: Bool
    public var indexInsideVault: Bool

    public init(
        filterApplied: Bool,
        sortApplied: Bool,
        groupApplied: Bool,
        resultsNotWrittenToMarkdown: Bool,
        indexInsideVault: Bool
    ) {
        self.filterApplied = filterApplied
        self.sortApplied = sortApplied
        self.groupApplied = groupApplied
        self.resultsNotWrittenToMarkdown = resultsNotWrittenToMarkdown
        self.indexInsideVault = indexInsideVault
    }

    /// Evaluate proof from a QueryEngine + grouping round-trip (no GRDB in LociCore).
    public static func evaluate(
        filteredTitles: [String],
        expectedFilteredTitles: [String],
        sortedTitles: [String],
        expectedSortedTitles: [String],
        sectionKeys: [String],
        expectedSectionKey: String,
        objectMarkdownUnchanged: Bool,
        dailyUnchanged: Bool,
        indexInsideVault: Bool
    ) -> DashboardViewProof {
        DashboardViewProof(
            filterApplied: filteredTitles == expectedFilteredTitles,
            sortApplied: sortedTitles == expectedSortedTitles,
            groupApplied: sectionKeys.contains(expectedSectionKey),
            resultsNotWrittenToMarkdown: objectMarkdownUnchanged && dailyUnchanged,
            indexInsideVault: indexInsideVault
        )
    }
}

/// Contract notes so XCTest / DevHarness never import SwiftUI or Features/Queries.
public enum DashboardViewNotes: Sendable {
    public static let usesQueryEngine = true
    public static let queryProtocol = "IndexQuerying.execute"
    public static let groupByIsDerivedUI = true
    public static let resultsNotWrittenToMarkdown = true
    public static let collectionsAreVaultJSON = true
    /// ObjectTypes may keep existing Feature facade calls; do not import Queries for the list.
    public static let mustNotImportQueriesFeature = true
}
