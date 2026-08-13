import Foundation

/// Serialize `LociDocument` / BlockAST back to Loci MD (stable, round-trip friendly).
public struct MarkdownSerializer: Sendable {
    public init() {}

    public func serialize(_ document: LociDocument) -> String {
        var parts: [String] = []
        if let matter = document.frontMatter {
            parts.append("---")
            parts.append(FrontMatterCodec.encode(matter))
            parts.append("---")
            parts.append("")
        }
        let body = serializeBlocks(document.blocks)
        if !body.isEmpty {
            parts.append(body)
        }
        var result = parts.joined(separator: "\n")
        if !result.hasSuffix("\n") {
            result += "\n"
        }
        return result
    }

    public func serializeBlocks(_ blocks: [BlockNode]) -> String {
        blocks.map { serializeBlock($0) }.joined(separator: "\n\n")
    }

    private func serializeBlock(_ block: BlockNode) -> String {
        switch block {
        case .paragraph(let inlines):
            return serializeInlines(inlines)
        case .heading(let level, let inlines):
            let marks = String(repeating: "#", count: min(max(level, 1), 4))
            let text = serializeInlines(inlines)
            return text.isEmpty ? marks : "\(marks) \(text)"
        case .bulletList(let items):
            return items.map { serializeListItem($0, ordered: false, index: 0) }.joined(
                separator: "\n"
            )
        case .numberedList(let start, let items):
            return items.enumerated().map { offset, item in
                serializeListItem(item, ordered: true, index: start + offset)
            }.joined(separator: "\n")
        case .blockQuote(let children):
            let inner = serializeBlocks(children)
            if inner.isEmpty { return ">" }
            return inner.split(separator: "\n", omittingEmptySubsequences: false).map { line in
                line.isEmpty ? ">" : "> \(line)"
            }.joined(separator: "\n")
        case .codeBlock(let language, let code):
            let info = language ?? ""
            return "```\(info)\n\(code)\n```"
        case .queryEmbed(let queryID):
            // Fence language `query`; body is the saved-query slug only (no result rows).
            return "```query\n\(queryID)\n```"
        case .image(let alt, let url, let title):
            return serializeImage(alt: alt, url: url, title: title)
        case .thematicBreak:
            return "---"
        }
    }

    private func serializeListItem(_ item: ListItem, ordered: Bool, index: Int) -> String {
        let marker: String
        if ordered {
            marker = "\(index)."
        } else {
            marker = "-"
        }
        var prefix = "\(marker) "
        if let checked = item.checked {
            prefix += checked ? "[x] " : "[ ] "
        }
        let body = serializeInlines(item.inlines)
        let lines = body.split(separator: "\n", omittingEmptySubsequences: false)
        guard let first = lines.first else { return prefix.trimmingCharacters(in: .whitespaces) }
        var out = "\(prefix)\(first)"
        for cont in lines.dropFirst() {
            out += "\n  \(cont)"
        }
        return out
    }

    func serializeInlines(_ inlines: [InlineNode]) -> String {
        inlines.map(serializeInline).joined()
    }

    private func serializeInline(_ node: InlineNode) -> String {
        switch node {
        case .text(let s):
            return s
        case .code(let s):
            let ticks = backtickFence(for: s)
            return "\(ticks)\(s)\(ticks)"
        case .emphasis(let children):
            return "*\(serializeInlines(children))*"
        case .strong(let children):
            return "**\(serializeInlines(children))**"
        case .link(let text, let url, let title):
            let label = serializeInlines(text)
            if let title {
                return "[\(label)](\(url) \"\(title)\")"
            }
            return "[\(label)](\(url))"
        case .image(let alt, let url, let title):
            return serializeImage(alt: alt, url: url, title: title)
        case .wikiLink(let link):
            return link.markdown
        case .tag(let body):
            return TagSyntax.markdown(body)
        case .softBreak:
            return "\n"
        case .hardBreak:
            return "  \n"
        }
    }

    private func serializeImage(alt: String, url: String, title: String?) -> String {
        if let title {
            return "![\(alt)](\(url) \"\(title)\")"
        }
        return "![\(alt)](\(url))"
    }

    private func backtickFence(for code: String) -> String {
        var len = 1
        while code.contains(String(repeating: "`", count: len)) {
            len += 1
        }
        return String(repeating: "`", count: len)
    }
}
