import Foundation
import GRDB
import LociCore

/// FTS5 search helpers over `blocks_fts` + `objects`.
public enum SearchQuery {
    static func search(db: Database, query: String, limit: Int = 50) throws -> [LociObjectMeta] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let match = ftsMatchQuery(trimmed)
        let rows = try Row.fetchAll(
            db,
            sql: """
                SELECT o.*
                FROM blocks_fts
                JOIN objects o ON o.id = blocks_fts.object_id
                WHERE blocks_fts MATCH ?
                ORDER BY rank
                LIMIT ?
                """,
            arguments: [match, limit]
        )
        return try rows.map { try ObjectRowDecoder.decode($0) }
    }

    /// Escape user text into a safe FTS5 MATCH expression (prefix token search).
    /// Public for Linux unit tests (ranking / MATCH construction).
    public static func ftsMatchQuery(_ raw: String) -> String {
        let normalized = SearchRanking.normalizeQuery(raw)
        let tokens = normalized
            .split(whereSeparator: { $0.isWhitespace || $0.isPunctuation })
            .map(String.init)
            .filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return "\"\"" }
        return tokens.map { token -> String in
            let escaped = token.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\"*"
        }.joined(separator: " ")
    }
}
