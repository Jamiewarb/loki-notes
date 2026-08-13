import Foundation
import GRDB
import LociCore
import LociMarkdown

/// Concrete `IndexQuerying` + `IndexUpdating` backed by GRDB/SQLite.
///
/// The index database is opened under `IndexDatabase.directory` (Application Support or tests) —
/// never under the vault root.
public final class IndexService: IndexQuerying, IndexUpdating, @unchecked Sendable {
    private let vault: any VaultServing
    private let database: IndexDatabase
    private let dbQueue: DatabaseQueue
    private let lock = NSLock()

    public var databaseURL: URL { database.databaseURL }
    public var vaultID: String { database.vaultID }

    public init(vault: any VaultServing, database: IndexDatabase) throws {
        self.vault = vault
        self.database = database
        self.dbQueue = try database.open()
    }

    /// Convenience: derive vaultID from vault root and place the DB under `indexDirectory`.
    public convenience init(vault: any VaultServing, indexDirectory: URL) async throws {
        let root = try await vault.vaultRootURL
        let id = IndexDatabase.vaultID(forVaultRoot: root)
        try self.init(vault: vault, database: IndexDatabase(vaultID: id, directory: indexDirectory))
    }

    // MARK: - IndexQuerying

    public func object(id: ObjectID) async throws -> LociObjectMeta? {
        let key = id.uuidString.lowercased()
        return try await dbQueue.read { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM objects WHERE id = ?", arguments: [key])
            else { return nil }
            return try ObjectRowDecoder.decode(row)
        }
    }

