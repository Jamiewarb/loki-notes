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

    /// Create a custom type on the fly (PR12). Writes `.loci/types/<slug>.json`
    /// and ensures `objects/<slug>/`. Properties may be empty until PR13.
    func createType(
        name: String,
        icon: String,
        color: String,
        slug: String?
    ) async throws -> ObjectType

    /// Rename display name (and optionally icon/color via `saveType`). Id/slug stays stable.
    func renameType(_ id: ObjectTypeID, name: String) async throws -> ObjectType

    /// Delete a custom type. Refuses built-in Page/Daily. Refuses non-empty
    /// `objects/<slug>/` unless `force` (then schema JSON only is removed).
    func deleteType(_ id: ObjectTypeID, force: Bool) async throws
}
