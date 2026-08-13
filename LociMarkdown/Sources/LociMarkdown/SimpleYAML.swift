import Foundation

/// Minimal YAML subset for Loci frontmatter (no external YAML dependency — Linux SPM friendly).
///
/// Supports: scalars (string / number / bool / null), flow arrays `[a, b]`,
/// block maps with 2-space indent, nested maps, and simple block sequences (`- item`).
public enum SimpleYAML {
    public enum Value: Hashable, Sendable, Equatable {
        case null
        case bool(Bool)
        case number(Double)
        case string(String)
        case array([Value])
        case map([String: Value])
    }

    // MARK: - Parse

    public static func parseMap(_ text: String) throws -> [String: Value] {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var index = 0
        let value = try parseBlock(lines: lines, index: &index, indent: 0)
        guard case .map(let map) = value else {
            throw MarkdownError.invalidFrontMatter("expected mapping at root")
        }
        return map
    }

    private static func parseBlock(lines: [String], index: inout Int, indent: Int) throws -> Value {
        skipBlank(lines: lines, index: &index)
        guard index < lines.count else { return .map([:]) }

        let current = lines[index]
        let currentIndent = leadingSpaces(current)
        if currentIndent < indent {
            return .map([:])
        }

        // Block sequence
        if trimmed(current).hasPrefix("- ") || trimmed(current) == "-" {
            return try parseSequence(lines: lines, index: &index, indent: indent)
        }

        return try parseMapping(lines: lines, index: &index, indent: indent)
    }

