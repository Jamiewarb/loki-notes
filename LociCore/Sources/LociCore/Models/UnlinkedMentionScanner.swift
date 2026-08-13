import Foundation

/// Pure title-mention scanner (PR44). No I/O, no index, no SwiftUI.
///
/// Matches a candidate title as a case-insensitive whole-word / phrase in markdown
/// or plain text. Skips matches inside `[[...]]` wiki-links. Empty or very short
/// titles are ignored so single letters do not flood the panel.
///
/// Listing mentions never rewrites the body. `replaceFirst` exists only for an
/// explicit **Link** tap.
public enum UnlinkedMentionScanner: Sendable {
    public static let minimumTitleLength = 3
    public static let resultLimit = 50

    /// True when `title` is long enough to scan without noise.
    public static func isTitleScannable(_ title: String) -> Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).count >= minimumTitleLength
    }

    /// Whether the source already wiki-links to this title (raw `[[target]]`).
    public static func alreadyWikiLinked(title: String, existingWikiTargets: [String]) -> Bool {
        let needle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return false }
        return existingWikiTargets.contains { target in
            target.trimmingCharacters(in: .whitespacesAndNewlines)
                .compare(needle, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
    }

    /// True when `body` mentions `title` as unlinked text.
    public static func mentions(
        _ body: String,
        title: String,
        existingWikiTargets: [String] = []
    ) -> Bool {
        firstRange(in: body, title: title, existingWikiTargets: existingWikiTargets) != nil
    }

    /// First unlinked title range, or `nil` when there is no mention.
    public static func firstRange(
        in body: String,
        title: String,
        existingWikiTargets: [String] = []
    ) -> Range<String.Index>? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isTitleScannable(trimmed) else { return nil }
        if alreadyWikiLinked(title: trimmed, existingWikiTargets: existingWikiTargets) {
            return nil
        }
        let wikiRanges = wikiLinkRanges(in: body)
        guard let regex = titleRegex(for: trimmed) else { return nil }
        let ns = body as NSString
        let full = NSRange(location: 0, length: ns.length)
        let matches = regex.matches(in: body, range: full)
        for match in matches {
            if wikiRanges.contains(where: { NSIntersectionRange($0, match.range).length > 0 }) {
                continue
            }
            guard let range = Range(match.range, in: body) else { continue }
            return range
        }
        return nil
    }

    /// Excerpt around the first unlinked occurrence.
    public static func snippet(
        from body: String,
        title: String,
        existingWikiTargets: [String] = [],
        radius: Int = 42
    ) -> String {
        guard let range = firstRange(
            in: body,
            title: title,
            existingWikiTargets: existingWikiTargets
        ) else {
            return ""
        }
        let startDistance = max(0, body.distance(from: body.startIndex, to: range.lowerBound) - radius)
        let endDistance = min(
            body.count,
            body.distance(from: body.startIndex, to: range.upperBound) + radius
        )
        let start = body.index(body.startIndex, offsetBy: startDistance)
        let end = body.index(body.startIndex, offsetBy: endDistance)
        var slice = String(body[start..<end])
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if startDistance > 0 { slice = "…" + slice }
        if endDistance < body.count { slice += "…" }
        return slice
    }

    /// `[[id|title]]` (or `[[id]]` when the title is empty).
    public static func wikiLinkMarkdown(targetID: String, title: String) -> String {
        let id = targetID.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if label.isEmpty || label == id {
            return "[[\(id)]]"
        }
        return "[[\(id)|\(label)]]"
    }

    /// Replace the first unlinked title occurrence with `wikiMarkdown`.
    /// Returns `nil` when there is nothing to link. Never called from typing / save.
    public static func replaceFirst(
        in body: String,
        title: String,
        withWikiLink wikiMarkdown: String,
        existingWikiTargets: [String] = []
    ) -> String? {
        guard let range = firstRange(
            in: body,
            title: title,
            existingWikiTargets: existingWikiTargets
        ) else {
            return nil
        }
        var next = body
        next.replaceSubrange(range, with: wikiMarkdown)
        return next
    }

    // MARK: - Internals

    private static func titleRegex(for title: String) -> NSRegularExpression? {
        let escaped = NSRegularExpression.escapedPattern(for: title)
        let pattern = "(?<![\\p{L}\\p{N}_])\(escaped)(?![\\p{L}\\p{N}_])"
        return try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }

    /// Ranges of `[[target]]` / `[[target|label]]` interiors including brackets.
    static func wikiLinkRanges(in text: String) -> [NSRange] {
        guard let regex = try? NSRegularExpression(pattern: #"\[\[[^\]]+\]\]"#) else {
            return []
        }
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)
        return regex.matches(in: text, range: full).map(\.range)
    }
}
