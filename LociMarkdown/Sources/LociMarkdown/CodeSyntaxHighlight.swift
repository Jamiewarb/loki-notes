import Foundation

/// Minimal CSS-class syntax highlighter for DevHarness / Linux demos (PR29).
///
/// Not a full lexer — tokenizes common keywords / strings / comments for Swift-ish
/// and generic code so harness CSS can color spans. Safe HTML (escaped text).
public enum CodeSyntaxHighlight: Sendable {
    private static let swiftKeywords: Set<String> = [
        "let", "var", "func", "return", "if", "else", "guard", "switch", "case",
        "struct", "class", "enum", "protocol", "import", "public", "private",
        "static", "throws", "try", "async", "await", "true", "false", "nil",
        "self", "Self", "init", "where", "for", "in", "while", "defer",
    ]

    public static func highlight(_ code: String, language: String?) -> String {
        let lang = (language ?? "").lowercased()
        if lang == "swift" || lang.isEmpty {
            return highlightSwiftish(code)
        }
        // Generic: strings + comments only
        return highlightGeneric(code)
    }

    private static func highlightSwiftish(_ code: String) -> String {
        var out = ""
        var i = code.startIndex
        while i < code.endIndex {
            // Line comment
            if code[i...].hasPrefix("//") {
                if let nl = code[i...].firstIndex(of: "\n") {
                    out += span("comment", String(code[i..<nl]))
                    i = nl
                } else {
                    out += span("comment", String(code[i...]))
                    break
                }
                continue
            }
            // String
            if code[i] == "\"" {
                var j = code.index(after: i)
                while j < code.endIndex {
                    if code[j] == "\\" {
                        j = code.index(after: j)
                        if j < code.endIndex { j = code.index(after: j) }
                        continue
                    }
                    if code[j] == "\"" {
                        j = code.index(after: j)
                        break
                    }
                    j = code.index(after: j)
                }
                out += span("string", String(code[i..<j]))
                i = j
                continue
            }
            // Identifier / keyword
            if code[i].isLetter || code[i] == "_" {
                var j = i
                while j < code.endIndex, code[j].isLetter || code[j].isNumber || code[j] == "_" {
                    j = code.index(after: j)
                }
                let word = String(code[i..<j])
                if swiftKeywords.contains(word) {
                    out += span("keyword", word)
                } else {
                    out += escape(word)
                }
                i = j
                continue
            }
            out += escape(String(code[i]))
            i = code.index(after: i)
        }
        return out
    }

    private static func highlightGeneric(_ code: String) -> String {
        var out = ""
        var i = code.startIndex
        while i < code.endIndex {
            if code[i...].hasPrefix("//") || code[i...].hasPrefix("#") {
                if let nl = code[i...].firstIndex(of: "\n") {
                    out += span("comment", String(code[i..<nl]))
                    i = nl
                } else {
                    out += span("comment", String(code[i...]))
                    break
                }
                continue
            }
            if code[i] == "\"" || code[i] == "'" {
                let quote = code[i]
                var j = code.index(after: i)
                while j < code.endIndex, code[j] != quote, code[j] != "\n" {
                    if code[j] == "\\" {
                        j = code.index(after: j)
                        if j < code.endIndex { j = code.index(after: j) }
                        continue
                    }
                    j = code.index(after: j)
                }
                if j < code.endIndex { j = code.index(after: j) }
                out += span("string", String(code[i..<j]))
                i = j
                continue
            }
            out += escape(String(code[i]))
            i = code.index(after: i)
        }
        return out
    }

    private static func span(_ cls: String, _ text: String) -> String {
        "<span class=\"tok-\(cls)\">\(escape(text))</span>"
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
