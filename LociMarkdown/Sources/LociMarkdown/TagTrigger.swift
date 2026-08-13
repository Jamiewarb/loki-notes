import Foundation

/// Incomplete `#tag` trigger in editor plain text (PR17).
public struct TagTrigger: Hashable, Sendable, Equatable {
    /// Tag body typed so far (no leading `#`).
    public var query: String
    /// Offset into plain text where `#` starts.
    public var replaceStartOffset: Int

    public init(query: String, replaceStartOffset: Int) {
        self.query = query
        self.replaceStartOffset = replaceStartOffset
    }
}

/// Detect incomplete `#tag` triggers for the tag completer.
public enum TagTriggerDetector: Sendable {
    /// Returns the rightmost incomplete `#…` token that is still being typed.
    ///
    /// Markdown headings (`# Title`) are ignored — they require whitespace after `#`.
    public static func detect(in text: String) -> TagTrigger? {
        guard let hash = text.range(of: "#", options: .backwards) else { return nil }

        // Must be at start or after whitespace / opening punctuation (not mid-word).
        if hash.lowerBound != text.startIndex {
            let before = text[text.index(before: hash.lowerBound)]
            let ok =
                before.isWhitespace || before.isNewline
                || "([{\"'".contains(before)
            guard ok else { return nil }
        }

        let after = text[hash.upperBound...]
        // Heading: `#` immediately followed by whitespace (or only `#`s then whitespace).
        if after.isEmpty {
            // Trailing `#` with nothing after — treat as open tag with empty query.
        } else if let first = after.first, first.isWhitespace || first.isNewline {
            return nil
        } else if after.first == "#" {
            // `##` heading marker — not a tag.
            return nil
        }

        var body = ""
        for ch in after {
            if isTagBodyChar(ch) {
                body.append(ch)
            } else {
                // User finished the tag (space / punctuation) — no open trigger.
                return nil
            }
        }

        // Body must start with a letter when non-empty (TagSyntax).
        if !body.isEmpty {
            guard let first = body.first, first.isLetter else { return nil }
        }

        let offset = text.distance(from: text.startIndex, to: hash.lowerBound)
        return TagTrigger(query: body, replaceStartOffset: offset)
    }

    private static func isTagBodyChar(_ ch: Character) -> Bool {
        ch.isLetter || ch.isNumber || ch == "_" || ch == "-" || ch == "/"
    }
}
