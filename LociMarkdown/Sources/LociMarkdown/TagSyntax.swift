import Foundation

/// Inline `#tag` helpers for Loci MD.
public enum TagSyntax {
    /// Tag body: letters, digits, underscore, hyphen, slash (for nested tags).
    public static let bodyPattern = #"[A-Za-z][A-Za-z0-9_/-]*"#

    /// Full `#tag` token.
    public static let pattern = "#\(bodyPattern)"

    public static func isValidTagBody(_ body: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: "^\(bodyPattern)$") else { return false }
        let range = NSRange(location: 0, length: (body as NSString).length)
        return regex.firstMatch(in: body, range: range) != nil
    }

    public static func normalize(_ raw: String) -> String {
        var body = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if body.hasPrefix("#") {
            body = String(body.dropFirst())
        }
        return body
    }

    public static func markdown(_ body: String) -> String {
        "#\(normalize(body))"
    }

    public static func extract(from text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)
        return regex.matches(in: text, range: range).compactMap { match -> String? in
            guard let r = Range(match.range, in: text) else { return nil }
            return normalize(String(text[r]))
        }
    }
}
