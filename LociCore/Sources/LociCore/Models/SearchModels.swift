import Foundation

/// One type section in global FTS results (PR18).
public struct SearchResultGroup: Hashable, Sendable, Equatable {
    public var typeID: ObjectTypeID
    public var items: [LociObjectMeta]

    public init(typeID: ObjectTypeID, items: [LociObjectMeta]) {
        self.typeID = typeID
        self.items = items
    }

    public var title: String { typeID.rawValue.capitalized }
}

/// Pure helpers for presenting ranked `IndexQuerying.search` hits.
///
/// Ranking comes from FTS5 (`ORDER BY rank`); these helpers only **group / filter /
/// lightly re-order** without touching the index or vault.
public enum SearchGrouping: Sendable {
    /// Group ranked hits by `typeID`, preserving first-seen type order and
    /// within-group FTS rank order.
    public static func byType(_ hits: [LociObjectMeta]) -> [SearchResultGroup] {
        var order: [ObjectTypeID] = []
        var buckets: [ObjectTypeID: [LociObjectMeta]] = [:]
        for hit in hits {
            if buckets[hit.typeID] == nil {
                order.append(hit.typeID)
                buckets[hit.typeID] = []
            }
            buckets[hit.typeID, default: []].append(hit)
        }
        return order.map { SearchResultGroup(typeID: $0, items: buckets[$0] ?? []) }
    }

    /// Optional type chip filter (nil = all types).
    public static func filter(_ hits: [LociObjectMeta], typeID: ObjectTypeID?) -> [LociObjectMeta] {
        guard let typeID else { return hits }
        return hits.filter { $0.typeID == typeID }
    }

    /// Flatten groups back to a single ranked list (group order × within-group order).
    public static func flatten(_ groups: [SearchResultGroup]) -> [LociObjectMeta] {
        groups.flatMap(\.items)
    }
}

/// Lightweight ranking polish for UI (does not replace FTS `rank`).
///
/// When titles clearly match the query, bubble those rows ahead of body-only hits
/// while keeping relative order inside each bucket.
public enum SearchRanking: Sendable {
    public static func preferTitleMatches(_ hits: [LociObjectMeta], query: String)
        -> [LociObjectMeta]
    {
        let needle = normalizeQuery(query)
        guard !needle.isEmpty else { return hits }
        var titleHits: [LociObjectMeta] = []
        var other: [LociObjectMeta] = []
        for hit in hits {
            if titleMatches(hit.title, query: needle) {
                titleHits.append(hit)
            } else {
                other.append(hit)
            }
        }
        return titleHits + other
    }

    /// Trim + collapse whitespace; empty → no search.
    public static func normalizeQuery(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    public static func titleMatches(_ title: String, query: String) -> Bool {
        let needle = normalizeQuery(query).lowercased()
        guard !needle.isEmpty else { return false }
        return title.lowercased().contains(needle)
    }
}

/// In-memory recent query list (optional ⌘K polish). Not written to vault or index.
public struct RecentSearchStore: Hashable, Sendable, Equatable {
    public private(set) var queries: [String]
    public var limit: Int

    public init(queries: [String] = [], limit: Int = 8) {
        self.limit = max(1, limit)
        self.queries = []
        for q in queries {
            record(q)
        }
    }

    public mutating func record(_ raw: String) {
        let q = SearchRanking.normalizeQuery(raw)
        guard !q.isEmpty else { return }
        queries.removeAll { $0.caseInsensitiveCompare(q) == .orderedSame }
        queries.insert(q, at: 0)
        if queries.count > limit {
            queries = Array(queries.prefix(limit))
        }
    }

    public mutating func clear() {
        queries = []
    }
}
