import Foundation

/// Saved query definition stored in the vault (PR23).
///
/// Vault truth: `.loci/queries/<slug>.json`. Results are always derived from the
/// index at read time — never persist live result lists into this file or into
/// note bodies (unless the user inserts a `/query` embed that only stores the slug).
public struct SavedQuery: Hashable, Sendable, Codable, Equatable {
    /// Stable slug id (`reading-books`).
    public var id: String
    public var name: String
    public var definition: QueryDefinition
    /// When set, the query is pinned on that type’s dashboard.
    public var pinnedTypeID: ObjectTypeID?
    public var updatedAt: Date

    public init(
        id: String,
        name: String,
        definition: QueryDefinition,
        pinnedTypeID: ObjectTypeID? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.definition = definition
        self.pinnedTypeID = pinnedTypeID
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, definition, pinnedTypeID, updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        definition = try container.decode(QueryDefinition.self, forKey: .definition)
        if let raw = try container.decodeIfPresent(String.self, forKey: .pinnedTypeID) {
            pinnedTypeID = ObjectTypeID(raw)
        } else {
            pinnedTypeID = nil
        }
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(definition, forKey: .definition)
        try container.encodeIfPresent(pinnedTypeID?.rawValue, forKey: .pinnedTypeID)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

/// Helpers for saved-query slugs (`reading-books`).
public enum QueryID: Sendable {
    public static func normalize(_ raw: String) -> String {
        TypeSlug.normalize(raw)
    }

    /// Build a slug id from name or explicit slug.
    public static func make(name: String, explicitSlug: String? = nil) throws -> String {
        let slug: String
        if let explicitSlug, !explicitSlug.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            slug = normalize(explicitSlug)
        } else {
            slug = TypeSlug.fromName(name)
        }
        guard !slug.isEmpty else {
            throw LociError.invalidQueryID("(empty)")
        }
        guard isValid(slug) else {
            throw LociError.invalidQueryID(slug)
        }
        return slug
    }

    /// Valid ids are `[a-z0-9-]+` (same rules as type slugs).
    public static func isValid(_ id: String) -> Bool {
        guard !id.isEmpty else { return false }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-")
        return id.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}
