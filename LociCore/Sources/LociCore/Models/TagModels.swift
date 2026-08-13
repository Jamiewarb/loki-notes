import Foundation

/// Normalize tag tokens for index / frontmatter (strip `#`, lowercase).
public enum TagNormalization: Sendable {
    public static func normalize(_ raw: String) -> String {
        var body = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if body.hasPrefix("#") {
            body = String(body.dropFirst())
        }
        return body.lowercased()
    }

    /// Display form `#tag` (always normalized body).
    public static func display(_ raw: String) -> String {
        let body = normalize(raw)
        guard !body.isEmpty else { return "#" }
        return "#\(body)"
    }

    /// Deduplicate while preserving first-seen order (normalized).
    public static func uniquing(_ tags: [String]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for tag in tags {
            let n = normalize(tag)
            guard !n.isEmpty, !seen.contains(n) else { continue }
            seen.insert(n)
            out.append(n)
        }
        return out
    }
}

/// Space-level tag aliases: canonical name → alternate spellings.
///
/// Stored on `SpaceSettings.tagAliases`. Index rows keep the literal normalized tag;
/// queries expand aliases so `#wellness` finds objects tagged `#health` when mapped.
public struct TagAliasTable: Hashable, Sendable, Codable, Equatable {
    /// Canonical tag (normalized) → alias list (normalized on read).
    public var aliasesByCanonical: [String: [String]]

    public init(aliasesByCanonical: [String: [String]] = [:]) {
        var normalized: [String: [String]] = [:]
        for (key, values) in aliasesByCanonical {
            let canon = TagNormalization.normalize(key)
            guard !canon.isEmpty else { continue }
            let aliases = TagNormalization.uniquing(values).filter { $0 != canon }
            normalized[canon] = aliases
        }
        self.aliasesByCanonical = normalized
    }

    public static let empty = TagAliasTable()

    /// Resolve any raw tag / alias to its canonical form.
    public func canonical(for raw: String) -> String {
        let n = TagNormalization.normalize(raw)
        guard !n.isEmpty else { return n }
        if aliasesByCanonical[n] != nil { return n }
        for (canon, aliases) in aliasesByCanonical {
            if aliases.contains(n) { return canon }
        }
        return n
    }

    /// All index spellings that should match a user query (canonical + aliases + raw).
    public func expansion(for raw: String) -> Set<String> {
        let n = TagNormalization.normalize(raw)
        guard !n.isEmpty else { return [] }
        let canon = canonical(for: n)
        var set: Set<String> = [n, canon]
        if let aliases = aliasesByCanonical[canon] {
            for a in aliases { set.insert(a) }
        }
        return set
    }

    /// Map a stored tag to its canonical display name.
    public func displayCanonical(for stored: String) -> String {
        TagNormalization.display(canonical(for: stored))
    }
}

/// Aggregated tag row for browse / completer UI.
public struct TagSummary: Hashable, Sendable, Equatable {
    public var tag: String
    public var count: Int
    /// Canonical form when aliases collapse variants (may equal `tag`).
    public var canonical: String

    public init(tag: String, count: Int, canonical: String? = nil) {
        let normalized = TagNormalization.normalize(tag)
        self.tag = normalized
        self.count = count
        self.canonical = TagNormalization.normalize(canonical ?? tag)
    }

    public var display: String { TagNormalization.display(tag) }
}

/// Dashboard / list filter by tag (PR17). Does not write derived lists into markdown.
public enum TagFilter: Sendable {
    public static func matches(_ meta: LociObjectMeta, tag: String, aliases: TagAliasTable = .empty)
        -> Bool
    {
        let wanted = aliases.expansion(for: tag)
        guard !wanted.isEmpty else { return true }
        let objectTags = Set(meta.tags.map(TagNormalization.normalize))
        return !objectTags.isDisjoint(with: wanted)
    }

    public static func visible(
        _ items: [LociObjectMeta],
        tag: String?,
        aliases: TagAliasTable = .empty
    ) -> [LociObjectMeta] {
        guard let tag, !TagNormalization.normalize(tag).isEmpty else { return items }
        return items.filter { matches($0, tag: tag, aliases: aliases) }
    }
}
