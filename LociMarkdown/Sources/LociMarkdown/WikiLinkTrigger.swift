import Foundation

/// Trigger kinds for the link picker (`@` mention or open `[[` wiki brackets).
public enum WikiLinkTriggerKind: String, Sendable, Hashable {
    case atMention
    case wikiBrackets
}

/// Incomplete `@query` or `[[query` in editor plain text.
public struct WikiLinkTrigger: Hashable, Sendable, Equatable {
    public var kind: WikiLinkTriggerKind
    public var query: String
    /// UTF-16 / String index offset into plain text where the trigger starts (`@` or `[[`).
    public var replaceStartOffset: Int

    public init(kind: WikiLinkTriggerKind, query: String, replaceStartOffset: Int) {
        self.kind = kind
        self.query = query
        self.replaceStartOffset = replaceStartOffset
    }
}

/// Detect incomplete wiki-link / @-mention triggers in block plain text.
public enum WikiLinkTriggerDetector: Sendable {
    /// Returns the rightmost incomplete trigger, preferring open `[[` over `@`.
    public static func detect(in text: String) -> WikiLinkTrigger? {
        if let wiki = detectOpenWikiBrackets(in: text) {
            return wiki
        }
        return detectAtMention(in: text)
    }

    private static func detectOpenWikiBrackets(in text: String) -> WikiLinkTrigger? {
        guard let open = text.range(of: "[[", options: .backwards) else { return nil }
        let after = text[open.upperBound...]
        // Still open if no closing `]` yet (covers `[[` and `[[query` and `[[query|`).
        if after.contains("]") { return nil }
        let query = String(after)
        let offset = text.distance(from: text.startIndex, to: open.lowerBound)
        return WikiLinkTrigger(kind: .wikiBrackets, query: query, replaceStartOffset: offset)
    }

    private static func detectAtMention(in text: String) -> WikiLinkTrigger? {
        guard let at = text.range(of: "@", options: .backwards) else { return nil }
        // Must be at start or after whitespace.
        if at.lowerBound != text.startIndex {
            let before = text[text.index(before: at.lowerBound)]
            guard before.isWhitespace || before.isNewline else { return nil }
        }
        let after = text[at.upperBound...]
        // Mentions are a single token — no whitespace; stop if user already closed somehow.
        if after.contains(where: { $0.isWhitespace || $0.isNewline }) { return nil }
        if after.contains("[") { return nil }
        let query = String(after)
        let offset = text.distance(from: text.startIndex, to: at.lowerBound)
        return WikiLinkTrigger(kind: .atMention, query: query, replaceStartOffset: offset)
    }
}
