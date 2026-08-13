import Foundation

/// Parse / serialize failures for Loci MD (kept in-package; Indexer maps as needed).
public enum MarkdownError: Error, Sendable, Equatable {
    case invalidFrontMatter(String)
    case missingRequiredField(String)
    case invalidObjectID(String)
    case unsupportedHeadingLevel(Int)
    case unbalancedFence
    case unexpectedEOF
}
