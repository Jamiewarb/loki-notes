import Foundation

/// Parse inline Loci MD: text, code, emphasis, links, images, wiki-links, tags.
enum InlineParser {
    static func parse(_ text: String) -> [InlineNode] {
        var nodes: [InlineNode] = []
        var i = text.startIndex
        var buffer = ""

        func flush() {
            if !buffer.isEmpty {
                nodes.append(.text(buffer))
                buffer = ""
            }
        }

        while i < text.endIndex {
            let ch = text[i]

            // Soft / hard breaks are handled at block level; treat remaining newlines as soft breaks.
            if ch == "\n" {
                flush()
                nodes.append(.softBreak)
                i = text.index(after: i)
                continue
            }

            // Wiki-link
            if ch == "[", peek(text, i, offset: 1) == "[" {
                flush()
                if let (link, end) = parseWikiLink(text, from: i) {
                    nodes.append(.wikiLink(link))
                    i = end
                    continue
                }
            }

            // Image ![alt](url)
            if ch == "!", peek(text, i, offset: 1) == "[" {
                flush()
                if let (alt, url, title, end) = parseImage(text, from: i) {
                    nodes.append(.image(alt: alt, url: url, title: title))
                    i = end
                    continue
                }
            }

            // Link [text](url)
            if ch == "[" {
                flush()
                if let (label, url, title, end) = parseLink(text, from: i) {
                    nodes.append(.link(text: parse(label), url: url, title: title))
                    i = end
                    continue
                }
            }

            // Inline code
            if ch == "`" {
                flush()
                if let (code, end) = parseBackticks(text, from: i) {
                    nodes.append(.code(code))
                    i = end
                    continue
                }
            }

            // Strong **...** or __...__
            if (ch == "*" && peek(text, i, offset: 1) == "*")
                || (ch == "_" && peek(text, i, offset: 1) == "_")
            {
                flush()
                let marker = String(ch)
                if let (inner, end) = parseDelimited(text, from: i, delimiter: marker + marker) {
                    nodes.append(.strong(parse(inner)))
                    i = end
                    continue
                }
            }

            // Emphasis *...* or _..._
            if ch == "*" || ch == "_" {
                flush()
                if let (inner, end) = parseDelimited(text, from: i, delimiter: String(ch)) {
                    nodes.append(.emphasis(parse(inner)))
                    i = end
                    continue
                }
            }

            // Tag #foo
            if ch == "#", isTagStart(text, at: i) {
                flush()
                let (tag, end) = parseTag(text, from: i)
                nodes.append(.tag(tag))
                i = end
                continue
            }

            buffer.append(ch)
            i = text.index(after: i)
        }

        flush()
        return mergeAdjacentText(nodes)
    }

    // MARK: - Parsers

    private static func parseWikiLink(_ text: String, from start: String.Index) -> (WikiLink, String.Index)? {
        guard peek(text, start, offset: 0) == "[", peek(text, start, offset: 1) == "[" else {
            return nil
        }
        var i = text.index(start, offsetBy: 2)
        var depth = 0
        while i < text.endIndex {
            if text[i] == "[", peek(text, i, offset: 1) == "[" {
                depth += 1
                i = text.index(i, offsetBy: 2)
                continue
            }
            if text[i] == "]", peek(text, i, offset: 1) == "]" {
                if depth == 0 {
                    let inner = String(text[text.index(start, offsetBy: 2)..<i])
                    guard let link = WikiLink.parse(inner) else { return nil }
                    let end = text.index(i, offsetBy: 2)
                    return (link, end)
                }
                depth -= 1
                i = text.index(i, offsetBy: 2)
                continue
            }
            i = text.index(after: i)
        }
        return nil
    }

    private static func parseImage(_ text: String, from start: String.Index) -> (
        String, String, String?, String.Index
    )? {
        guard text[start] == "!" else { return nil }
        let bracketStart = text.index(after: start)
        guard bracketStart < text.endIndex, text[bracketStart] == "[" else { return nil }
        guard let (alt, afterAlt) = parseBracketContent(text, from: bracketStart) else { return nil }
        guard afterAlt < text.endIndex, text[afterAlt] == "(" else { return nil }
        guard let (url, title, end) = parseParenDestination(text, from: afterAlt) else { return nil }
        return (alt, url, title, end)
    }

    private static func parseLink(_ text: String, from start: String.Index) -> (
        String, String, String?, String.Index
    )? {
        guard let (label, afterLabel) = parseBracketContent(text, from: start) else { return nil }
        guard afterLabel < text.endIndex, text[afterLabel] == "(" else { return nil }
        guard let (url, title, end) = parseParenDestination(text, from: afterLabel) else { return nil }
        return (label, url, title, end)
    }

