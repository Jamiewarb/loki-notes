import Foundation
import GRDB
import LociCore

/// Backlinks / outgoing link queries over the disposable `links` table.
enum LinksQuery {
    static func backlinks(db: Database, to objectID: ObjectID) throws -> [BacklinkRecord] {
        guard
            let row = try Row.fetchOne(
                db,
                sql: "SELECT * FROM objects WHERE id = ?",
                arguments: [objectID.uuidString.lowercased()]
            )
        else { return [] }

        let meta = try ObjectRowDecoder.decode(row)
        let aliases = LinkResolver.targetAliases(for: meta)
        guard !aliases.isEmpty else { return [] }

        let placeholders = Array(repeating: "?", count: aliases.count).joined(separator: ", ")
        let sql = """
            SELECT l.target AS link_target, l.label AS link_label, o.*
            FROM links l
            JOIN objects o ON o.id = l.source_id
            WHERE lower(l.target) IN (\(placeholders))
            ORDER BY o.title COLLATE NOCASE ASC
            """
        let args = StatementArguments(aliases.map { $0.lowercased() })
        let rows = try Row.fetchAll(db, sql: sql, arguments: args)

        var seen = Set<String>()
        var results: [BacklinkRecord] = []
        for r in rows {
            let source = try ObjectRowDecoder.decode(r)
            let key = source.id.uuidString.lowercased()
            if seen.contains(key) { continue }
            seen.insert(key)
            let target: String = r["link_target"]
            let label: String? = r["link_label"]
            results.append(BacklinkRecord(source: source, target: target, label: label))
        }
        return results
    }

    static func outgoing(db: Database, from objectID: ObjectID) throws -> [ResolvedWikiLink] {
        let id = objectID.uuidString.lowercased()
        let rows = try Row.fetchAll(
            db,
            sql: """
                SELECT target, label FROM links
                WHERE source_id = ?
                ORDER BY id ASC
                """,
            arguments: [id]
        )
        return try rows.map { row in
            let target: String = row["target"]
            let label: String? = row["label"]
            let resolved = try LinkResolver.resolve(db: db, target: target)
            return ResolvedWikiLink(target: target, label: label, resolved: resolved)
        }
    }

    static func candidates(
        db: Database,
        matching query: String,
        excluding excludeID: ObjectID?,
        limit: Int
    ) throws -> [LociObjectMeta] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let cap = max(1, min(limit, 100))
        let exclude = excludeID?.uuidString.lowercased()

        if trimmed.isEmpty {
            let rows = try Row.fetchAll(
                db,
                sql: """
                    SELECT * FROM objects
                    ORDER BY updated DESC
                    LIMIT ?
                    """,
                arguments: [cap + 5]
            )
            return try filterExclude(rows, exclude: exclude, limit: cap)
        }

        // Exact resolve first (id/path/title)
        var results: [LociObjectMeta] = []
        var seen = Set<String>()
        if let hit = try LinkResolver.resolve(db: db, target: trimmed) {
            let key = hit.id.uuidString.lowercased()
            if exclude != key {
                results.append(hit)
                seen.insert(key)
            }
        }

        // Title prefix / contains
        let like = "%\(escapeLike(trimmed))%"
        let titleRows = try Row.fetchAll(
            db,
            sql: """
                SELECT * FROM objects
                WHERE title LIKE ? ESCAPE '\\' COLLATE NOCASE
                ORDER BY
                  CASE WHEN title LIKE ? ESCAPE '\\' COLLATE NOCASE THEN 0 ELSE 1 END,
                  updated DESC
                LIMIT ?
                """,
            arguments: [like, "\(escapeLike(trimmed))%", cap]
        )
        for row in titleRows {
            let meta = try ObjectRowDecoder.decode(row)
            let key = meta.id.uuidString.lowercased()
            if let exclude, key == exclude { continue }
            if seen.contains(key) { continue }
            seen.insert(key)
            results.append(meta)
            if results.count >= cap { return results }
        }

        // FTS fallback for body hits
        let fts = try SearchQuery.search(db: db, query: trimmed, limit: cap)
        for meta in fts {
            let key = meta.id.uuidString.lowercased()
            if let exclude, key == exclude { continue }
            if seen.contains(key) { continue }
            seen.insert(key)
            results.append(meta)
            if results.count >= cap { break }
        }

        return results
    }

    private static func filterExclude(
        _ rows: [Row],
        exclude: String?,
        limit: Int
    ) throws -> [LociObjectMeta] {
        var out: [LociObjectMeta] = []
        for row in rows {
            let meta = try ObjectRowDecoder.decode(row)
            let key = meta.id.uuidString.lowercased()
            if let exclude, key == exclude { continue }
            out.append(meta)
            if out.count >= limit { break }
        }
        return out
    }

    private static func escapeLike(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
    }
}