    private static func parseMapping(lines: [String], index: inout Int, indent: Int) throws -> Value {
        var result: [String: Value] = [:]
        while index < lines.count {
            skipBlank(lines: lines, index: &index)
            guard index < lines.count else { break }
            let line = lines[index]
            let lineIndent = leadingSpaces(line)
            if lineIndent < indent { break }
            if lineIndent > indent {
                throw MarkdownError.invalidFrontMatter("unexpected indent at line \(index + 1)")
            }
            let content = trimmed(line)
            if content.hasPrefix("- ") { break }

            guard let colon = content.firstIndex(of: ":") else {
                throw MarkdownError.invalidFrontMatter("expected key: value at line \(index + 1)")
            }
            let key = String(content[..<colon]).trimmingCharacters(in: .whitespaces)
            let rest = String(content[content.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            index += 1

            if rest.isEmpty {
                // Nested block
                skipBlank(lines: lines, index: &index)
                if index < lines.count {
                    let nextIndent = leadingSpaces(lines[index])
                    if nextIndent > indent {
                        result[key] = try parseBlock(lines: lines, index: &index, indent: nextIndent)
                        continue
                    }
                }
                result[key] = .null
            } else {
                result[key] = try parseFlow(rest)
            }
        }
        return .map(result)
    }

    private static func parseSequence(lines: [String], index: inout Int, indent: Int) throws -> Value {
        var items: [Value] = []
        while index < lines.count {
            skipBlank(lines: lines, index: &index)
            guard index < lines.count else { break }
            let line = lines[index]
            let lineIndent = leadingSpaces(line)
            if lineIndent < indent { break }
            let content = trimmed(line)
            guard content.hasPrefix("-") else { break }
            let afterDash = content.dropFirst().trimmingCharacters(in: .whitespaces)
            index += 1
            if afterDash.isEmpty {
                skipBlank(lines: lines, index: &index)
                if index < lines.count, leadingSpaces(lines[index]) > indent {
                    items.append(try parseBlock(lines: lines, index: &index, indent: leadingSpaces(lines[index])))
                } else {
                    items.append(.null)
                }
            } else if afterDash.contains(":"), !afterDash.hasPrefix("["), !afterDash.hasPrefix("{") {
                // Inline map start: fake a line and parse mapping at deeper indent
                // Treat `- key: value` as a single-key map, possibly followed by more indented keys.
                var fakeLines = ["\(String(repeating: " ", count: indent + 2))\(afterDash)"]
                var j = index
                while j < lines.count {
                    let li = leadingSpaces(lines[j])
                    if li <= indent { break }
                    if trimmed(lines[j]).hasPrefix("- ") { break }
                    fakeLines.append(lines[j])
                    j += 1
                }
                var fakeIndex = 0
                items.append(try parseMapping(lines: fakeLines, index: &fakeIndex, indent: indent + 2))
                index = j
            } else {
                items.append(try parseFlow(String(afterDash)))
            }
        }
        return .array(items)
    }

    public static func parseFlow(_ raw: String) throws -> Value {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return .null }
        if s == "null" || s == "~" || s == "Null" || s == "NULL" { return .null }
        if s == "true" || s == "True" || s == "TRUE" { return .bool(true) }
        if s == "false" || s == "False" || s == "FALSE" { return .bool(false) }
        if s.hasPrefix("["), s.hasSuffix("]") {
            return try parseFlowArray(String(s.dropFirst().dropLast()))
        }
        if s.hasPrefix("{"), s.hasSuffix("}") {
            return try parseFlowMap(String(s.dropFirst().dropLast()))
        }
        if let d = Double(s), s.rangeOfCharacter(from: LetterSet.letters) == nil {
            return .number(d)
        }
        return .string(unquote(s))
    }

    private static func parseFlowArray(_ inner: String) throws -> Value {
        let parts = splitTopLevel(inner, separator: ",")
        let values = try parts.map { try parseFlow($0) }
        return .array(values)
    }

    private static func parseFlowMap(_ inner: String) throws -> Value {
        var map: [String: Value] = [:]
        for part in splitTopLevel(inner, separator: ",") {
            let trimmedPart = part.trimmingCharacters(in: .whitespaces)
            guard let colon = trimmedPart.firstIndex(of: ":") else {
                throw MarkdownError.invalidFrontMatter("invalid flow map entry: \(part)")
            }
            let key = unquote(String(trimmedPart[..<colon]).trimmingCharacters(in: .whitespaces))
            let value = try parseFlow(String(trimmedPart[trimmedPart.index(after: colon)...]))
            map[key] = value
        }
        return .map(map)
    }

    // MARK: - Stringify

    public static func stringify(_ value: Value, indent: Int = 0) -> String {
        switch value {
        case .null:
            return "null"
        case .bool(let b):
            return b ? "true" : "false"
        case .number(let n):
            if n.rounded() == n, abs(n) < Double(Int.max) {
                return String(Int(n))
            }
            return String(n)
        case .string(let s):
            return quoteIfNeeded(s)
        case .array(let items):
            if items.isEmpty { return "[]" }
            if items.allSatisfy(\.isScalar) {
                let inner = items.map { stringify($0) }.joined(separator: ", ")
                return "[\(inner)]"
            }
            let pad = String(repeating: " ", count: indent)
            return items.map { item in
                let body = stringify(item, indent: indent + 2)
                if case .map = item {
                    let lines = body.split(separator: "\n", omittingEmptySubsequences: false)
                    if let first = lines.first {
                        let rest = lines.dropFirst().map { "\(pad)  \($0)" }.joined(separator: "\n")
                        return rest.isEmpty ? "\(pad)- \(first)" : "\(pad)- \(first)\n\(rest)"
                    }
                }
                return "\(pad)- \(body)"
            }.joined(separator: "\n")
        case .map(let map):
            if map.isEmpty { return "{}" }
            let pad = String(repeating: " ", count: indent)
            let keys = map.keys.sorted()
            return keys.map { key in
                let v = map[key]!
                switch v {
                case .map, .array:
                    if case .array(let items) = v, items.isEmpty {
                        return "\(pad)\(key): []"
                    }
                    if case .map(let nested) = v, nested.isEmpty {
                        return "\(pad)\(key): {}"
                    }
                    if case .array(let items) = v, items.allSatisfy(\.isScalar) {
                        return "\(pad)\(key): \(stringify(v))"
                    }
                    return "\(pad)\(key):\n\(stringify(v, indent: indent + 2))"
                default:
                    return "\(pad)\(key): \(stringify(v))"
                }
            }.joined(separator: "\n")
        }
    }

    // MARK: - Helpers

    private enum LetterSet {
        static let letters = CharacterSet.letters
    }

    private static func leadingSpaces(_ line: String) -> Int {
        var count = 0
        for ch in line {
            if ch == " " { count += 1 } else { break }
        }
        return count
    }

    private static func trimmed(_ line: String) -> String {
        line.trimmingCharacters(in: .whitespaces)
    }

    private static func skipBlank(lines: [String], index: inout Int) {
        while index < lines.count {
            let t = trimmed(lines[index])
            if t.isEmpty || t.hasPrefix("#") {
                index += 1
            } else {
                break
            }
        }
    }

    private static func unquote(_ s: String) -> String {
        if s.count >= 2 {
            if (s.hasPrefix("\"") && s.hasSuffix("\"")) || (s.hasPrefix("'") && s.hasSuffix("'")) {
                let inner = String(s.dropFirst().dropLast())
                return inner
                    .replacingOccurrences(of: "\\\"", with: "\"")
                    .replacingOccurrences(of: "\\n", with: "\n")
            }
        }
        return s
    }

    private static func quoteIfNeeded(_ s: String) -> String {
        let needs =
            s.isEmpty
            || s.hasPrefix(" ")
            || s.hasSuffix(" ")
            || s.contains(":")
            || s.contains("#")
            || s.contains("[")
            || s.contains("]")
            || s.contains("{")
            || s.contains("}")
            || s.contains(",")
            || s.contains("\n")
            || s == "true" || s == "false" || s == "null"
            || Double(s) != nil
        if needs {
            let escaped = s
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
            return "\"\(escaped)\""
        }
        return s
    }

    private static func splitTopLevel(_ input: String, separator: Character) -> [String] {
        var parts: [String] = []
        var current = ""
        var depth = 0
        var inQuote: Character?
        for ch in input {
            if let q = inQuote {
                current.append(ch)
                if ch == q { inQuote = nil }
                continue
            }
            if ch == "\"" || ch == "'" {
                inQuote = ch
                current.append(ch)
                continue
            }
            if ch == "[" || ch == "{" {
                depth += 1
                current.append(ch)
                continue
            }
            if ch == "]" || ch == "}" {
                depth -= 1
                current.append(ch)
                continue
            }
            if ch == separator, depth == 0 {
                parts.append(current)
                current = ""
                continue
            }
            current.append(ch)
        }
        if !current.trimmingCharacters(in: .whitespaces).isEmpty || !parts.isEmpty {
            parts.append(current)
        }
        return parts.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}

extension SimpleYAML.Value {
    fileprivate var isScalar: Bool {
        switch self {
        case .null, .bool, .number, .string: return true
        default: return false
        }
    }
}
