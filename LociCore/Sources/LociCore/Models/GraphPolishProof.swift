import Foundation

/// Linux-testable notes for graph polish (PR45).
///
/// Hide-hubs and 1-hop focus are derived UI over `GraphAssembly`. Layout
/// coordinates must never be written into vault markdown or space.json.
public struct GraphPolishProof: Hashable, Sendable, Equatable, Codable {
    public var hidesHighDegree: Bool
    public var focusNeighbors: Bool
    public var layoutNotWrittenToVault: Bool
    public var indexInsideVault: Bool

    public init(
        hidesHighDegree: Bool,
        focusNeighbors: Bool,
        layoutNotWrittenToVault: Bool,
        indexInsideVault: Bool
    ) {
        self.hidesHighDegree = hidesHighDegree
        self.focusNeighbors = focusNeighbors
        self.layoutNotWrittenToVault = layoutNotWrittenToVault
        self.indexInsideVault = indexInsideVault
    }

    /// Evaluate hide-hubs + isolate + “layout stays out of the vault”.
    public static func evaluate(
        fullTitles: [String],
        hiddenTitles: [String],
        hubTitle: String,
        spokeTitles: [String],
        focusedTitles: [String],
        expectedFocusTitles: [String],
        vaultTexts: [String],
        indexInsideVault: Bool
    ) -> GraphPolishProof {
        let full = Set(fullTitles)
        let hidden = Set(hiddenTitles)
        let focused = Set(focusedTitles)
        let expectedFocus = Set(expectedFocusTitles)
        let hides =
            full.contains(hubTitle)
            && !hidden.contains(hubTitle)
            && spokeTitles.allSatisfy { hidden.contains($0) }
        let layoutClean = vaultTexts.allSatisfy { !markdownLooksLikeGraphLayout($0) }
        return GraphPolishProof(
            hidesHighDegree: hides,
            focusNeighbors: focused == expectedFocus && !expectedFocus.isEmpty,
            layoutNotWrittenToVault: layoutClean,
            indexInsideVault: indexInsideVault
        )
    }

    /// Force-layout / harness markers must never appear in note bodies or space.json.
    public static func markdownLooksLikeGraphLayout(_ text: String) -> Bool {
        let needles = [
            "graph-layout",
            "graph-node",
            "data-harness",
            "force-directed-x",
            "node-position",
            "layout-x",
            "layout-y",
        ]
        return needles.contains { text.localizedCaseInsensitiveContains($0) }
    }
}

/// Contract notes so XCTest / DevHarness never import SwiftUI.
public enum GraphPolishNotes: Sendable {
    public static let hidesHighDegree = true
    public static let focusNeighbors = true
    public static let layoutNotWrittenToVault = true
    public static let sessionOnlyNotVault = true
    public static let defaultHideHubDegree = GraphBuildOptions.defaultHideHubDegree
    public static let queryProtocol = "IndexQuerying.graph"
    public static let neverOnTypingPath = true
}
