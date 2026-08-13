import Foundation

/// Wiki-link target used in Loci MD: `[[id-or-slug]]` or `[[id-or-slug|label]]`.
public struct WikiLink: Hashable, Sendable, Equatable {
    public var target: String
    public var label: String?

    public init(target: String, label: String? = nil) {
        self.target = target
        self.label = label
    }

    /// Display text: explicit label, otherwise the target.
    public var displayText: String {
        label ?? target
    }

    /// Serialize to Loci wiki-link syntax.
    public var markdown: String {
        if let label, !label.isEmpty, label != target {
            return "[[\(target)|\(label)]]"
        }
        return "[[\(target)]]"
    }

    /// Parse a single wiki-link token (with or without surrounding brackets).
    public static func parse(_ raw: String) -> WikiLink? {
        var inner = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if inner.hasPrefix("[["), inner.hasSuffix("]]"), inner.count >= 4 {
            inner = String(inner.dropFirst(2).dropLast(2))
        }
        guard !inner.isEmpty else { return nil }
        if let bar = inner.firstIndex(of: "|") {
            let target = String(inner[..<bar]).trimmingCharacters(in: .whitespaces)
            let label = String(inner[inner.index(after: bar)...]).trimmingCharacters(in: .whitespaces)
            guard !target.isEmpty else { return nil }
            return WikiLink(target: target, label: label.isEmpty ? nil : label)
        }
        return WikiLink(target: inner)
    }
}

/// Helpers for locating wiki-links inside plain text.
public enum WikiLinkSyntax {
    /// Regex-friendly pattern for `[[target]]` / `[[target|label]]` (non-greedy).
    public static let pattern = #"\[\[([^\]|]+)(?:\|([^\]]+))?\]\]"#

    public static func extract(from text: String) -> [WikiLink] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)
        return regex.matches(in: text, range: range).compactMap { match -> WikiLink? in
            guard match.numberOfRanges >= 2,
                let targetRange = Range(match.range(at: 1), in: text)
            else { return nil }
            let target = String(text[targetRange])
            var label: String?
            if match.numberOfRanges >= 3, match.range(at: 2).location != NSNotFound,
                let labelRange = Range(match.range(at: 2), in: text)
            {
                label = String(text[labelRange])
            }
            return WikiLink(target: target, label: label)
        }
    }
}
