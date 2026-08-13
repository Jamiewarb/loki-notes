import Foundation

/// High-level object CRUD. Single orchestration entry for features (PR08).
public protocol ObjectServing: Sendable {
    func create(typeID: ObjectTypeID, title: String) async throws -> LociObjectMeta
    func open(id: ObjectID) async throws -> LociObjectMeta
    func save(meta: LociObjectMeta, bodyMarkdown: String) async throws
    func delete(id: ObjectID) async throws
}
