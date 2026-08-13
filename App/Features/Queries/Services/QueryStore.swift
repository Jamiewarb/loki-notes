import Foundation
import LociCore

/// Thin feature-local facade over SchemaServing + IndexQuerying (PR23).
///
/// Features must not import other features; composition injects protocols.
public struct QueryStore: Sendable {
    private let schema: any SchemaServing
    private let index: (any IndexQuerying)?

    public init(schema: any SchemaServing, index: (any IndexQuerying)?) {
        self.schema = schema
        self.index = index
    }

    public func list() async throws -> [SavedQuery] {
        try await schema.listQueries()
    }

    public func listPinned(typeID: ObjectTypeID) async throws -> [SavedQuery] {
        try await schema.listPinnedQueries(typeID: typeID)
    }

    public func load(_ id: String) async throws -> SavedQuery {
        try await schema.loadQuery(id)
    }

    public func save(_ query: SavedQuery) async throws -> SavedQuery {
        try await schema.saveQuery(query)
    }

    public func create(
        name: String,
        definition: QueryDefinition,
        slug: String?,
        pinnedTypeID: ObjectTypeID?
    ) async throws -> SavedQuery {
        try await schema.createQuery(
            name: name,
            definition: definition,
            slug: slug,
            pinnedTypeID: pinnedTypeID
        )
    }

    public func delete(_ id: String) async throws {
        try await schema.deleteQuery(id)
    }

    public func setPinned(_ id: String, typeID: ObjectTypeID?) async throws -> SavedQuery {
        try await schema.setQueryPinned(id, typeID: typeID)
    }

    /// Run a saved query — results derived from index only.
    public func execute(_ query: SavedQuery) async throws -> [LociObjectMeta] {
        guard let index else { return [] }
        return try await index.execute(query.definition)
    }

    public func execute(definition: QueryDefinition) async throws -> [LociObjectMeta] {
        guard let index else { return [] }
        return try await index.execute(definition)
    }
}
