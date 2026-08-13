import Foundation

/// Stable property ids stored in type schema + frontmatter keys.
public enum PropertyKey: Sendable {
    /// Derive a filesystem/YAML-safe id from a display name (lowercase, hyphenated).
    public static func fromName(_ name: String) -> String {
        TypeSlug.fromName(name)
    }

    /// Normalize an explicit id; empty → error via caller.
    public static func normalize(_ raw: String) -> String {
        TypeSlug.normalize(raw)
    }

    /// Resolve id from optional explicit value or display name.
    public static func resolve(explicit: String?, fromName name: String) throws -> String {
        let candidate: String
        if let explicit, !explicit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            candidate = normalize(explicit)
        } else {
            candidate = fromName(name)
        }
        guard !candidate.isEmpty else {
            throw LociError.invalidPropertyID("(empty)")
        }
        return candidate
    }
}
