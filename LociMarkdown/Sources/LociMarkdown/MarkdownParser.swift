import Foundation
import LociCore

/// Parse Loci MD text into `LociDocument` (frontmatter + BlockAST).
public struct MarkdownParser: Sendable {
    public init() {}

    public func parse(_ markdown: String) throws -> LociDocument {
        let normalized = markdown.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(
            of: "\r",
            with: "\n"
        )
        let (matter, body) = try Self.splitFrontMatter(normalized)
        let frontMatter: FrontMatter?
        if let matter {
            frontMatter = try FrontMatterCodec.decode(matter)
        } else {
            frontMatter = nil
        }
        let blocks = try parseBlocks(body)
        return LociDocument(frontMatter: frontMatter, blocks: blocks)
    }

    // MARK: - Front matter

    static func splitFrontMatter(_ text: String) throws -> (String?, String) {
        let trimmedStart = text.drop(while: { $0 == "\n" })
        guard trimmedStart.hasPrefix("---") else {
            return (nil, text)
        }
        // Opening fence must be on its own line
        let afterOpen: Substring
        if trimmedStart.hasPrefix("---\n") {
            afterOpen = trimmedStart.dropFirst(4)
        } else if trimmedStart == "---" {
            throw MarkdownError.unexpectedEOF
        } else {
            // `---` not followed by newline — not frontmatter
            return (nil, text)
        }

        if let closeRange = afterOpen.range(of: "\n---") {
            let yaml = String(afterOpen[..<closeRange.lowerBound])
            var rest = afterOpen[closeRange.upperBound...]
            // Closing fence is `\n---`; optional body follows after a newline.
            if rest.hasPrefix("\n") {
                rest = rest.dropFirst()
            }
            return (yaml, String(rest))
        }

        // Closing fence at EOF without leading newline already consumed: look for \n--- at end
        if afterOpen.hasSuffix("\n---") {
            let yaml = String(afterOpen.dropLast(4))
            return (yaml, "")
        }
        if afterOpen == "---" {
            return ("", "")
        }

        throw MarkdownError.invalidFrontMatter("missing closing --- fence")
    }

    // MARK: - Blocks

    private func parseBlocks(_ body: String) throws -> [BlockNode] {
        let lines = body.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var index = 0
        var blocks: [BlockNode] = []
        while index < lines.count {
            // Skip blank lines between blocks
            if lines[index].trimmingCharacters(in: .whitespaces).isEmpty {
                index += 1
                continue
            }
            if let (block, next) = try parseBlock(lines: lines, at: index) {
                blocks.append(block)
                index = next
            } else {
                index += 1
            }
        }
        return blocks
    }

    private func parseBlock(lines: [String], at index: Int) throws -> (BlockNode, Int)? {
        let line = lines[index]
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Thematic break
        if isThematicBreak(trimmed) {
            return (.thematicBreak, index + 1)
        }

        // HTML <details> toggle (PR29)
        if trimmed.lowercased().hasPrefix("<details") {
            return try parseToggle(lines: lines, at: index)
        }

        // Fenced code
        if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
            return try parseCodeFence(lines: lines, at: index)
        }

        // Heading
        if let heading = parseHeading(trimmed) {
            return (heading, index + 1)
        }

        // GFM table (PR29)
        if let table = parseTable(lines: lines, at: index) {
            return table
        }

        // Block quote or callout (PR29)
        if trimmed.hasPrefix(">") {
            return try parseBlockQuoteOrCallout(lines: lines, at: index)
        }

        // List (bullet / task / numbered)
        if let list = try parseList(lines: lines, at: index) {
            return list
        }

        // Standalone image line
        if let image = parseStandaloneImage(trimmed) {
            return (image, index + 1)
        }

