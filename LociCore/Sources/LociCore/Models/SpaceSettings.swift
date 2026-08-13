import Foundation

/// Space-level settings persisted as `.loci/space.json` (PR05).
public struct SpaceSettings: Hashable, Sendable, Codable {
    public var name: String
    public var schemaVersion: Int

    public init(name: String = "Loci", schemaVersion: Int = 1) {
        self.name = name
        self.schemaVersion = schemaVersion
    }
}
