import Foundation

/// Slug rules for custom object types (`.loci/types/<slug>.json` + `objects/<slug>/`).
public enum TypeSlug: Sendable {
    /// Reserved built-in ids — never create/delete casually as custom types.
    public static let reserved: Set<String> = ["page", "daily", "image"]

    /// Derive a filesystem-safe slug from a display name (lowercase, hyphenated).
    public static func fromName(_ name: String) -> String {
        let lowered = name.lowercased()
        var out = ""
        var lastDash = false
        for scalar in lowered.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                out.unicodeScalars.append(scalar)
                lastDash = false
            } else if !out.isEmpty && !lastDash {
                out.append("-")
                lastDash = true
            }
        }
        while out.hasSuffix("-") {
            out.removeLast()
        }
        if out.count > 48 {
            out = String(out.prefix(48))
            while out.hasSuffix("-") {
                out.removeLast()
            }
        }
        return out
    }

    /// Normalize an explicit slug (trim, lower, collapse invalid chars).
    public static func normalize(_ raw: String) -> String {
        fromName(raw.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Resolve slug from optional explicit value or display name; validates reserved/empty.
    public static func resolve(explicit: String?, fromName name: String) throws -> String {
        let candidate: String
        if let explicit, !explicit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            candidate = normalize(explicit)
        } else {
            candidate = fromName(name)
        }
        guard !candidate.isEmpty else {
            throw LociError.invalidTypeSlug("(empty)")
        }
        guard !reserved.contains(candidate) else {
            throw LociError.invalidTypeSlug(candidate)
        }
        // Must be lowercase alphanumeric + hyphens only (already enforced by fromName).
        return candidate
    }

    public static func isProtected(_ id: ObjectTypeID) -> Bool {
        reserved.contains(id.rawValue) || id == .page || id == .daily || id == .image
    }
}
