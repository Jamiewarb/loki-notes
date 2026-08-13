import Foundation
import LociCore
import LociMarkdown

/// Extracted projection of one vault markdown file for writers.
struct IndexedDocument: Sendable {
    var meta: LociObjectMeta
    var bodyText: String
    var wikiLinks: [WikiLink]
    var bodyTags: [String]
}

/// Walks BlockAST + frontmatter into indexable fields.
enum ObjectIndexer {
    static func extract(relativePath: String, markdown: String) throws -> IndexedDocument? {
        let doc = try MarkdownParser().parse(markdown)
        guard let fm = doc.frontMatter else {
            return nil
        }
        let meta = fm.toMeta(relativePath: relativePath)
        let walk = ASTWalker.walk(doc.blocks)
        var tags = Set(fm.tags.map { $0.lowercased() })
        for t in walk.tags {
            tags.insert(t.lowercased())
        }
        return IndexedDocument(
            meta: LociObjectMeta(
                id: meta.id,
                typeID: meta.typeID,
                title: meta.title,
                created: meta.created,
                updated: meta.updated,
                relativePath: relativePath,
                tags: Array(tags).sorted(),
                properties: meta.properties
            ),
            bodyText: walk.plainText,
            wikiLinks: walk.wikiLinks,
            bodyTags: walk.tags
        )
    }
}

private struct ASTWalker {
    var plainText: String = ""
    var wikiLinks: [WikiLink] = []
    var tags: [String] = []

    static func walk(_ blocks: [BlockNode]) -> ASTWalker {
        var walker = ASTWalker()
        for block in blocks {
            walker.visit(block)
        }
        return walker
    }

    mutating func visit(_ block: BlockNode) {
        switch block {
        case .paragraph(let inlines):
            visitInlines(inlines)
            plainText.append("\n")
        case .heading(_, let inlines):
            visitInlines(inlines)
            plainText.append("\n")
        case .bulletList(let items), .numberedList(_, let items):
            for item in items {
                visitInlines(item.inlines)
                plainText.append("\n")
            }
        case .blockQuote(let nested):
            for b in nested {
                visit(b)
            }
        case .codeBlock(_, let code):
            plainText.append(code)
            plainText.append("\n")
        case .image(let alt, _, _):
            plainText.append(alt)
            plainText.append("\n")
        case .thematicBreak:
            break
        }
    }

    mutating func visitInlines(_ inlines: [InlineNode]) {
        for node in inlines {
            switch node {
            case .text(let s):
                plainText.append(s)
            case .code(let s):
                plainText.append(s)
            case .emphasis(let inner), .strong(let inner):
                visitInlines(inner)
            case .link(let text, _, _):
                visitInlines(text)
            case .image(let alt, _, _):
                plainText.append(alt)
            case .wikiLink(let link):
                wikiLinks.append(link)
                plainText.append(link.label ?? link.target)
            case .tag(let name):
                tags.append(name)
                plainText.append("#\(name)")
            case .softBreak, .hardBreak:
                plainText.append(" ")
            }
        }
    }
}
