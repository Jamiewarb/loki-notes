import Foundation

/// Linux-testable notes for the type-dashboard Board view (PR42).
///
/// Columns come from `DashboardGrouping` (select option order / observed tags).
/// Moving a card updates YAML frontmatter via `KanbanMove` + `ObjectServing.save`.
/// Kanban layout is never written into object or daily markdown.
public struct KanbanProof: Hashable, Sendable, Equatable, Codable {
    public var boardColumnsFromGroup: Bool
    public var moveUpdatesVaultYAML: Bool
    public var layoutNotWrittenToMarkdown: Bool
    public var indexInsideVault: Bool

    public init(
        boardColumnsFromGroup: Bool,
        moveUpdatesVaultYAML: Bool,
        layoutNotWrittenToMarkdown: Bool,
        indexInsideVault: Bool
    ) {
        self.boardColumnsFromGroup = boardColumnsFromGroup
        self.moveUpdatesVaultYAML = moveUpdatesVaultYAML
        self.layoutNotWrittenToMarkdown = layoutNotWrittenToMarkdown
        self.indexInsideVault = indexInsideVault
    }

    /// Evaluate proof from a move + grouping round-trip (no GRDB in LociCore).
    public static func evaluate(
        columnKeys: [String],
        expectedColumnKeys: [String],
        yamlSnippet: String,
        expectedYAMLValue: String,
        bodyBefore: String,
        bodyAfter: String,
        dailyUnchanged: Bool,
        indexInsideVault: Bool
    ) -> KanbanProof {
        KanbanProof(
            boardColumnsFromGroup: columnKeys == expectedColumnKeys,
            moveUpdatesVaultYAML: yamlContainsValue(yamlSnippet, expectedYAMLValue),
            layoutNotWrittenToMarkdown: bodyBefore == bodyAfter
                && dailyUnchanged
                && !markdownLooksLikeBoardLayout(bodyAfter),
            indexInsideVault: indexInsideVault
        )
    }

    /// Board HTML / harness markers must never appear in note bodies.
    public static func markdownLooksLikeBoardLayout(_ markdown: String) -> Bool {
        let needles = ["kanban-column", "kanban-card", "data-harness", "board-layout"]
        return needles.contains { markdown.localizedCaseInsensitiveContains($0) }
    }

    private static func yamlContainsValue(_ yaml: String, _ value: String) -> Bool {
        let wanted = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !wanted.isEmpty else { return false }
        return yaml.contains(wanted)
    }
}

/// Contract notes so XCTest / DevHarness never import SwiftUI.
public enum KanbanNotes: Sendable {
    public static let boardColumnsFromGroup = true
    public static let moveUpdatesVaultYAML = true
    public static let layoutNotWrittenToMarkdown = true
    public static let usesObjectServing = true
    public static let saveProtocol = "ObjectServing.open + save"
    public static let listOrBoardToggle = true
}
