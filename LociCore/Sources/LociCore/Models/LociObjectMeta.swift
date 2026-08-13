import Foundation

/// Lightweight object metadata shared across packages. Full body lives in markdown files.
public struct LociObjectMeta: Hashable, Sendable, Codable {
    public var id: ObjectID
    public var typeID: ObjectTypeID
    public var title: String
    public var created: Date
    public var updated: Date
    public var relativePath: String

    public init(
        id: ObjectID,
        typeID: ObjectTypeID,
        title: String,
        created: Date = Date(),
        updated: Date = Date(),
        relativePath: String
    ) {
        self.id = id
        self.typeID = typeID
        self.title = title
        self.created = created
        self.updated = updated
        self.relativePath = relativePath
    }
}
