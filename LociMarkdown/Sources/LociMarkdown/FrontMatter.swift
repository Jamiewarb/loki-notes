import Foundation
import LociCore

/// YAML frontmatter for a Loci object file (aligned with `LociObjectMeta`).
///
/// On-disk keys use `type` (not `typeID`). `relativePath` is a locator, not stored here.
public struct FrontMatter: Hashable, Sendable, Equatable {
    public var id: ObjectID
    public var typeID: ObjectTypeID
    public var title: String
    public var created: Date
    public var updated: Date
    public var tags: [String]
    public var properties: [String: PropertyValue]
    /// Optional template id from Part 4 document shape (`template: default-book`).
    public var template: String?

    public init(
        id: ObjectID,
        typeID: ObjectTypeID,
        title: String,
        created: Date = Date(),
        updated: Date = Date(),
        tags: [String] = [],
        properties: [String: PropertyValue] = [:],
        template: String? = nil
    ) {
        self.id = id
        self.typeID = typeID
        self.title = title
        self.created = created
        self.updated = updated
        self.tags = tags
        self.properties = properties
        self.template = template
    }

    public init(meta: LociObjectMeta, template: String? = nil) {
        self.init(
            id: meta.id,
            typeID: meta.typeID,
            title: meta.title,
            created: meta.created,
            updated: meta.updated,
            tags: meta.tags,
            properties: meta.properties,
            template: template
        )
    }

    public func toMeta(relativePath: String) -> LociObjectMeta {
        LociObjectMeta(
            id: id,
            typeID: typeID,
            title: title,
            created: created,
            updated: updated,
            relativePath: relativePath,
            tags: tags,
            properties: properties
        )
    }
}
