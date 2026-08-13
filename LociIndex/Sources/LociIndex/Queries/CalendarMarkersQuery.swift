import Foundation
import GRDB
import LociCore

/// Builds index-derived calendar day markers for a date range (PR25).
///
/// Dots are UI chrome only — never writes into vault markdown.
enum CalendarMarkersQuery {
    static func markers(
        db: Database,
        from: Date,
        to: Date,
        calendar: Calendar
    ) throws -> [CalendarDayMarker] {
        let start = calendar.startOfDay(for: from)
        let endDay = calendar.startOfDay(for: to)
        guard let endExclusive = calendar.date(byAdding: .day, value: 1, to: endDay) else {
            return []
        }

        let pathStart = DailyNoteIdentity.relativePath(for: start, calendar: calendar)
        let pathEnd = DailyNoteIdentity.relativePath(for: endDay, calendar: calendar)

        let dailyRows = try Row.fetchAll(
            db,
            sql: """
                SELECT o.id, o.relative_path, f.body AS fts_body
                FROM objects o
                LEFT JOIN blocks_fts f ON f.object_id = o.id
                WHERE o.type_id = ?
                  AND o.relative_path >= ?
                  AND o.relative_path <= ?
                """,
            arguments: [ObjectTypeID.daily.rawValue, pathStart, pathEnd]
        )

        var byKey: [String: (
            hasDaily: Bool,
            hasContent: Bool,
            creations: Int
        )] = [:]

        for row in dailyRows {
            let path: String = row["relative_path"]
            guard let key = dayKey(fromDailyPath: path) else { continue }
            let body: String = row["fts_body"] ?? ""
            let hasContent = !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            var entry = byKey[key] ?? (false, false, 0)
            entry.hasDaily = true
            entry.hasContent = entry.hasContent || hasContent
            byKey[key] = entry
        }

        let createdRows = try Row.fetchAll(
            db,
            sql: """
                SELECT created FROM objects
                WHERE created >= ? AND created < ?
                """,
            arguments: [start.timeIntervalSince1970, endExclusive.timeIntervalSince1970]
        )

        for row in createdRows {
            let created: Double = row["created"]
            let date = Date(timeIntervalSince1970: created)
            let key = DailyNoteIdentity.title(for: date, calendar: calendar)
            var entry = byKey[key] ?? (false, false, 0)
            entry.creations += 1
            byKey[key] = entry
        }

        return byKey.keys.sorted().map { key in
            let entry = byKey[key]!
            return CalendarDayMarker(
                dayKey: key,
                hasDailyNote: entry.hasDaily,
                hasContent: entry.hasContent,
                creationCount: entry.creations
            )
        }
    }

    private static func dayKey(fromDailyPath path: String) -> String? {
        // daily/YYYY-MM-DD.md
        guard path.hasPrefix("daily/"), path.hasSuffix(".md") else { return nil }
        let mid = path.dropFirst("daily/".count).dropLast(".md".count)
        guard mid.count == 10 else { return nil }
        return String(mid)
    }
}
