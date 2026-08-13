import Foundation

/// Space-level settings persisted as `.loci/space.json` (small, rare writes).
public struct SpaceSettings: Hashable, Sendable, Codable, Equatable {
    public var name: String
    public var schemaVersion: Int
    /// Pinned object id strings (ObjectID uuid) or type slugs — UI interprets later.
    public var pins: [String]
    /// PARA starter pack applied (PR15). Idempotent re-apply is safe.
    public var paraPackApplied: Bool
    /// When true, type dashboards / lists hide `#archive` / status=Archived by default.
    public var hideArchived: Bool
    /// Documented approach: `tag:#resource` (no dedicated Resource type).
    public var resourceApproach: String?
    /// Documented approach: `tag:#archive` (never a folder move).
    public var archiveApproach: String?

    public init(
        name: String = "Loci",
        schemaVersion: Int = 1,
        pins: [String] = [],
        paraPackApplied: Bool = false,
        hideArchived: Bool = false,
        resourceApproach: String? = nil,
        archiveApproach: String? = nil
    ) {
        self.name = name
        self.schemaVersion = schemaVersion
        self.pins = pins
        self.paraPackApplied = paraPackApplied
        self.hideArchived = hideArchived
        self.resourceApproach = resourceApproach
        self.archiveApproach = archiveApproach
    }

    private enum CodingKeys: String, CodingKey {
        case name, schemaVersion, pins, paraPackApplied, hideArchived, resourceApproach,
            archiveApproach
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Loci"
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        pins = try container.decodeIfPresent([String].self, forKey: .pins) ?? []
        paraPackApplied = try container.decodeIfPresent(Bool.self, forKey: .paraPackApplied) ?? false
        hideArchived = try container.decodeIfPresent(Bool.self, forKey: .hideArchived) ?? false
        resourceApproach = try container.decodeIfPresent(String.self, forKey: .resourceApproach)
        archiveApproach = try container.decodeIfPresent(String.self, forKey: .archiveApproach)
    }
}
