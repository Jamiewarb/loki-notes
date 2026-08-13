import Foundation

/// Per-type schema + templates + space.json. Implemented in PR05.
public protocol SchemaServing: Sendable {
    func loadSpaceSettings() async throws -> SpaceSettings
    func saveSpaceSettings(_ settings: SpaceSettings) async throws
    func knownTypeIDs() async throws -> [ObjectTypeID]
}