    public func objects(typeID: ObjectTypeID) async throws -> [LociObjectMeta] {
        try await dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                    SELECT * FROM objects
                    WHERE type_id = ?
                    ORDER BY title COLLATE NOCASE ASC
                    """,
                arguments: [typeID.rawValue]
            )
            return try rows.map { try ObjectRowDecoder.decode($0) }
        }
    }

    public func search(query: String) async throws -> [LociObjectMeta] {
        try await dbQueue.read { db in
            try SearchQuery.search(db: db, query: query)
        }
    }

    public func created(on day: Date) async throws -> [LociObjectMeta] {
        try await dbQueue.read { db in
            try CreatedOnQuery.created(db: db, on: day)
        }
    }

    public func objects(
        typeID: ObjectTypeID?,
        propertyKey: String,
        equalsText: String
    ) async throws -> [LociObjectMeta] {
        try await dbQueue.read { db in
            try PropertiesQuery.objects(
                db: db,
                typeID: typeID,
                propertyKey: propertyKey,
                equalsText: equalsText
            )
        }
    }

    public func propertyIndex(objectID: ObjectID) async throws -> [PropertyIndexRow] {
        try await dbQueue.read { db in
            try PropertiesQuery.propertyIndex(db: db, objectID: objectID)
        }
    }

    public func resolve(wikiTarget: String) async throws -> LociObjectMeta? {
        try await dbQueue.read { db in
            try LinkResolver.resolve(db: db, target: wikiTarget)
        }
    }

    public func backlinks(to objectID: ObjectID) async throws -> [BacklinkRecord] {
        try await dbQueue.read { db in
            try LinksQuery.backlinks(db: db, to: objectID)
        }
    }

    public func outgoingLinks(from objectID: ObjectID) async throws -> [ResolvedWikiLink] {
        try await dbQueue.read { db in
            try LinksQuery.outgoing(db: db, from: objectID)
        }
    }

    public func linkCandidates(
        matching query: String,
        excluding excludeID: ObjectID?,
        limit: Int
    ) async throws -> [LociObjectMeta] {
        try await dbQueue.read { db in
            try LinksQuery.candidates(
                db: db,
                matching: query,
                excluding: excludeID,
                limit: limit
            )
        }
    }

    public func allTags(aliases: TagAliasTable, limit: Int) async throws -> [TagSummary] {
        try await dbQueue.read { db in
            try TagsQuery.allTags(db: db, aliases: aliases, limit: limit)
        }
    }

    public func objects(
        tagged tag: String,
        typeID: ObjectTypeID?,
        aliases: TagAliasTable
    ) async throws -> [LociObjectMeta] {
        try await dbQueue.read { db in
            try TagsQuery.objects(db: db, tagged: tag, typeID: typeID, aliases: aliases)
        }
    }

    public func tagCandidates(
        matching query: String,
        aliases: TagAliasTable,
        limit: Int
    ) async throws -> [TagSummary] {
        try await dbQueue.read { db in
            try TagsQuery.candidates(db: db, matching: query, aliases: aliases, limit: limit)
        }
    }

    public func tasks(completed: Bool?) async throws -> [IndexedTask] {
        try await dbQueue.read { db in
            try TasksQuery.tasks(db: db, completed: completed)
        }
    }

    public func openTasks() async throws -> [IndexedTask] {
        try await tasks(completed: false)
    }

    public func tasks(inDailyNoteOn day: Date, calendar: Calendar = .current) async throws
        -> [IndexedTask]
    {
        let path = DailyNoteIdentity.relativePath(for: day, calendar: calendar)
        return try await dbQueue.read { db in
            try TasksQuery.tasks(db: db, relativePath: path)
        }
    }

    // MARK: - IndexUpdating

    public func rebuild() async throws {
        let paths = try await Self.discoverMarkdownPaths(vault: vault)
        try await dbQueue.write { db in
            try db.execute(sql: "DELETE FROM links")
            try db.execute(sql: "DELETE FROM tags")
            try db.execute(sql: "DELETE FROM properties_idx")
            try db.execute(sql: "DELETE FROM tasks")
            try db.execute(sql: "DELETE FROM blocks_fts")
            try db.execute(sql: "DELETE FROM objects")
        }
        for path in paths {
            try await indexFile(atRelativePath: path)
        }
    }

    public func applyVaultEvent(relativePath: String, kind: VaultEventKind) async throws {
        let normalized = Self.normalizeRelativePath(relativePath)
        guard Self.isIndexableMarkdown(normalized) else { return }

        switch kind {
        case .created, .modified, .renamed:
            let exists = try await vault.fileExists(atRelativePath: normalized)
            if exists {
                try await indexFile(atRelativePath: normalized)
            } else {
                try await removeByRelativePath(normalized)
            }
        case .deleted:
            try await removeByRelativePath(normalized)
        }
    }

    // MARK: - Internals

    private func indexFile(atRelativePath path: String) async throws {
        let data = try await vault.readFile(atRelativePath: path)
        guard let markdown = String(data: data, encoding: .utf8) else { return }
        guard let extracted = try ObjectIndexer.extract(relativePath: path, markdown: markdown) else {
            // Markdown without frontmatter is not a Loci object — ignore for index.
            return
        }
        try await upsert(extracted)
    }

    private func upsert(_ doc: IndexedDocument) async throws {
        let meta = doc.meta
        let id = meta.id.uuidString.lowercased()
        let tagsJSON = String(data: try JSONEncoder().encode(meta.tags), encoding: .utf8) ?? "[]"
        let propsJSON = String(data: try JSONEncoder().encode(meta.properties), encoding: .utf8) ?? "{}"

        try await dbQueue.write { db in
            // If another object previously owned this path, drop it first.
            if let existingPathOwner = try String.fetchOne(
                db,
                sql: "SELECT id FROM objects WHERE relative_path = ?",
                arguments: [meta.relativePath]
            ), existingPathOwner != id {
                try Self.deleteObject(db: db, id: existingPathOwner)
            }

            // Replace prior rows for this object id.
            try Self.deleteObject(db: db, id: id)

            try db.execute(
                sql: """
                    INSERT INTO objects
                      (id, type_id, title, created, updated, relative_path, tags_json, properties_json)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    id,
                    meta.typeID.rawValue,
                    meta.title,
                    meta.created.timeIntervalSince1970,
                    meta.updated.timeIntervalSince1970,
                    meta.relativePath,
                    tagsJSON,
                    propsJSON,
                ]
            )

            for tag in meta.tags {
                let normalized = TagNormalization.normalize(tag)
                guard !normalized.isEmpty else { continue }
                try db.execute(
                    sql: "INSERT OR IGNORE INTO tags (object_id, tag) VALUES (?, ?)",
                    arguments: [id, normalized]
                )
            }

            try LinkIndexer.replaceLinks(db: db, sourceID: meta.id, links: doc.wikiLinks)
            try TasksQuery.replaceTasks(db: db, objectID: meta.id, tasks: doc.tasks)
            try Self.writeProperties(db: db, objectID: id, properties: meta.properties)

            try db.execute(
                sql: "INSERT INTO blocks_fts (object_id, title, body) VALUES (?, ?, ?)",
                arguments: [id, meta.title, doc.bodyText]
            )
        }
    }

    private func removeByRelativePath(_ path: String) async throws {
        try await dbQueue.write { db in
            guard let id = try String.fetchOne(
                db,
                sql: "SELECT id FROM objects WHERE relative_path = ?",
                arguments: [path]
            ) else { return }
            try Self.deleteObject(db: db, id: id)
        }
    }

    private static func deleteObject(db: Database, id: String) throws {
        try db.execute(sql: "DELETE FROM links WHERE source_id = ?", arguments: [id])
        try db.execute(sql: "DELETE FROM tags WHERE object_id = ?", arguments: [id])
        try db.execute(sql: "DELETE FROM properties_idx WHERE object_id = ?", arguments: [id])
        try db.execute(sql: "DELETE FROM tasks WHERE object_id = ?", arguments: [id])
        try db.execute(sql: "DELETE FROM blocks_fts WHERE object_id = ?", arguments: [id])
        try db.execute(sql: "DELETE FROM objects WHERE id = ?", arguments: [id])
    }

    private static func writeProperties(
        db: Database,
        objectID: String,
        properties: [String: PropertyValue]
    ) throws {
        for (key, value) in properties {
            var text: String?
            var number: Double?
            var boolVal: Int?
            var dateVal: Double?
            switch value {
            case .text(let s), .url(let s), .select(let s):
                text = s
            case .number(let n):
                number = n
                text = String(n)
            case .bool(let b):
                boolVal = b ? 1 : 0
                text = b ? "true" : "false"
            case .date(let d):
                dateVal = d.timeIntervalSince1970
                text = ISO8601DateFormatter().string(from: d)
            case .multiSelect(let arr), .objectSelect(let arr):
                text = arr.joined(separator: ",")
            case .null:
                text = nil
            }
            try db.execute(
                sql: """
                    INSERT INTO properties_idx
                      (object_id, key, value_text, value_number, value_bool, value_date)
                    VALUES (?, ?, ?, ?, ?, ?)
                    """,
                arguments: [objectID, key, text, number, boolVal, dateVal]
            )
        }
    }

    /// Enumerate vault-relative `.md` paths under `daily/` and `objects/` (skips `.loci/`).
    public static func discoverMarkdownPaths(vault: any VaultServing) async throws -> [String] {
        let root = try await vault.vaultRootURL
        var results: [String] = []
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        for case let url as URL in enumerator {
            let relative = url.path.replacingOccurrences(of: root.path + "/", with: "")
            if relative.hasPrefix(".") || relative.hasPrefix(".loci/") { continue }
            // Skip enumerator diving into .loci if somehow not hidden
            if relative.split(separator: "/").contains(where: { $0.hasPrefix(".") }) { continue }
            guard relative.hasSuffix(".md") else { continue }
            guard isIndexableMarkdown(relative) else { continue }
            var isFile: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isFile), !isFile.boolValue else {
                continue
            }
            results.append(normalizeRelativePath(relative))
        }
        return results.sorted()
    }

    static func isIndexableMarkdown(_ relativePath: String) -> Bool {
        let path = normalizeRelativePath(relativePath)
        guard path.hasSuffix(".md") else { return false }
        if path.hasPrefix(".loci/") { return false }
        return path.hasPrefix("daily/") || path.hasPrefix("objects/")
    }

    static func normalizeRelativePath(_ path: String) -> String {
        var p = path
        while p.hasPrefix("./") { p = String(p.dropFirst(2)) }
        while p.hasPrefix("/") { p = String(p.dropFirst()) }
        return p
    }
}
