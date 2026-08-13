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
            let lang = language.map { " class=\"language-\(escape($0))\"" } ?? ""
            return "<pre><code\(lang)>\(escape(code))</code></pre>"
        case .image(let alt, let url, _):
            return "<p><img src=\"\(escape(url))\" alt=\"\(escape(alt))\" /></p>"
        case .thematicBreak:
            return "<hr />"
        }
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
        MarkdownSerializer().serializeInlines(inlines)
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
