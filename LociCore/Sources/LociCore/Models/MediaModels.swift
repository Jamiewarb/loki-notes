import Foundation

/// Whether an attached blob belongs under `media/images` or `media/files`.
public enum MediaKind: String, Sendable, Hashable, Codable, Equatable {
    case image
    case file

    /// Vault-relative directory for this kind (`media/images` / `media/files`).
    public var directory: String {
        switch self {
        case .image: return "media/images"
        case .file: return "media/files"
        }
    }
}

/// Result of copying bytes into the vault media tree. Blobs live only on disk — never in SQLite.
public struct MediaAttachment: Hashable, Sendable, Equatable, Codable {
    /// Vault-relative path, e.g. `media/images/hero-a1b2.png`.
    public var relativePath: String
    public var kind: MediaKind
    public var fileName: String
    public var byteCount: Int

    public init(
        relativePath: String,
        kind: MediaKind,
        fileName: String,
        byteCount: Int
    ) {
        self.relativePath = relativePath
        self.kind = kind
        self.fileName = fileName
        self.byteCount = byteCount
    }
}

/// Helpers for vault-relative media paths and Loci MD image syntax.
public enum MediaPath: Sendable {
    /// Compute a relative URL from a markdown object path to a media blob path.
    ///
    /// - From `objects/page/note.md` → `media/images/a.png` = `../../media/images/a.png`
    /// - From `daily/2026-08-13.md` → `media/images/a.png` = `../media/images/a.png`
    public static func relativeURL(
        fromObjectRelativePath objectPath: String,
        toMediaRelativePath mediaPath: String
    ) -> String {
        let sourceDir = directory(of: normalize(objectPath))
        let sourceParts = sourceDir.split(separator: "/").map(String.init)
        let targetParts = normalize(mediaPath).split(separator: "/").map(String.init)

        var i = 0
        while i < sourceParts.count, i < targetParts.count, sourceParts[i] == targetParts[i] {
            i += 1
        }
        let ups = Array(repeating: "..", count: sourceParts.count - i)
        let downs = Array(targetParts[i...])
        let joined = (ups + downs).joined(separator: "/")
        return joined.isEmpty ? "." : joined
    }

    /// `![alt](relative-url)` pointing at a vault media path from an object file.
    public static func markdownImage(
        alt: String,
        mediaRelativePath: String,
        fromObjectRelativePath objectPath: String,
        title: String? = nil
    ) -> String {
        let url = relativeURL(
            fromObjectRelativePath: objectPath,
            toMediaRelativePath: mediaRelativePath
        )
        if let title, !title.isEmpty {
            return "![\(alt)](\(url) \"\(title)\")"
        }
        return "![\(alt)](\(url))"
    }

    /// Sanitize a preferred file name (keep extension; lowercase alphanumeric + hyphen stem).
    public static func sanitizeFileName(_ preferred: String, fallbackStem: String = "attachment")
        -> String
    {
        let trimmed = preferred.trimmingCharacters(in: .whitespacesAndNewlines)
        let ns = trimmed as NSString
        let ext = ns.pathExtension.lowercased()
        let rawStem = ns.deletingPathExtension
        var stem = ""
        var lastDash = false
        for scalar in rawStem.lowercased().unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                stem.unicodeScalars.append(scalar)
                lastDash = false
            } else if !stem.isEmpty && !lastDash {
                stem.append("-")
                lastDash = true
            }
        }
        while stem.hasSuffix("-") { stem.removeLast() }
        if stem.isEmpty { stem = fallbackStem }
        if stem.count > 48 { stem = String(stem.prefix(48)) }
        if ext.isEmpty { return stem }
        return "\(stem).\(ext)"
    }

    /// Infer image vs file from extension (common raster / vector image types → image).
    public static func kind(forFileName fileName: String) -> MediaKind {
        let ext = (fileName as NSString).pathExtension.lowercased()
        let images: Set<String> = [
            "png", "jpg", "jpeg", "gif", "webp", "heic", "heif", "tif", "tiff", "bmp", "svg",
        ]
        return images.contains(ext) ? .image : .file
    }

    private static func directory(of path: String) -> String {
        let ns = path as NSString
        let dir = ns.deletingLastPathComponent
        if dir.isEmpty || dir == "." { return "" }
        return normalize(dir)
    }

    private static func normalize(_ path: String) -> String {
        var p = path
        while p.hasPrefix("./") { p = String(p.dropFirst(2)) }
        while p.hasPrefix("/") { p = String(p.dropFirst()) }
        return p
    }
}
