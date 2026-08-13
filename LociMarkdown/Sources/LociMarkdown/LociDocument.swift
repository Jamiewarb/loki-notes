import Foundation

/// Parsed Loci markdown document: optional YAML frontmatter + block body.
public struct LociDocument: Hashable, Sendable, Equatable {
    public var frontMatter: FrontMatter?
    public var blocks: [BlockNode]

    public init(frontMatter: FrontMatter? = nil, blocks: [BlockNode] = []) {
        self.frontMatter = frontMatter
        self.blocks = blocks
    }
}
