import Foundation
import LociCore

/// Allocates vault-relative paths for new objects: `objects/<type>/<slug-or-id>.md`.
enum ObjectPathAllocator {
    static func allocate(
        typeID: ObjectTypeID,
        title: String,
        id: ObjectID,
        vault: any VaultServing
    ) async throws -> String {
        let directory = "\(VaultLayout.objectsDirectory)/\(typeID.rawValue)"
        let slug = slugify(title)
        let primary = slug.isEmpty ? id.uuidString.lowercased() : slug
        let candidates = [
            "\(directory)/\(primary).md",
            "\(directory)/\(primary)-\(shortID(id)).md",
            "\(directory)/\(id.uuidString.lowercased()).md",
        ]
        for path in candidates {
            if try await !vault.fileExists(atRelativePath: path) {
                return path
            }
        }
        // Extremely unlikely collision on full UUID filename.
        return "\(directory)/\(id.uuidString.lowercased())-\(Int(Date().timeIntervalSince1970)).md"
    }

    static func slugify(_ title: String) -> String {
        let lowered = title.lowercased()
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
        if out.count > 64 {
            out = String(out.prefix(64))
            while out.hasSuffix("-") {
                out.removeLast()
            }
        }
        return out
    }

    private static func shortID(_ id: ObjectID) -> String {
        String(id.uuidString.lowercased().replacingOccurrences(of: "-", with: "").prefix(8))
    }
}
