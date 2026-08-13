import Foundation

/// Read-only derived index queries. Index DB lives in Application Support only — never in the vault.
public protocol IndexQuerying: Sendable {
    func object(id: ObjectID) async throws -> LociObjectMeta?
    func objects(typeID: ObjectTypeID) async throws -> [LociObjectMeta]
    func search(query: String) async throws -> [LociObjectMeta]
    func created(on day: Date) async throws -> [LociObjectMeta]
}
