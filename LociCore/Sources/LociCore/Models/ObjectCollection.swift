import Foundation

/// Manual curated group *within* one object type (PR22).
///
/// Vault truth: one merge-friendly file per collection under
/// `.loci/collections/<type>.<slug>.json`. Membership is an ordered list of
/// object ids — not derived from the index.
public struct ObjectCollection: Hashable, Sendable, Codable, Equatable {
    public var id: String
    public var typeID: ObjectTypeID
    public var name: String
    /// Ordered membership (vault source of truth).
    public var memberIDs: [ObjectID]
    public var updatedAt: Date

    public init(
        id: String,
        typeID: ObjectTypeID,
        name: String,
        memberIDs: [ObjectID] = [],
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.typeID = typeID
        self.name = name
        self.memberIDs = memberIDs
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, typeID, name, memberIDs, updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        typeID = try container.decode(ObjectTypeID.self, forKey: .typeID)
        name = try container.decode(String.self, forKey: .name)
        let rawMembers = try container.decodeIfPresent([String].self, forKey: .memberIDs) ?? []
        memberIDs = rawMembers.compactMap { ObjectID(parsing: $0) }
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(typeID, forKey: .typeID)
        try container.encode(name, forKey: .name)
        try container.encode(memberIDs.map(\.frontMatterIDString), forKey: .memberIDs)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

/// Helpers for collection ids (`book.favorites`, `page.inbox`).
public enum CollectionID: Sendable {
    /// Normalize a raw id fragment (lowercase, hyphenated).
    public static func normalize(_ raw: String) -> String {
        TypeSlug.normalize(raw)
    }

    /// Build `<type>.<slug>` id. Slug defaults from name when blank.
    public static func make(
        typeID: ObjectTypeID,
        name: String,
        explicitSlug: String? = nil
    ) throws -> String {
        let slug: String
        if let explicitSlug, !explicitSlug.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            slug = normalize(explicitSlug)
        } else {
            slug = TypeSlug.fromName(name)
        }
        guard !slug.isEmpty else {
            throw LociError.invalidCollectionID("(empty)")
        }
        let id = "\(typeID.rawValue).\(slug)"
        guard isValid(id) else {
            throw LociError.invalidCollectionID(id)
        }
        return id
    }

    /// Valid ids look like `type.slug` (both sides non-empty, `[a-z0-9-]+`).
    public static func isValid(_ id: String) -> Bool {
        let parts = id.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return false }
        let typePart = String(parts[0])
        let slugPart = String(parts[1])
        guard !typePart.isEmpty, !slugPart.isEmpty else { return false }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-")
        return typePart.unicodeScalars.allSatisfy { allowed.contains($0) }
            && slugPart.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    /// Type prefix from a valid collection id (`book.favorites` → `book`).
    public static func typeID(from id: String) -> ObjectTypeID? {
        guard isValid(id),
            let prefix = id.split(separator: ".", maxSplits: 1).first
        else {
            return nil
        }
        return ObjectTypeID(String(prefix))
    }
}
