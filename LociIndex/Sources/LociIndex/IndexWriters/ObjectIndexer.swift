import Foundation
import LociCore
import LociMarkdown

/// Extracted projection of one vault markdown file for writers.
struct IndexedDocument: Sendable {
    var meta: LociObjectMeta
    var bodyText: String
    var wikiLinks: [WikiLink]
    var bodyTags: [String]
    var tasks: [ExtractedTask]
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
        var tags = Set(fm.tags.map { TagNormalization.normalize($0) }.filter { !$0.isEmpty })
        for t in walk.tags {
            let n = TagNormalization.normalize(t)
            if !n.isEmpty { tags.insert(n) }
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
            wikiLinks: ObjectSelectLinks.merge(
                body: walk.wikiLinks,
                properties: meta.properties
            ),
            bodyTags: walk.tags,
            tasks: walk.tasks
        )
    }
}

private struct ASTWalker {
    var plainText: String = ""
    var wikiLinks: [WikiLink] = []
    var tags: [String] = []
    var tasks: [ExtractedTask] = []
    private var blockIndex: Int = 0
    private var captureTasks = true

    static func walk(_ blocks: [BlockNode]) -> ASTWalker {
        var walker = ASTWalker()
        for (i, block) in blocks.enumerated() {
            walker.blockIndex = i
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
            for (itemIndex, item) in items.enumerated() {
                if captureTasks, let checked = item.checked {
                    let text = inlinePlainText(item.inlines)
                    tasks.append(
                        ExtractedTask(
                            blockIndex: blockIndex,
                            itemIndex: itemIndex,
                            text: text,
                            isCompleted: checked
                        )
                    )
                }
                visitInlines(item.inlines)
                plainText.append("\n")
            }
        case .blockQuote(let nested):
            let was = captureTasks
            captureTasks = false
            for b in nested {
                visit(b)
            }
            captureTasks = was
        case .codeBlock(_, let code):
            plainText.append(code)
            plainText.append("\n")
        case .queryEmbed(let queryID):
            // Slug only — do not invent result titles into the indexed body.
            plainText.append(queryID)
            plainText.append("\n")
        case .table(let headers, _, let rows):
            plainText.append(headers.joined(separator: " "))
            plainText.append("\n")
            for row in rows {
                plainText.append(row.joined(separator: " "))
                plainText.append("\n")
            }
        case .toggle(let summary, let nested, _):
            visitInlines(summary)
            plainText.append("\n")
            for b in nested {
                visit(b)
            }
        case .callout(_, let title, let nested):
            visitInlines(title)
            plainText.append("\n")
            for b in nested {
                visit(b)
            }
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

    private func inlinePlainText(_ inlines: [InlineNode]) -> String {
        var s = ""
        func walk(_ nodes: [InlineNode]) {
            for node in nodes {
                switch node {
                case .text(let t), .code(let t):
                    s.append(t)
                case .emphasis(let inner), .strong(let inner), .link(let inner, _, _):
                    walk(inner)
                case .image(let alt, _, _):
                    s.append(alt)
                case .wikiLink(let link):
                    s.append(link.label ?? link.target)
                case .tag(let name):
                    s.append("#\(name)")
                case .softBreak, .hardBreak:
                    s.append(" ")
                }
            }
        }
        walk(inlines)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