        // Paragraph (collect until blank / other block)
        return parseParagraph(lines: lines, at: index)
    }

    private func parseHeading(_ trimmed: String) -> BlockNode? {
        var level = 0
        var i = trimmed.startIndex
        while i < trimmed.endIndex, trimmed[i] == "#", level < 6 {
            level += 1
            i = trimmed.index(after: i)
        }
        guard level >= 1, level <= 4 else { return nil }
        guard i < trimmed.endIndex, trimmed[i] == " " || trimmed[i] == "\t" else {
            // Allow `#Title` without space for friendliness? CommonMark requires space.
            if i == trimmed.endIndex { return .heading(level: level, inlines: []) }
            return nil
        }
        let text = trimmed[i...].trimmingCharacters(in: .whitespaces)
        return .heading(level: level, inlines: InlineParser.parse(text))
    }

    private func parseCodeFence(lines: [String], at index: Int) throws -> (BlockNode, Int) {
        let open = lines[index].trimmingCharacters(in: .whitespaces)
        let fenceChar = open.first!
        var fenceLen = 0
        for ch in open {
            if ch == fenceChar { fenceLen += 1 } else { break }
        }
        let info = String(open.dropFirst(fenceLen)).trimmingCharacters(in: .whitespaces)
        let language = info.isEmpty ? nil : String(info.split(separator: " ").first ?? Substring(info))

        var codeLines: [String] = []
        var i = index + 1
        while i < lines.count {
            let t = lines[i].trimmingCharacters(in: .whitespaces)
            if t.hasPrefix(String(repeating: String(fenceChar), count: fenceLen))
                && t.drop(while: { $0 == fenceChar }).allSatisfy({ $0.isWhitespace })
            {
                let code = codeLines.joined(separator: "\n")
                if language?.lowercased() == "query" {
                    let slug = TypeSlug.normalize(
                        code.trimmingCharacters(in: .whitespacesAndNewlines)
                            .split(whereSeparator: { $0.isNewline }).first.map(String.init) ?? code
                    )
                    return (.queryEmbed(queryID: slug.isEmpty ? "query" : slug), i + 1)
                }
                return (.codeBlock(language: language, code: code), i + 1)
            }
            codeLines.append(lines[i])
            i += 1
        }
        throw MarkdownError.unbalancedFence
    }

    private func parseBlockQuoteOrCallout(lines: [String], at index: Int) throws -> (BlockNode, Int) {
        var quoteLines: [String] = []
        var i = index
        while i < lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix(">") {
                var rest = String(trimmed.dropFirst())
                if rest.hasPrefix(" ") { rest = String(rest.dropFirst()) }
                quoteLines.append(rest)
                i += 1
            } else if trimmed.isEmpty {
                // Blank ends quote unless next continues — keep simple: blank ends.
                break
            } else {
                break
            }
        }
        if let callout = try parseCallout(from: quoteLines) {
            return (callout, i)
        }
        let inner = try parseBlocks(quoteLines.joined(separator: "\n"))
        return (.blockQuote(inner.isEmpty ? [.paragraph([])] : inner), i)
    }

    /// `> [!note] Title` / `> [!WARNING]` callout convention (PR29).
    private func parseCallout(from quoteLines: [String]) throws -> BlockNode? {
        guard let first = quoteLines.first else { return nil }
        let trimmed = first.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("[!") else { return nil }
        guard let close = trimmed.firstIndex(of: "]") else { return nil }
        let kindRaw = String(trimmed[trimmed.index(trimmed.startIndex, offsetBy: 2)..<close])
        // Optional fold marker `-` after `]` (Obsidian) — ignored for callout (toggles use <details>).
        var after = String(trimmed[trimmed.index(after: close)...])
        if after.hasPrefix("-") {
            after = String(after.dropFirst())
        }
        after = after.trimmingCharacters(in: .whitespaces)
        let kind = CalloutKind.parse(kindRaw)
        let title: [InlineNode] =
            after.isEmpty ? [.text(kind.title)] : InlineParser.parse(after)
        let bodyLines = Array(quoteLines.dropFirst())
        let children = try parseBlocks(bodyLines.joined(separator: "\n"))
        return .callout(
            kind: kind,
            title: title,
            children: children.isEmpty ? [.paragraph([])] : children
        )
    }

    private func parseToggle(lines: [String], at index: Int) throws -> (BlockNode, Int) {
        var i = index + 1
        var summaryInlines: [InlineNode] = [.text("Toggle")]
        var bodyLines: [String] = []
        var sawClose = false
        while i < lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            let lower = trimmed.lowercased()
            if lower.hasPrefix("<summary>") {
                var text = String(trimmed.dropFirst("<summary>".count))
                if let end = text.range(of: "</summary>", options: .caseInsensitive) {
                    text = String(text[..<end.lowerBound])
                    i += 1
                } else {
                    // Multi-line summary until </summary>
                    i += 1
                    while i < lines.count {
                        let t = lines[i]
                        if let end = t.range(of: "</summary>", options: .caseInsensitive) {
                            text += String(t[..<end.lowerBound])
                            i += 1
                            break
                        }
                        text += "\n" + t
                        i += 1
                    }
                }
                summaryInlines = InlineParser.parse(text.trimmingCharacters(in: .whitespacesAndNewlines))
                continue
            }
            if lower == "</details>" || lower.hasPrefix("</details>") {
                sawClose = true
                i += 1
                break
            }
            bodyLines.append(lines[i])
            i += 1
        }
        if !sawClose {
            throw MarkdownError.unbalancedFence
        }
        // Drop leading/trailing blank lines in body
        while bodyLines.first?.trimmingCharacters(in: .whitespaces).isEmpty == true {
            bodyLines.removeFirst()
        }
        while bodyLines.last?.trimmingCharacters(in: .whitespaces).isEmpty == true {
            bodyLines.removeLast()
        }
        let children = try parseBlocks(bodyLines.joined(separator: "\n"))
        return (
            .toggle(
                summary: summaryInlines.isEmpty ? [.text("Toggle")] : summaryInlines,
                children: children.isEmpty ? [.paragraph([])] : children,
                collapsed: true
            ),
            i
        )
    }

    private func parseTable(lines: [String], at index: Int) -> (BlockNode, Int)? {
        guard index + 1 < lines.count else { return nil }
        let headerLine = lines[index].trimmingCharacters(in: .whitespaces)
        let sepLine = lines[index + 1].trimmingCharacters(in: .whitespaces)
        guard headerLine.contains("|"), sepLine.contains("|") else { return nil }
        guard let headers = splitTableRow(headerLine), headers.count >= 1 else { return nil }
        guard let sepCells = splitTableRow(sepLine), sepCells.count >= 1 else { return nil }
        let alignments = sepCells.map { TableAlignment.parseSeparatorCell($0) ?? .none }
        // Require at least one real separator cell
        guard sepCells.contains(where: { TableAlignment.parseSeparatorCell($0) != nil }) else {
            return nil
        }

        var rows: [[String]] = []
        var i = index + 2
        while i < lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { break }
            if !trimmed.contains("|") { break }
            if isThematicBreak(trimmed) { break }
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") { break }
            if trimmed.hasPrefix(">") { break }
            if parseHeading(trimmed) != nil { break }
            if matchListMarker(lines[i]) != nil { break }
            guard let cells = splitTableRow(trimmed) else { break }
            rows.append(cells)
            i += 1
        }

        let colCount = max(headers.count, alignments.count, rows.map(\.count).max() ?? 0)
        func pad(_ cells: [String], to count: Int) -> [String] {
            var next = cells
            while next.count < count { next.append("") }
            return Array(next.prefix(count))
        }
        var aligns = alignments
        while aligns.count < colCount { aligns.append(.none) }
        return (
            .table(
                headers: pad(headers, to: colCount),
                alignments: Array(aligns.prefix(colCount)),
                rows: rows.map { pad($0, to: colCount) }
            ),
            i
        )
    }

    private func splitTableRow(_ line: String) -> [String]? {
        var s = line.trimmingCharacters(in: .whitespaces)
        guard s.contains("|") else { return nil }
        if s.hasPrefix("|") { s = String(s.dropFirst()) }
        if s.hasSuffix("|") { s = String(s.dropLast()) }
        let cells = s.split(separator: "|", omittingEmptySubsequences: false).map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        return cells.isEmpty ? nil : cells
    }

    private func parseList(lines: [String], at index: Int) throws -> (BlockNode, Int)? {
        guard let first = matchListMarker(lines[index]) else { return nil }
        let ordered = first.ordered
        let start = first.number ?? 1

        var items: [ListItem] = []
        var i = index
        while i < lines.count {
            guard let marker = matchListMarker(lines[i]) else { break }
            if marker.ordered != ordered { break }

            var itemText = marker.rest
            var j = i + 1
            // Continuation lines indented by ≥2 spaces
            while j < lines.count {
                let line = lines[j]
                if line.trimmingCharacters(in: .whitespaces).isEmpty {
                    break
                }
                if matchListMarker(line) != nil { break }
                let leading = line.prefix(while: { $0 == " " }).count
                if leading >= 2 {
                    itemText += "\n" + String(line.drop(while: { $0 == " " }))
                    j += 1
                } else {
                    break
                }
            }
            items.append(
                ListItem(checked: marker.checked, inlines: InlineParser.parse(itemText))
            )
            i = j
        }

        if ordered {
            return (.numberedList(start: start, items: items), i)
        }
        return (.bulletList(items), i)
    }

    private struct ListMarker {
        var ordered: Bool
        var number: Int?
        var checked: Bool?
        var rest: String
    }

    private func matchListMarker(_ line: String) -> ListMarker? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        // Bullet
        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
            var rest = String(trimmed.dropFirst(2))
            var checked: Bool?
            if rest.hasPrefix("[ ]") {
                checked = false
                rest = String(rest.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            } else if rest.lowercased().hasPrefix("[x]") {
                checked = true
                rest = String(rest.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            }
            return ListMarker(ordered: false, number: nil, checked: checked, rest: rest)
        }
        // Numbered: `1. text`
        if let dot = trimmed.firstIndex(of: "."),
            let num = Int(trimmed[..<dot]),
            num >= 0,
            trimmed.index(after: dot) < trimmed.endIndex,
            trimmed[trimmed.index(after: dot)] == " "
        {
            let rest = String(trimmed[trimmed.index(dot, offsetBy: 2)...])
            return ListMarker(ordered: true, number: num, checked: nil, rest: rest)
        }
        return nil
    }

    private func parseStandaloneImage(_ trimmed: String) -> BlockNode? {
        let nodes = InlineParser.parse(trimmed)
        if nodes.count == 1, case .image(let alt, let url, let title) = nodes[0] {
            return .image(alt: alt, url: url, title: title)
        }
        return nil
    }

    private func parseParagraph(lines: [String], at index: Int) -> (BlockNode, Int) {
        var parts: [String] = []
        var i = index
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { break }
            if isThematicBreak(trimmed) { break }
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") { break }
            if trimmed.lowercased().hasPrefix("<details") { break }
            if trimmed.hasPrefix(">") { break }
            if matchListMarker(line) != nil { break }
            if parseHeading(trimmed) != nil { break }
            // Stop before a GFM table that starts on this line
            if i + 1 < lines.count, parseTable(lines: lines, at: i) != nil { break }
            parts.append(trimmed)
            i += 1
        }
        let text = parts.joined(separator: "\n")
        return (.paragraph(InlineParser.parse(text)), i)
    }

    private func isThematicBreak(_ trimmed: String) -> Bool {
        let compact = trimmed.filter { !$0.isWhitespace }
        guard compact.count >= 3 else { return false }
        return compact.allSatisfy({ $0 == "-" })
            || compact.allSatisfy({ $0 == "*" })
            || compact.allSatisfy({ $0 == "_" })
    }
}
