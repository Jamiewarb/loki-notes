import Foundation
import GRDB
import LociCore

/// Resolves wiki-link targets against the local `objects` projection.
///
/// **Priority:** ObjectID → relative path → path/slug stem → case-insensitive title.
/// Path/slug are locators only — identity remains frontmatter `id`.
public enum LinkResolver: Sendable {
    /// Resolve a single wiki-link target string to an indexed object, or `nil` if broken.
    public static func resolve(db: Database, target: String) throws -> LociObjectMeta? {
        let trimmed = target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // 1. ObjectID (UUID or daily-YYYY-MM-DD)
        if let oid = ObjectID(parsing: trimmed) {
            let key = oid.uuidString.lowercased()
            if let row = try Row.fetchOne(
                db,
                sql: "SELECT * FROM objects WHERE id = ?",
                arguments: [key]
            ) {
                return try ObjectRowDecoder.decode(row)
            }
            // Daily date key → vault path daily/YYYY-MM-DD.md
            if let dailyKey = oid.dailyDateKey {
                let datePart = String(dailyKey.dropFirst("daily-".count))
                if let byPath = try fetchByRelativePath(db, "daily/\(datePart).md") {
                    return byPath
                }
            }
        }

        // 2. Exact relative path (with or without .md)
        let pathCandidates = pathVariants(trimmed)
        for path in pathCandidates {
            if let meta = try fetchByRelativePath(db, path) {
                return meta
            }
        }

        // 3. Filename / slug stem (last path component, case-insensitive)
        let stem = slugStem(trimmed)
        if !stem.isEmpty {
            let lowered = stem.lowercased()
            let rows = try Row.fetchAll(
                db,
                sql: """
                    SELECT * FROM objects
                    WHERE lower(relative_path) LIKE ?
                       OR lower(relative_path) = ?
                    ORDER BY title COLLATE NOCASE ASC
                    LIMIT 8
                    """,
                arguments: ["%/\(lowered).md", "\(lowered).md"]
            )
            // Prefer exact filename stem match over accidental substring.
            for row in rows {
                let meta = try ObjectRowDecoder.decode(row)
                if slugStem(meta.relativePath).lowercased() == lowered {
                    return meta
                }
            }
            if let row = rows.first {
                return try ObjectRowDecoder.decode(row)
            }
        }

        // 4. Exact title (case-insensitive)
        if let row = try Row.fetchOne(
            db,
            sql: """
                SELECT * FROM objects
                WHERE title = ? COLLATE NOCASE
                ORDER BY updated DESC
                LIMIT 1
                """,
            arguments: [trimmed]
        ) {
            return try ObjectRowDecoder.decode(row)
        }

        return nil
    }

    /// Targets that should match when querying backlinks *to* an object.
    public static func targetAliases(for meta: LociObjectMeta) -> [String] {
        var aliases: [String] = []
        let idLower = meta.id.uuidString.lowercased()
        aliases.append(idLower)
        aliases.append(meta.id.frontMatterIDString)
        aliases.append(meta.relativePath)
        if meta.relativePath.hasSuffix(".md") {
            aliases.append(String(meta.relativePath.dropLast(3)))
        } else {
            aliases.append(meta.relativePath + ".md")
        }
        let stem = slugStem(meta.relativePath)
        if !stem.isEmpty {
            aliases.append(stem)
        }
        let title = meta.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty {
            aliases.append(title)
        }
        // Deduplicate while preserving order
        var seen = Set<String>()
        return aliases.filter { alias in
            let key = alias.lowercased()
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }
    }

    /// Preferred wiki-link target when inserting from the picker — always ObjectID.
    public static func preferredTarget(for meta: LociObjectMeta) -> String {
        meta.id.frontMatterIDString
    }

    // MARK: - Helpers

    private static func fetchByRelativePath(_ db: Database, _ path: String) throws -> LociObjectMeta? {
        let normalized = normalizePath(path)
        if let row = try Row.fetchOne(
            db,
            sql: "SELECT * FROM objects WHERE relative_path = ? COLLATE NOCASE",
            arguments: [normalized]
        ) {
            return try ObjectRowDecoder.decode(row)
        }
        return nil
    }

    private static func pathVariants(_ raw: String) -> [String] {
        var out: [String] = []
        let n = normalizePath(raw)
        out.append(n)
        if n.hasSuffix(".md") {
            out.append(String(n.dropLast(3)))
        } else {
            out.append(n + ".md")
        }
        return out
    }

    private static func normalizePath(_ path: String) -> String {
        var p = path.trimmingCharacters(in: .whitespacesAndNewlines)
        while p.hasPrefix("./") { p = String(p.dropFirst(2)) }
        while p.hasPrefix("/") { p = String(p.dropFirst()) }
        return p
    }

    /// Last path component without `.md`.
    public static func slugStem(_ path: String) -> String {
        var p = normalizePath(path)
        if p.hasSuffix(".md") {
            p = String(p.dropLast(3))
        }
        if let slash = p.lastIndex(of: "/") {
            return String(p[p.index(after: slash)...])
        }
        return p
    }
}
