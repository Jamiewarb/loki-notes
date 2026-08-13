import Foundation
import GRDB
import LociCore

/// Read helpers for the disposable `tasks` projection (PR19).
enum TasksQuery {
    static func tasks(db: Database, completed: Bool?) throws -> [IndexedTask] {
        let sql: String
        let arguments: StatementArguments
        if let completed {
            sql = """
                SELECT t.object_id, t.block_index, t.item_index, t.text, t.completed,
                       o.title, o.type_id, o.relative_path
                FROM tasks t
                JOIN objects o ON o.id = t.object_id
                WHERE t.completed = ?
                ORDER BY t.completed ASC, o.title COLLATE NOCASE ASC, t.block_index ASC, t.item_index ASC
                """
            arguments = [completed ? 1 : 0]
        } else {
            sql = """
                SELECT t.object_id, t.block_index, t.item_index, t.text, t.completed,
                       o.title, o.type_id, o.relative_path
                FROM tasks t
                JOIN objects o ON o.id = t.object_id
                ORDER BY t.completed ASC, o.title COLLATE NOCASE ASC, t.block_index ASC, t.item_index ASC
                """
            arguments = []
        }
        let rows = try Row.fetchAll(db, sql: sql, arguments: arguments)
        return try rows.map { try decode($0) }
    }

    static func tasks(db: Database, relativePath: String) throws -> [IndexedTask] {
        let rows = try Row.fetchAll(
            db,
            sql: """
                SELECT t.object_id, t.block_index, t.item_index, t.text, t.completed,
                       o.title, o.type_id, o.relative_path
                FROM tasks t
                JOIN objects o ON o.id = t.object_id
                WHERE o.relative_path = ?
                ORDER BY t.completed ASC, t.block_index ASC, t.item_index ASC
                """,
            arguments: [relativePath]
        )
        return try rows.map { try decode($0) }
    }

    static func replaceTasks(db: Database, objectID: ObjectID, tasks: [ExtractedTask]) throws {
        let id = objectID.uuidString.lowercased()
        try db.execute(sql: "DELETE FROM tasks WHERE object_id = ?", arguments: [id])
        for task in tasks {
            try db.execute(
                sql: """
                    INSERT INTO tasks (object_id, block_index, item_index, text, completed)
                    VALUES (?, ?, ?, ?, ?)
                    """,
                arguments: [
                    id,
                    task.blockIndex,
                    task.itemIndex,
                    task.text,
                    task.isCompleted ? 1 : 0,
                ]
            )
        }
    }

    private static func decode(_ row: Row) throws -> IndexedTask {
        let idString: String = row["object_id"]
        guard let objectID = ObjectID(parsing: idString) else {
            throw LociError.invalidObjectID(idString)
        }
        let typeRaw: String = row["type_id"]
        let completed: Int = row["completed"]
        return IndexedTask(
            objectID: objectID,
            objectTitle: row["title"],
            objectTypeID: ObjectTypeID(typeRaw),
            relativePath: row["relative_path"],
            blockIndex: row["block_index"],
            itemIndex: row["item_index"],
            text: row["text"],
            isCompleted: completed != 0
        )
    }
}

/// Raw task extracted from BlockAST before join with object meta.
struct ExtractedTask: Sendable, Equatable {
    var blockIndex: Int
    var itemIndex: Int
    var text: String
    var isCompleted: Bool
}
