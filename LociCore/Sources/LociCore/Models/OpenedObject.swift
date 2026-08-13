import Foundation

/// Result of `ObjectServing.open` — metadata plus body markdown (no YAML frontmatter fence).
public struct OpenedObject: Hashable, Sendable, Codable, Equatable {
    public var meta: LociObjectMeta
    /// Markdown body only (paragraphs, headings, …). Frontmatter is owned by `meta`.
    public var bodyMarkdown: String

    public init(meta: LociObjectMeta, bodyMarkdown: String) {
        self.meta = meta
        self.bodyMarkdown = bodyMarkdown
    }
}
