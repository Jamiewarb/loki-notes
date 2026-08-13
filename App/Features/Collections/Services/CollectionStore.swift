import Foundation
import LociCore

/// Thin feature-local facade over `SchemaServing` collection APIs (PR22).
///
/// Features must not import other features; composition injects `SchemaServing`.
public struct CollectionStore: Sendable {
    private let schema: any SchemaServing

    public init(schema: any SchemaServing) {
        self.schema = schema
    }

    public func list(typeID: ObjectTypeID) async throws -> [ObjectCollection] {
        try await schema.listCollections(typeID: typeID)
    }

    public func load(_ id: String) async throws -> ObjectCollection {
        try await schema.loadCollection(id)
    }

    public func save(_ collection: ObjectCollection) async throws -> ObjectCollection {
        try await schema.saveCollection(collection)
    }

    public func create(typeID: ObjectTypeID, name: String, slug: String?) async throws
        -> ObjectCollection
    {
        try await schema.createCollection(typeID: typeID, name: name, slug: slug)
    }

    public func delete(_ id: String) async throws {
        try await schema.deleteCollection(id)
    }

    public func add(collectionID: String, objectID: ObjectID) async throws -> ObjectCollection {
        try await schema.addToCollection(collectionID, objectID: objectID)
    }

    public func remove(collectionID: String, objectID: ObjectID) async throws -> ObjectCollection {
        try await schema.removeFromCollection(collectionID, objectID: objectID)
    }
}
