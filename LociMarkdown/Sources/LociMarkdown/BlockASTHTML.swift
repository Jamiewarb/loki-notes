import Foundation

/// Lightweight HTML preview of BlockAST for DevHarness / demos (not a full renderer).
public enum BlockASTHTML: Sendable {
    public static func render(_ blocks: [BlockNode]) -> String {
        let body = blocks.map(renderBlock).joined(separator: "\n")
        return """
            <article class="loci-ast" data-harness="block-ast-html">
            \(body)
            </article>
            """
    }

    private static func renderBlock(_ block: BlockNode) -> String {
        switch block {
        case .paragraph(let inlines):
            return "<p>\(escape(inlineText(inlines)))</p>"
        case .heading(let level, let inlines):
            let clamped = min(max(level, 1), 4)
            return "<h\(clamped)>\(escape(inlineText(inlines)))</h\(clamped)>"
        case .bulletList(let items):
            let lis = items.map(renderListItem).joined(separator: "\n")
            return "<ul>\n\(lis)\n</ul>"
        case .numberedList(_, let items):
            let lis = items.map(renderListItem).joined(separator: "\n")
            return "<ol>\n\(lis)\n</ol>"
        case .blockQuote(let children):
            let inner = children.map(renderBlock).joined(separator: "\n")
            return "<blockquote>\n\(inner)\n</blockquote>"
        case .codeBlock(let language, let code):
            let lang = language?.lowercased()
            if lang == "mermaid" {
                return """
                    <div class="mermaid-block" data-harness="mermaid-stub" data-language="mermaid">
                    <pre class="mermaid-source"><code class="language-mermaid">\(escape(code))</code></pre>
                    <p class="mermaid-hint">Mermaid diagram (WebKit render on Apple; harness stub on Linux)</p>
                    </div>
                    """
            }
            let langClass = language.map { " class=\"language-\(escape($0))\"" } ?? ""
            let highlighted = CodeSyntaxHighlight.highlight(code, language: language)
            return "<pre data-harness=\"code-highlight\"><code\(langClass)>\(highlighted)</code></pre>"
        case .queryEmbed(let queryID):
            return
                "<div class=\"query-embed\" data-query-id=\"\(escape(queryID))\" data-harness=\"query-embed\"><span class=\"query-embed-label\">/query</span> <code>\(escape(queryID))</code> <span class=\"query-embed-hint\">live results</span></div>"
        case .table(let headers, let alignments, let rows):
            return renderTable(headers: headers, alignments: alignments, rows: rows)
        case .toggle(let summary, let children, let collapsed):
            let open = collapsed ? "" : " open"
            let inner = children.map(renderBlock).joined(separator: "\n")
            return
                "<details class=\"loci-toggle\" data-harness=\"toggle\"\(open)><summary>\(escape(inlineText(summary)))</summary>\n\(inner)\n</details>"
        case .callout(let kind, let title, let children):
            let inner = children.map(renderBlock).joined(separator: "\n")
            let titleHTML = escape(inlineText(title))
            return
                "<aside class=\"loci-callout callout-\(escape(kind.rawValue))\" data-harness=\"callout\" data-callout=\"\(escape(kind.rawValue))\"><p class=\"callout-title\">\(titleHTML)</p>\n\(inner)\n</aside>"
        case .image(let alt, let url, _):
            return "<p><img src=\"\(escape(url))\" alt=\"\(escape(alt))\" /></p>"
        case .thematicBreak:
            return "<hr />"
        }
    }

    private static func renderTable(
        headers: [String],
        alignments: [TableAlignment],
        rows: [[String]]
    ) -> String {
        func alignAttr(_ index: Int) -> String {
            guard alignments.indices.contains(index) else { return "" }
            switch alignments[index] {
            case .left: return " align=\"left\""
            case .center: return " align=\"center\""
            case .right: return " align=\"right\""
            case .none: return ""
            }
        }
        let ths = headers.enumerated().map { i, h in
            "<th\(alignAttr(i))>\(escape(h))</th>"
        }.joined()
        let body = rows.map { row in
            let cells = row.enumerated().map { i, cell in
                "<td\(alignAttr(i))>\(escape(cell))</td>"
            }.joined()
            return "<tr>\(cells)</tr>"
        }.joined(separator: "\n")
        return
            "<table class=\"loci-table\" data-harness=\"table\">\n<thead><tr>\(ths)</tr></thead>\n<tbody>\n\(body)\n</tbody>\n</table>"
    }

    private static func renderListItem(_ item: ListItem) -> String {
        let text = escape(inlineText(item.inlines))
        if let checked = item.checked {
            let mark = checked ? "☑" : "☐"
            return "<li data-task=\"\(checked ? "done" : "open")\">\(mark) \(text)</li>"
        }
        return "<li>\(text)</li>"
    }

    private static func inlineText(_ inlines: [InlineNode]) -> String {
        inlines.map(renderInline).joined()
    }

    private static func renderInline(_ node: InlineNode) -> String {
        switch node {
        case .text(let s):
            return escape(s)
        case .code(let s):
            return "<code>\(escape(s))</code>"
        case .emphasis(let children):
            return "<em>\(inlineText(children))</em>"
        case .strong(let children):
            return "<strong>\(inlineText(children))</strong>"
        case .link(let text, let url, _):
            return "<a href=\"\(escape(url))\">\(inlineText(text))</a>"
        case .image(let alt, let url, _):
            return "<img src=\"\(escape(url))\" alt=\"\(escape(alt))\" />"
        case .wikiLink(let link):
            // Harness styles `.wiki-link`; broken class applied by demo when unresolved.
            return
                "<span class=\"wiki-link\" data-wiki-target=\"\(escape(link.target))\">\(escape(link.displayText))</span>"
        case .tag(let name):
            return "<span class=\"tag\">#\(escape(name))</span>"
        case .softBreak, .hardBreak:
            return " "
        }
    }

    /// Render with explicit broken/resolved classes from a resolve map (target → exists).
    public static func render(_ blocks: [BlockNode], resolvedTargets: Set<String>) -> String {
        let body = blocks.map { renderBlockStyled($0, resolved: resolvedTargets) }.joined(
            separator: "\n"
        )
        return """
            <article class="loci-ast" data-harness="block-ast-html">
            \(body)
            </article>
            """
    }

    private static func renderBlockStyled(_ block: BlockNode, resolved: Set<String>) -> String {
        switch block {
        case .paragraph(let inlines):
            return "<p>\(styledInlines(inlines, resolved: resolved))</p>"
        case .heading(let level, let inlines):
            let clamped = min(max(level, 1), 4)
            return "<h\(clamped)>\(styledInlines(inlines, resolved: resolved))</h\(clamped)>"
        default:
            return renderBlock(block)
        }
    }

    private static func styledInlines(_ inlines: [InlineNode], resolved: Set<String>) -> String {
        inlines.map { node -> String in
            if case .wikiLink(let link) = node {
                let ok =
                    resolved.contains(link.target)
                    || resolved.contains(link.target.lowercased())
                let cls = ok ? "wiki-link is-resolved" : "wiki-link is-broken"
                return
                    "<span class=\"\(cls)\" data-wiki-target=\"\(escape(link.target))\">\(escape(link.displayText))</span>"
            }
            return renderInline(node)
        }.joined()
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
