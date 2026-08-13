import Foundation
import GRDB
import LociCore

/// Objects whose `created` timestamp falls on a calendar day (local timezone).
enum CreatedOnQuery {
    static func created(db: Database, on day: Date, calendar: Calendar = .current) throws -> [LociObjectMeta] {
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        let rows = try Row.fetchAll(
            db,
            sql: """
                SELECT * FROM objects
                WHERE created >= ? AND created < ?
                ORDER BY created ASC, title COLLATE NOCASE ASC
                """,
            arguments: [start.timeIntervalSince1970, end.timeIntervalSince1970]
        )
        return try rows.map { try ObjectRowDecoder.decode($0) }
    }
}
