import Foundation
import GRDB
import LociCore

/// Filter DSL executor over the disposable SQLite index (PR23).
///
/// Builds SQL from `QueryDefinition` (type, tags, property ops, created/updated ranges).
/// Results are derived — never write them into vault markdown by default.
enum QueryEngine {
    static func execute(db: Database, definition: QueryDefinition) throws -> [LociObjectMeta] {
        var sql = """
            SELECT DISTINCT o.* FROM objects o
            """
        var joins: [String] = []
        var whereClauses: [String] = ["1=1"]
        // JOIN placeholders appear before WHERE in the final SQL — keep args in that order.
        var joinArgs = StatementArguments()
        var whereArgs = StatementArguments()

        if let typeID = definition.typeID {
            whereClauses.append("o.type_id = ?")
            whereArgs += [typeID.rawValue]
        }

        if let created = definition.created, !created.isEmpty {
            if let from = created.from {
                whereClauses.append("o.created >= ?")
                whereArgs += [from.timeIntervalSince1970]
            }
            if let to = created.to {
                whereClauses.append("o.created <= ?")
                whereArgs += [to.timeIntervalSince1970]
            }
        }

        if let updated = definition.updated, !updated.isEmpty {
            if let from = updated.from {
                whereClauses.append("o.updated >= ?")
                whereArgs += [from.timeIntervalSince1970]
            }
            if let to = updated.to {
                whereClauses.append("o.updated <= ?")
                whereArgs += [to.timeIntervalSince1970]
            }
        }

        let normalizedTags = definition.tags
            .map { TagNormalization.normalize($0) }
            .filter { !$0.isEmpty }

        if !normalizedTags.isEmpty {
            switch definition.tagMode {
            case .all:
                for (i, tag) in normalizedTags.enumerated() {
                    let alias = "t\(i)"
                    joins.append(
                        "INNER JOIN tags \(alias) ON \(alias).object_id = o.id AND \(alias).tag = ?"
                    )
                    joinArgs += [tag]
                }
            case .any:
                let placeholders = Array(repeating: "?", count: normalizedTags.count)
                    .joined(separator: ", ")
                whereClauses.append(
                    """
                    EXISTS (
                      SELECT 1 FROM tags tx
                      WHERE tx.object_id = o.id AND tx.tag IN (\(placeholders))
                    )
                    """
                )
                for tag in normalizedTags {
                    whereArgs += [tag]
                }
            }
        }

        for (i, filter) in definition.properties.enumerated() {
            let key = filter.key.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { continue }
            let alias = "p\(i)"
            switch filter.op {
            case .exists:
                whereClauses.append(
                    """
                    EXISTS (
                      SELECT 1 FROM properties_idx \(alias)
                      WHERE \(alias).object_id = o.id AND \(alias).key = ?
                    )
                    """
                )
                whereArgs += [key]
            case .notExists:
                whereClauses.append(
                    """
                    NOT EXISTS (
                      SELECT 1 FROM properties_idx \(alias)
                      WHERE \(alias).object_id = o.id AND \(alias).key = ?
                    )
                    """
                )
                whereArgs += [key]
            case .equals:
                if let bool = filter.bool {
                    joins.append(
                        """
                        INNER JOIN properties_idx \(alias)
                          ON \(alias).object_id = o.id
                         AND \(alias).key = ?
                         AND \(alias).value_bool = ?
                        """
                    )
                    joinArgs += [key, bool ? 1 : 0]
                } else if let number = filter.number {
                    joins.append(
                        """
                        INNER JOIN properties_idx \(alias)
                          ON \(alias).object_id = o.id
                         AND \(alias).key = ?
                         AND \(alias).value_number = ?
                        """
                    )
                    joinArgs += [key, number]
                } else {
                    let text = filter.text ?? ""
                    joins.append(
                        """
                        INNER JOIN properties_idx \(alias)
                          ON \(alias).object_id = o.id
                         AND \(alias).key = ?
                         AND \(alias).value_text = ?
                        """
                    )
                    joinArgs += [key, text]
                }
            case .notEquals:
                let text = filter.text ?? ""
                whereClauses.append(
                    """
                    NOT EXISTS (
                      SELECT 1 FROM properties_idx \(alias)
                      WHERE \(alias).object_id = o.id
                        AND \(alias).key = ?
                        AND \(alias).value_text = ?
                    )
                    """
                )
                whereArgs += [key, text]
            case .contains:
                let text = filter.text ?? ""
                joins.append(
                    """
                    INNER JOIN properties_idx \(alias)
                      ON \(alias).object_id = o.id
                     AND \(alias).key = ?
                     AND \(alias).value_text LIKE ?
                    """
                )
                joinArgs += [key, "%\(text)%"]
            case .greaterThan:
                guard let number = filter.number else { continue }
                joins.append(
                    """
                    INNER JOIN properties_idx \(alias)
                      ON \(alias).object_id = o.id
                     AND \(alias).key = ?
                     AND \(alias).value_number > ?
                    """
                )
                joinArgs += [key, number]
            case .greaterThanOrEqual:
                guard let number = filter.number else { continue }
                joins.append(
                    """
                    INNER JOIN properties_idx \(alias)
                      ON \(alias).object_id = o.id
                     AND \(alias).key = ?
                     AND \(alias).value_number >= ?
                    """
                )
                joinArgs += [key, number]
            case .lessThan:
                guard let number = filter.number else { continue }
                joins.append(
                    """
                    INNER JOIN properties_idx \(alias)
                      ON \(alias).object_id = o.id
                     AND \(alias).key = ?
                     AND \(alias).value_number < ?
                    """
                )
                joinArgs += [key, number]
            case .lessThanOrEqual:
                guard let number = filter.number else { continue }
                joins.append(
                    """
                    INNER JOIN properties_idx \(alias)
                      ON \(alias).object_id = o.id
                     AND \(alias).key = ?
                     AND \(alias).value_number <= ?
                    """
                )
                joinArgs += [key, number]
            }
        }

        if !joins.isEmpty {
            sql += "\n" + joins.joined(separator: "\n")
        }
        sql += "\nWHERE " + whereClauses.joined(separator: " AND ")
        sql += "\nORDER BY " + orderSQL(definition.sort)
        if let limit = definition.limit, limit > 0 {
            sql += "\nLIMIT \(limit)"
        }

        var args = joinArgs
        args += whereArgs
        let rows = try Row.fetchAll(db, sql: sql, arguments: args)
        return try rows.map { try ObjectRowDecoder.decode($0) }
    }

    private static func orderSQL(_ sort: QuerySort) -> String {
        switch sort {
        case .titleAsc:
            return "o.title COLLATE NOCASE ASC"
        case .titleDesc:
            return "o.title COLLATE NOCASE DESC"
        case .updatedDesc:
            return "o.updated DESC"
        case .updatedAsc:
            return "o.updated ASC"
        case .createdDesc:
            return "o.created DESC"
        case .createdAsc:
            return "o.created ASC"
        }
    }
}
