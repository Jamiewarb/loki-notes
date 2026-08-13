import Foundation
import LociCore
import LociMarkdown

/// Concrete `ObjectServing` — orchestrates vault writes, markdown, and index updates.
///
/// Features never touch vault paths or SQLite directly; they call this (or `IndexQuerying` for lists).
public final class ObjectService: ObjectServing, @unchecked Sendable {
    private let vault: any VaultServing
    private let query: any IndexQuerying
    private let update: any IndexUpdating
    private let parser = MarkdownParser()
    private let serializer = MarkdownSerializer()
    private let lock = NSLock()

    public init(
        vault: any VaultServing,
        query: any IndexQuerying,
        update: any IndexUpdating
    ) {
        self.vault = vault
        self.query = query
        self.update = update
    }

    /// Convenience when one service implements both index protocols (e.g. `IndexService`).
    public convenience init(
        vault: any VaultServing,
        index: some IndexQuerying & IndexUpdating
    ) {
        self.init(vault: vault, query: index, update: index)
    }

    // MARK: - ObjectServing

    public func create(typeID: ObjectTypeID, title: String) async throws -> LociObjectMeta {
        let id = ObjectID()
        let now = Date()
        let relativePath = try await ObjectPathAllocator.allocate(
            typeID: typeID,
            title: title,
            id: id,
            vault: vault
        )
        var meta = LociObjectMeta(
            id: id,
            typeID: typeID,
            title: title,
            created: now,
            updated: now,
            relativePath: relativePath
        )
        try await writeDocument(meta: meta, bodyMarkdown: "")
        try await update.applyVaultEvent(relativePath: relativePath, kind: .created)
        // Prefer index row (tags from body etc.) when available.
        if let indexed = try await query.object(id: id) {
            meta = indexed
        }
        return meta
    }

    public func open(id: ObjectID) async throws -> OpenedObject {
        let relativePath: String
        if let indexed = try await query.object(id: id) {
            relativePath = indexed.relativePath
        } else {
            throw LociError.objectNotFound(id)
        }

        let data = try await vault.readFile(atRelativePath: relativePath)
        guard let markdown = String(data: data, encoding: .utf8) else {
            throw LociError.fileNotFound(relativePath)
        }
        let document = try parser.parse(markdown)
        guard let frontMatter = document.frontMatter else {
            throw LociError.objectNotFound(id)
        }
        let meta = frontMatter.toMeta(relativePath: relativePath)
        let bodyMarkdown = serializer.serializeBlocks(document.blocks)
        return OpenedObject(meta: meta, bodyMarkdown: bodyMarkdown)
    }

    public func save(meta: LociObjectMeta, bodyMarkdown: String) async throws {
        var next = meta
        next.updated = Date()
        try await writeDocument(meta: next, bodyMarkdown: bodyMarkdown)
        try await update.applyVaultEvent(relativePath: next.relativePath, kind: .modified)
    }

    public func delete(id: ObjectID) async throws {
        guard let indexed = try await query.object(id: id) else {
            throw LociError.objectNotFound(id)
        }
        let path = indexed.relativePath
        _ = try await vault.trashFile(atRelativePath: path, objectID: id)
        try await update.applyVaultEvent(relativePath: path, kind: .deleted)
    }

    // MARK: - Internals

    private func writeDocument(meta: LociObjectMeta, bodyMarkdown: String) async throws {
        let bodyDoc = try parser.parse(bodyMarkdown)
        let document = LociDocument(
            frontMatter: FrontMatter(meta: meta),
            blocks: bodyDoc.blocks
        )
        let text = serializer.serialize(document)
        guard let data = text.data(using: .utf8) else {
            throw LociError.coordinationFailed("utf8 encode failed for \(meta.relativePath)")
        }
        try await vault.writeFile(data, atRelativePath: meta.relativePath)
    }
}

/// Module version bump for PR08 Object CRUD.
extension LociVaultModule {
    /// Alias kept for demo JSON `moduleVersion` field.
    public static var objectCRUDVersion: String { version }
}
