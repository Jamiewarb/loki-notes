import Foundation
import GRDB
import LociCore

/// Tag browse / filter / completer queries over the disposable `tags` table.
enum TagsQuery {
    static func allTags(
        db: Database,
        aliases: TagAliasTable,
        limit: Int
    ) throws -> [TagSummary] {
        let cap = max(1, min(limit, 500))
        let rows = try Row.fetchAll(
            db,
            sql: """
                SELECT tag, COUNT(*) AS cnt
                FROM tags
                GROUP BY tag
                ORDER BY cnt DESC, tag COLLATE NOCASE ASC
                """
        )

        var counts: [String: Int] = [:]
        for row in rows {
            let raw: String = row["tag"]
            let stored = TagNormalization.normalize(raw)
            guard !stored.isEmpty else { continue }
            let canon = aliases.canonical(for: stored)
            counts[canon, default: 0] += Int(row["cnt"] as Int64)
        }

        return counts
            .map { TagSummary(tag: $0.key, count: $0.value, canonical: $0.key) }
            .sorted { lhs, rhs in
                if lhs.count != rhs.count { return lhs.count > rhs.count }
                return lhs.tag < rhs.tag
            }
            .prefix(cap)
            .map { $0 }
    }

    static func objects(
        db: Database,
        tagged tag: String,
        typeID: ObjectTypeID?,
        aliases: TagAliasTable
    ) throws -> [LociObjectMeta] {
        let variants = Array(aliases.expansion(for: tag)).sorted()
        guard !variants.isEmpty else { return [] }

        let placeholders = Array(repeating: "?", count: variants.count).joined(separator: ", ")
        var sql = """
            SELECT DISTINCT o.*
            FROM objects o
            JOIN tags t ON t.object_id = o.id
            WHERE lower(t.tag) IN (\(placeholders))
            """
        var args = StatementArguments(variants)
        if let typeID {
            sql += " AND o.type_id = ?"
            args += [typeID.rawValue]
        }
        sql += " ORDER BY o.title COLLATE NOCASE ASC"

        let rows = try Row.fetchAll(db, sql: sql, arguments: args)
        return try rows.map { try ObjectRowDecoder.decode($0) }
    }

    static func candidates(
        db: Database,
        matching query: String,
        aliases: TagAliasTable,
        limit: Int
    ) throws -> [TagSummary] {
        let trimmed = TagNormalization.normalize(query)
        let all = try allTags(db: db, aliases: aliases, limit: 500)
        let cap = max(1, min(limit, 50))

        if trimmed.isEmpty {
            return Array(all.prefix(cap))
        }

        // Prefer prefix matches, then contains; always offer the typed tag if novel.
        var results: [TagSummary] = []
        var seen = Set<String>()

        let prefix = all.filter { $0.tag.hasPrefix(trimmed) }
        let contains = all.filter { !$0.tag.hasPrefix(trimmed) && $0.tag.contains(trimmed) }

        for hit in prefix + contains {
            if seen.contains(hit.tag) { continue }
            seen.insert(hit.tag)
            results.append(hit)
            if results.count >= cap { break }
        }

        if !seen.contains(trimmed) {
            let insert = TagSummary(tag: trimmed, count: 0, canonical: aliases.canonical(for: trimmed))
            if results.count >= cap {
                results[results.count - 1] = insert
            } else {
                results.insert(insert, at: 0)
            }
        }

        return results
    }
}
