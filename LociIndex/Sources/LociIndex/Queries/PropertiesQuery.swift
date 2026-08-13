import Foundation
import GRDB
import LociCore

/// Query helpers for `properties_idx` (filter/sort foundation for type dashboards).
enum PropertiesQuery {
    static func objects(
        db: Database,
        typeID: ObjectTypeID?,
        propertyKey: String,
        equalsText: String
    ) throws -> [LociObjectMeta] {
        let sql: String
        let args: StatementArguments
        if let typeID {
            sql = """
                SELECT o.* FROM objects o
                INNER JOIN properties_idx p ON p.object_id = o.id
                WHERE p.key = ? AND p.value_text = ? AND o.type_id = ?
                ORDER BY o.title COLLATE NOCASE ASC
                """
            args = [propertyKey, equalsText, typeID.rawValue]
        } else {
            sql = """
                SELECT o.* FROM objects o
                INNER JOIN properties_idx p ON p.object_id = o.id
                WHERE p.key = ? AND p.value_text = ?
                ORDER BY o.title COLLATE NOCASE ASC
                """
            args = [propertyKey, equalsText]
        }
        let rows = try Row.fetchAll(db, sql: sql, arguments: args)
        return try rows.map { try ObjectRowDecoder.decode($0) }
    }

    static func propertyIndex(db: Database, objectID: ObjectID) throws -> [PropertyIndexRow] {
        let key = objectID.uuidString.lowercased()
        let rows = try Row.fetchAll(
            db,
            sql: """
                SELECT key, value_text, value_number, value_bool, value_date
                FROM properties_idx
                WHERE object_id = ?
                ORDER BY key ASC
                """,
            arguments: [key]
        )
        return rows.map { row in
            let boolRaw: Int? = row["value_bool"]
            let dateRaw: Double? = row["value_date"]
            return PropertyIndexRow(
                key: row["key"],
                valueText: row["value_text"],
                valueNumber: row["value_number"],
                valueBool: boolRaw.map { $0 != 0 },
                valueDate: dateRaw.map { Date(timeIntervalSince1970: $0) }
            )
        }
    }
}
