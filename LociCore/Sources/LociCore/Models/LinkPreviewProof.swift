import Foundation

/// Linux-testable notes for the weblink preview metadata cache (PR43).
///
/// Cache lives next to the index (Application Support). Fetch happens on weblink
/// open / after create / Refresh preview — **never** on editor typing debounce.
public struct LinkPreviewProof: Hashable, Sendable, Equatable, Codable {
    public var parsesOpenGraph: Bool
    public var cacheOutsideVault: Bool
    public var noFetchOnType: Bool
    public var indexInsideVault: Bool

    public init(
        parsesOpenGraph: Bool,
        cacheOutsideVault: Bool,
        noFetchOnType: Bool,
        indexInsideVault: Bool
    ) {
        self.parsesOpenGraph = parsesOpenGraph
        self.cacheOutsideVault = cacheOutsideVault
        self.noFetchOnType = noFetchOnType
        self.indexInsideVault = indexInsideVault
    }

    public static func evaluate(
        parsedTitle: String?,
        expectedTitle: String,
        cachePath: String,
        vaultRoot: String,
        fetchCountAfterOpen: Int,
        fetchCountAfterTypingSave: Int,
        indexInsideVault: Bool
    ) -> LinkPreviewProof {
        LinkPreviewProof(
            parsesOpenGraph: (parsedTitle ?? "") == expectedTitle && !expectedTitle.isEmpty,
            cacheOutsideVault: pathIsOutsideVault(cachePath, vaultRoot: vaultRoot),
            noFetchOnType: fetchCountAfterOpen > 0
                && fetchCountAfterTypingSave == fetchCountAfterOpen,
            indexInsideVault: indexInsideVault
        )
    }

    public static func pathIsOutsideVault(_ path: String, vaultRoot: String) -> Bool {
        let cache = (path as NSString).standardizingPath
        let vault = (vaultRoot as NSString).standardizingPath
        guard !cache.isEmpty, !vault.isEmpty else { return false }
        if cache.hasPrefix(vault + "/") { return false }
        if cache == vault { return false }
        return true
    }
}

/// Contract notes so XCTest / DevHarness never import SwiftUI or URLSession.
public enum LinkPreviewNotes: Sendable {
    public static let parsesOpenGraph = true
    public static let cacheOutsideVault = true
    public static let noFetchOnType = true
    public static let cacheOnlyNotYAML = true
    public static let httpOnly = true
    public static let maxBytes = 1_048_576
    public static let fetchProtocol = "LinkPreviewServing.preview"
    public static let linuxUsesFakes = true
}
