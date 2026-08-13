import Foundation

/// Space-level settings persisted as `.loci/space.json` (small, rare writes).
public struct SpaceSettings: Hashable, Sendable, Codable, Equatable {
    public var name: String
    public var schemaVersion: Int
    /// Pinned object id strings (ObjectID uuid) or type slugs — UI interprets later.
    public var pins: [String]

    public init(
        name: String = "Loci",
        schemaVersion: Int = 1,
        pins: [String] = []
    ) {
        self.name = name
        self.schemaVersion = schemaVersion
        self.pins = pins
    }

    private enum CodingKeys: String, CodingKey {
        case name, schemaVersion, pins
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Loci"
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        pins = try container.decodeIfPresent([String].self, forKey: .pins) ?? []
    }
}
