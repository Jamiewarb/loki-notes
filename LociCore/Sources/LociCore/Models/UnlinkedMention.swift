import Foundation

/// One unlinked title mention: another object’s body contains this object’s title
/// as plain text, and does not already wiki-link to it.
///
/// Derived UI only — never written into daily.md or the target object.
public struct UnlinkedMention: Hashable, Sendable, Equatable, Codable {
    public var source: LociObjectMeta
    /// Short excerpt around the first unlinked title occurrence.
    public var snippet: String

    public init(source: LociObjectMeta, snippet: String) {
        self.source = source
        self.snippet = snippet
    }
}
