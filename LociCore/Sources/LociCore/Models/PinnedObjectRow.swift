import Foundation

/// Sidebar / inspector display row for a pinned object (PR34).
///
/// Identity comes from space.json; title/type/path are resolved from the index
/// (or `ObjectServing.open`). Missing objects stay pinned and can still be unpinned.
public struct PinnedObjectRow: Hashable, Sendable, Identifiable, Equatable {
    public var id: ObjectID
    public var title: String
    public var typeID: ObjectTypeID?
    public var relativePath: String?
    public var isMissing: Bool

    public init(
        id: ObjectID,
        title: String,
        typeID: ObjectTypeID? = nil,
        relativePath: String? = nil,
        isMissing: Bool = false
    ) {
        self.id = id
        self.title = title
        self.typeID = typeID
        self.relativePath = relativePath
        self.isMissing = isMissing
    }

    /// Unresolved pin — still listed so the user can unpin it.
    public static func missing(_ id: ObjectID) -> PinnedObjectRow {
        PinnedObjectRow(
            id: id,
            title: "Missing pin",
            typeID: nil,
            relativePath: nil,
            isMissing: true
        )
    }

    public static func resolved(_ meta: LociObjectMeta) -> PinnedObjectRow {
        PinnedObjectRow(
            id: meta.id,
            title: meta.title.isEmpty ? meta.id.frontMatterIDString : meta.title,
            typeID: meta.typeID,
            relativePath: meta.relativePath,
            isMissing: false
        )
    }

    /// Type slug, or “Missing pin” when the object cannot be resolved.
    public var subtitle: String {
        if isMissing { return "Missing pin" }
        return typeID?.rawValue ?? "object"
    }
}
