import Foundation

/// Per-type content preset: body markdown + default property values (PR14).
///
/// Stored under `.loci/templates/<id>.md` (YAML frontmatter + body). Type schema
/// tracks `templateIDs` and `defaultTemplateID` for starring.
public struct ObjectTemplate: Hashable, Sendable, Codable, Equatable {
    public var id: String
    public var typeID: ObjectTypeID
    public var name: String
    public var bodyMarkdown: String
    public var defaultProperties: [String: PropertyValue]

    public init(
        id: String,
        typeID: ObjectTypeID,
        name: String,
        bodyMarkdown: String = "",
        defaultProperties: [String: PropertyValue] = [:]
    ) {
        self.id = id
        self.typeID = typeID
        self.name = name
        self.bodyMarkdown = bodyMarkdown
        self.defaultProperties = defaultProperties
    }
}

/// Helpers for template ids (`book.default`, `daily.morning`).
public enum TemplateID: Sendable {
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
            throw LociError.invalidTemplateID("(empty)")
        }
        let id = "\(typeID.rawValue).\(slug)"
        guard isValid(id) else {
            throw LociError.invalidTemplateID(id)
        }
        return id
    }

    /// Valid ids look like `type.slug` (both sides non-empty, `[a-z0-9.-]+`).
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
}
