import Foundation

/// Per-type schema files + space.json. Implementations live beside Vault (PR05).
/// Prefer `.loci/types/<slug>.json` — never a monolithic schema.json rewrite.
public protocol SchemaServing: Sendable {
    func loadSpaceSettings() async throws -> SpaceSettings
    func saveSpaceSettings(_ settings: SpaceSettings) async throws

    func knownTypeIDs() async throws -> [ObjectTypeID]
    func loadType(_ id: ObjectTypeID) async throws -> ObjectType
    func saveType(_ type: ObjectType) async throws
    func allTypes() async throws -> [ObjectType]

    /// Ensure vault skeleton + seed built-in Page (and space.json if missing).
    func bootstrapSchema(spaceName: String) async throws
}
