import Foundation

/// Block-level AST for Loci MD (CommonMark subset + wiki-links / tags / tasks).
public enum BlockNode: Hashable, Sendable, Equatable {
    case paragraph([InlineNode])
    /// Heading levels 1…4 (Loci editor budget).
    case heading(level: Int, inlines: [InlineNode])
    case bulletList([ListItem])
    case numberedList(start: Int, items: [ListItem])
    case blockQuote([BlockNode])
    case codeBlock(language: String?, code: String)
    /// Standalone image block (serialized as its own paragraph-like line).
    case image(alt: String, url: String, title: String?)
    /// Live query embed — stores only the saved-query slug; results are derived at render time (PR23).
    case queryEmbed(queryID: String)
    case thematicBreak
}