    private static func parseBracketContent(_ text: String, from start: String.Index) -> (
        String, String.Index
    )? {
        guard start < text.endIndex, text[start] == "[" else { return nil }
        var i = text.index(after: start)
        var depth = 0
        while i < text.endIndex {
            let ch = text[i]
            if ch == "\\" {
                i = text.index(after: i)
                if i < text.endIndex { i = text.index(after: i) }
                continue
            }
            if ch == "[" {
                depth += 1
            } else if ch == "]" {
                if depth == 0 {
                    let content = String(text[text.index(after: start)..<i])
                    return (content, text.index(after: i))
                }
                depth -= 1
            }
            i = text.index(after: i)
        }
        return nil
    }

    private static func parseParenDestination(_ text: String, from start: String.Index) -> (
        String, String?, String.Index
    )? {
        guard start < text.endIndex, text[start] == "(" else { return nil }
        var i = text.index(after: start)
        while i < text.endIndex, text[i].isWhitespace { i = text.index(after: i) }
        var url = ""
        if i < text.endIndex, text[i] == "<" {
            i = text.index(after: i)
            while i < text.endIndex, text[i] != ">" {
                url.append(text[i])
                i = text.index(after: i)
            }
            if i < text.endIndex { i = text.index(after: i) }
        } else {
            while i < text.endIndex, text[i] != ")", !text[i].isWhitespace {
                url.append(text[i])
                i = text.index(after: i)
            }
        }
        while i < text.endIndex, text[i].isWhitespace { i = text.index(after: i) }
        var title: String?
        if i < text.endIndex, text[i] == "\"" || text[i] == "'" {
            let quote = text[i]
            i = text.index(after: i)
            var t = ""
            while i < text.endIndex, text[i] != quote {
                t.append(text[i])
                i = text.index(after: i)
            }
            if i < text.endIndex { i = text.index(after: i) }
            title = t
        }
        while i < text.endIndex, text[i].isWhitespace { i = text.index(after: i) }
        guard i < text.endIndex, text[i] == ")" else { return nil }
        return (url, title, text.index(after: i))
    }

    private static func parseBackticks(_ text: String, from start: String.Index) -> (
        String, String.Index
    )? {
        var i = start
        var ticks = 0
        while i < text.endIndex, text[i] == "`" {
            ticks += 1
            i = text.index(after: i)
        }
        guard ticks > 0 else { return nil }
        let marker = String(repeating: "`", count: ticks)
        var j = i
        while j < text.endIndex {
            if text[j...].hasPrefix(marker) {
                let after = text.index(j, offsetBy: ticks)
                // Require closing not followed by more backticks (CommonMark-ish).
                if after < text.endIndex, text[after] == "`" {
                    j = text.index(after: j)
                    continue
                }
                let code = String(text[i..<j])
                return (code, after)
            }
            j = text.index(after: j)
        }
        return nil
    }

    private static func parseDelimited(_ text: String, from start: String.Index, delimiter: String)
        -> (String, String.Index)?
    {
        guard text[start...].hasPrefix(delimiter) else { return nil }
        let innerStart = text.index(start, offsetBy: delimiter.count)
        var i = innerStart
        while i < text.endIndex {
            if text[i...].hasPrefix(delimiter) {
                // Avoid matching empty or whitespace-only for single markers adjacent to punctuation loosely.
                let inner = String(text[innerStart..<i])
                if !inner.isEmpty {
                    return (inner, text.index(i, offsetBy: delimiter.count))
                }
            }
            i = text.index(after: i)
        }
        return nil
    }

    private static func isTagStart(_ text: String, at i: String.Index) -> Bool {
        // `#tag` — `#` at start or after whitespace/punctuation, body starts with letter.
        let prevOK: Bool
        if i == text.startIndex {
            prevOK = true
        } else {
            let prev = text[text.index(before: i)]
            prevOK = prev.isWhitespace || "([{\"'".contains(prev)
        }
        guard prevOK else { return false }
        let next = text.index(after: i)
        guard next < text.endIndex else { return false }
        return text[next].isLetter
    }

    private static func parseTag(_ text: String, from start: String.Index) -> (String, String.Index) {
        var i = text.index(after: start)  // skip #
        var body = ""
        while i < text.endIndex {
            let ch = text[i]
            if ch.isLetter || ch.isNumber || ch == "_" || ch == "-" || ch == "/" {
                body.append(ch)
                i = text.index(after: i)
            } else {
                break
            }
        }
        return (body, i)
    }

    private static func peek(_ text: String, _ i: String.Index, offset: Int) -> Character? {
        guard let idx = text.index(i, offsetBy: offset, limitedBy: text.endIndex), idx < text.endIndex
        else {
            return nil
        }
        return text[idx]
    }

    private static func mergeAdjacentText(_ nodes: [InlineNode]) -> [InlineNode] {
        var out: [InlineNode] = []
        for node in nodes {
            if case .text(let s) = node, case .text(let prev)? = out.last {
                out[out.count - 1] = .text(prev + s)
            } else {
                out.append(node)
            }
        }
        return out
    }
}
