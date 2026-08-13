import Foundation

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

        // Fenced code
        if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
            return try parseCodeFence(lines: lines, at: index)
        }

        // Heading
        if let heading = parseHeading(trimmed) {
            return (heading, index + 1)
        }

        // Block quote
        if trimmed.hasPrefix(">") {
            return try parseBlockQuote(lines: lines, at: index)
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
                return (.codeBlock(language: language, code: code), i + 1)
            }
            codeLines.append(lines[i])
            i += 1
        }
        throw MarkdownError.unbalancedFence
    }

    private func parseBlockQuote(lines: [String], at index: Int) throws -> (BlockNode, Int) {
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
        let inner = try parseBlocks(quoteLines.joined(separator: "\n"))
        return (.blockQuote(inner.isEmpty ? [.paragraph([])] : inner), i)
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
            if trimmed.hasPrefix(">") { break }
            if matchListMarker(line) != nil { break }
            if parseHeading(trimmed) != nil { break }
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
