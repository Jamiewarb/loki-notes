import Foundation

/// Inline nodes inside paragraphs, headings, and list items.
public enum InlineNode: Hashable, Sendable, Equatable {
    case text(String)
    case code(String)
    case emphasis([InlineNode])
    case strong([InlineNode])
    case link(text: [InlineNode], url: String, title: String?)
    case image(alt: String, url: String, title: String?)
    case wikiLink(WikiLink)
    case tag(String)
    case softBreak
    case hardBreak
}
