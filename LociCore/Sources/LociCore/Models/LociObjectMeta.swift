import Foundation

/// Lightweight object metadata shared across packages. Full body lives in markdown files.
public struct LociObjectMeta: Hashable, Sendable, Codable, Equatable {
    public var id: ObjectID
    public var typeID: ObjectTypeID
    public var title: String
    public var created: Date
    public var updated: Date
    public var relativePath: String
    public var tags: [String]
    public var properties: [String: PropertyValue]

    public init(
        id: ObjectID,
        typeID: ObjectTypeID,
        title: String,
        created: Date = Date(),
        updated: Date = Date(),
        relativePath: String,
        tags: [String] = [],
        properties: [String: PropertyValue] = [:]
    ) {
        self.id = id
        self.typeID = typeID
        self.title = title
        self.created = created
        self.updated = updated
        self.relativePath = relativePath
        self.tags = tags
        self.properties = properties
    }

    private enum CodingKeys: String, CodingKey {
        case id, typeID, title, created, updated, relativePath, tags, properties
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(ObjectID.self, forKey: .id)
        typeID = try container.decode(ObjectTypeID.self, forKey: .typeID)
        title = try container.decode(String.self, forKey: .title)
        created = try container.decode(Date.self, forKey: .created)
        updated = try container.decode(Date.self, forKey: .updated)
        relativePath = try container.decode(String.self, forKey: .relativePath)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        properties =
            try container.decodeIfPresent([String: PropertyValue].self, forKey: .properties) ?? [:]
    }
}
