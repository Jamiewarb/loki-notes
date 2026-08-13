import Foundation

/// Source flavor for vault import (PR27).
public enum ImportSourceKind: String, Sendable, Hashable, Codable, Equatable {
    /// Arbitrary folder of `.md` (+ optional media siblings).
    case markdownFolder
    /// Obsidian vault (`.obsidian/` present); wiki-links best-effort.
    case obsidianVault
    /// Capacities-style markdown export (typed Objects/ + frontmatter/media).
    case capacitiesExport
}

/// What to do when a planned destination path or ObjectID already exists.
public enum ImportConflictPolicy: String, Sendable, Hashable, Codable, Equatable {
    /// Leave existing vault file / id alone.
    case skip
    /// Allocate a new path (and new id when the id collides).
    case rename
    /// Replace vault bytes at the planned path (same id when preserved).
    case overwrite
}

/// Planned fate of one source markdown file.
public enum ImportPlanAction: String, Sendable, Hashable, Codable, Equatable {
    case create
    case overwrite
    case skipConflict
    case rename
}

/// One markdown file discovered in the import source (before / after planning).
public struct ImportPlanItem: Hashable, Sendable, Equatable, Codable {
    /// Absolute path to the source `.md` file.
    public var sourcePath: String
    /// Path relative to the import root (portable).
    public var sourceRelativePath: String
    public var title: String
    public var typeID: ObjectTypeID
    /// Preserved or allocated object id.
    public var objectID: ObjectID
    /// Vault-relative destination, e.g. `objects/page/hello.md` or `daily/2026-08-01.md`.
    public var destinationRelativePath: String
    public var action: ImportPlanAction
    public var tags: [String]
    /// Whether this maps onto the deterministic daily scheme.
    public var isDaily: Bool
    /// True when frontmatter (or Capacities export) supplied a stable id we kept.
    public var preservedObjectID: Bool
    public var warnings: [String]

    public init(
        sourcePath: String,
        sourceRelativePath: String,
        title: String,
        typeID: ObjectTypeID,
        objectID: ObjectID,
        destinationRelativePath: String,
        action: ImportPlanAction,
        tags: [String] = [],
        isDaily: Bool = false,
        preservedObjectID: Bool = false,
        warnings: [String] = []
    ) {
        self.sourcePath = sourcePath
        self.sourceRelativePath = sourceRelativePath
        self.title = title
        self.typeID = typeID
        self.objectID = objectID
        self.destinationRelativePath = destinationRelativePath
        self.action = action
        self.tags = tags
        self.isDaily = isDaily
        self.preservedObjectID = preservedObjectID
        self.warnings = warnings
    }
}

/// Media file that should land under vault `media/` during apply.
public struct ImportMediaItem: Hashable, Sendable, Equatable, Codable {
    public var sourcePath: String
    public var sourceRelativePath: String
    public var preferredFileName: String
    public var kind: MediaKind
    /// Filled after apply when bytes were copied.
    public var destinationRelativePath: String?

    public init(
        sourcePath: String,
        sourceRelativePath: String,
        preferredFileName: String,
        kind: MediaKind,
        destinationRelativePath: String? = nil
    ) {
        self.sourcePath = sourcePath
        self.sourceRelativePath = sourceRelativePath
        self.preferredFileName = preferredFileName
        self.kind = kind
        self.destinationRelativePath = destinationRelativePath
    }
}

/// Dry-run summary shown before apply (PR27).
public struct ImportDryRunSummary: Hashable, Sendable, Equatable, Codable {
    public var sourceKind: ImportSourceKind
    public var sourceRoot: String
    public var conflictPolicy: ImportConflictPolicy
    public var items: [ImportPlanItem]
    public var media: [ImportMediaItem]
    public var warnings: [String]
    /// Title → destination slug / id for wiki-link rewrite hints.
    public var titleIndex: [String: String]

    public init(
        sourceKind: ImportSourceKind,
        sourceRoot: String,
        conflictPolicy: ImportConflictPolicy,
        items: [ImportPlanItem],
        media: [ImportMediaItem] = [],
        warnings: [String] = [],
        titleIndex: [String: String] = [:]
    ) {
        self.sourceKind = sourceKind
        self.sourceRoot = sourceRoot
        self.conflictPolicy = conflictPolicy
        self.items = items
        self.media = media
        self.warnings = warnings
        self.titleIndex = titleIndex
    }

    public var createCount: Int { items.filter { $0.action == .create || $0.action == .rename }.count }
    public var overwriteCount: Int { items.filter { $0.action == .overwrite }.count }
    public var skipCount: Int { items.filter { $0.action == .skipConflict }.count }
    public var dailyCount: Int { items.filter(\.isDaily).count }
    public var preservedIDCount: Int { items.filter(\.preservedObjectID).count }
}

/// Outcome of applying an import plan.
public struct ImportApplyResult: Hashable, Sendable, Equatable, Codable {
    public var sourceKind: ImportSourceKind
    public var written: [ImportPlanItem]
    public var skipped: [ImportPlanItem]
    public var mediaCopied: [ImportMediaItem]
    public var warnings: [String]

    public init(
        sourceKind: ImportSourceKind,
        written: [ImportPlanItem],
        skipped: [ImportPlanItem],
        mediaCopied: [ImportMediaItem] = [],
        warnings: [String] = []
    ) {
        self.sourceKind = sourceKind
        self.written = written
        self.skipped = skipped
        self.mediaCopied = mediaCopied
        self.warnings = warnings
    }

    public var writtenCount: Int { written.count }
    public var skippedCount: Int { skipped.count }
}

/// Pure helpers for import path / daily / slug detection (Linux-testable).
public enum ImportPathRules: Sendable {
    /// Match `YYYY-MM-DD` (optionally with `.md`).
    public static func parseDailyDateKey(_ name: String) -> (year: Int, month: Int, day: Int)? {
        var stem = name
        if stem.lowercased().hasSuffix(".md") {
            stem = String(stem.dropLast(3))
        }
        let pattern = #"^(\d{4})-(\d{2})-(\d{2})$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(stem.startIndex..<stem.endIndex, in: stem)
        guard let match = regex.firstMatch(in: stem, range: range),
            match.numberOfRanges == 4,
            let yRange = Range(match.range(at: 1), in: stem),
            let mRange = Range(match.range(at: 2), in: stem),
            let dRange = Range(match.range(at: 3), in: stem),
            let year = Int(stem[yRange]),
            let month = Int(stem[mRange]),
            let day = Int(stem[dRange]),
            (1...12).contains(month),
            (1...31).contains(day)
        else {
            return nil
        }
        return (year, month, day)
    }

    /// True when the relative path looks like an Obsidian/Capacities daily note.
    public static func looksLikeDaily(relativePath: String) -> Bool {
        let normalized = relativePath.replacingOccurrences(of: "\\", with: "/")
        let parts = normalized.split(separator: "/").map(String.init)
        guard let file = parts.last else { return false }
        guard parseDailyDateKey(file) != nil else { return false }
        if parts.count == 1 { return true }
        let parent = parts[parts.count - 2].lowercased()
        let dailyParents: Set<String> = [
            "daily", "daily notes", "dailynotes", "journal", "journals", "日历",
        ]
        return dailyParents.contains(parent) || normalized.lowercased().hasPrefix("daily/")
    }

    public static func dailyDestination(year: Int, month: Int, day: Int) -> (
        path: String, id: ObjectID, title: String
    ) {
        (
            DailyNoteIdentity.relativePath(year: year, month: month, day: day),
            ObjectID.daily(year: year, month: month, day: day),
            String(format: "%04d-%02d-%02d", year, month, day)
        )
    }

    /// Slugify a title for `objects/<type>/<slug>.md` (mirrors ObjectPathAllocator rules).
    public static func slugify(_ title: String) -> String {
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
        while out.hasSuffix("-") { out.removeLast() }
        if out.count > 64 {
            out = String(out.prefix(64))
            while out.hasSuffix("-") { out.removeLast() }
        }
        return out
    }

    public static func objectDestination(typeID: ObjectTypeID, title: String, id: ObjectID) -> String {
        let slug = slugify(title)
        let primary = slug.isEmpty ? id.uuidString.lowercased() : slug
        return "\(VaultLayoutPaths.objects)/\(typeID.rawValue)/\(primary).md"
    }

    /// Normalize Capacities / Obsidian type names → Loci type ids.
    public static func mapTypeName(_ raw: String?) -> ObjectTypeID {
        guard let raw else { return .page }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .page }
        let lower = trimmed.lowercased()
        switch lower {
        case "page", "pages", "note", "notes": return .page
        case "daily", "daily note", "daily notes": return .daily
        case "image", "images", "photo", "photos": return .image
        case "project", "projects": return .project
        case "area", "areas": return .area
        default:
            // Slugify unknown type names into custom type ids.
            let slug = slugify(trimmed)
            return ObjectTypeID(slug.isEmpty ? "page" : slug)
        }
    }
}

/// Path constants without importing LociVault (Core stays I/O-free).
public enum VaultLayoutPaths: Sendable {
    public static let objects = "objects"
    public static let daily = "daily"
    public static let mediaImages = "media/images"
    public static let mediaFiles = "media/files"
}

/// Best-effort wiki-link rewrite: `[[Title]]` → `[[slug-or-id]]` when title is in the index.
public enum ImportWikiLinkRewriter: Sendable {
    /// Rewrite wiki-link targets using a title/alias → preferred target map.
    public static func rewrite(_ body: String, titleIndex: [String: String]) -> (String, [String]) {
        guard !titleIndex.isEmpty else { return (body, []) }
        var unresolved: [String] = []
        guard let regex = try? NSRegularExpression(pattern: #"\[\[([^\]|]+)(?:\|([^\]]+))?\]\]"#)
        else {
            return (body, [])
        }
        let ns = body as NSString
        let matches = regex.matches(in: body, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return (body, []) }

        var result = body
        // Replace from the end so ranges stay valid.
        for match in matches.reversed() {
            guard match.numberOfRanges >= 2,
                let targetRange = Range(match.range(at: 1), in: result)
            else { continue }
            let target = String(result[targetRange]).trimmingCharacters(in: .whitespaces)
            let key = target.lowercased()
            var label: String?
            if match.numberOfRanges >= 3, match.range(at: 2).location != NSNotFound,
                let labelRange = Range(match.range(at: 2), in: result)
            {
                label = String(result[labelRange])
            }
            if let mapped = titleIndex[key] ?? titleIndex[target] {
                let replacement: String
                if let label, !label.isEmpty, label != mapped {
                    replacement = "[[\(mapped)|\(label)]]"
                } else if mapped != target {
                    // Keep human title as label when target becomes a slug/id.
                    replacement = "[[\(mapped)|\(target)]]"
                } else {
                    replacement = "[[\(mapped)]]"
                }
                if let full = Range(match.range(at: 0), in: result) {
                    result.replaceSubrange(full, with: replacement)
                }
            } else {
                unresolved.append(target)
            }
        }
        return (result, unresolved)
    }
}

/// Detect import source kind from directory names (no deep content scan).
public enum ImportSourceDetector: Sendable {
    public static func detect(relativeEntries: [String]) -> ImportSourceKind {
        let normalized = relativeEntries.map {
            $0.replacingOccurrences(of: "\\", with: "/").lowercased()
        }
        if normalized.contains(where: { $0 == ".obsidian" || $0.hasPrefix(".obsidian/") }) {
            return .obsidianVault
        }
        // Capacities-style: Objects/<Type>/… or top-level capacities markers.
        let hasObjectsTyped = normalized.contains { entry in
            let parts = entry.split(separator: "/").map(String.init)
            return parts.count >= 2 && parts[0] == "objects"
                && parts[1] != "page" // still capacities-like when Objects/Page exists
        }
        // Case-sensitive check was lowercased — also accept "objects/…"
        let hasCapacitiesMarker = normalized.contains {
            $0 == "capacities.json" || $0.hasPrefix("_capacities") || $0 == ".capacities"
        }
        let hasObjectsFolder = normalized.contains {
            $0 == "objects" || $0.hasPrefix("objects/")
        }
        if hasCapacitiesMarker || (hasObjectsFolder && hasObjectsTyped) || hasObjectsFolder {
            // Prefer capacities when Objects/ tree looks typed (Page, Book, …).
            if hasCapacitiesMarker || normalized.contains(where: {
                $0.hasPrefix("objects/") && $0.hasSuffix(".md")
            }) {
                return .capacitiesExport
            }
        }
        return .markdownFolder
    }

    /// File-system friendly: pass top-level directory / file names only.
    public static func detect(topLevelNames: [String]) -> ImportSourceKind {
        let lower = Set(topLevelNames.map { $0.lowercased() })
        if lower.contains(".obsidian") { return .obsidianVault }
        if lower.contains("capacities.json") || lower.contains("_capacities")
            || lower.contains(".capacities")
        {
            return .capacitiesExport
        }
        if lower.contains("objects") { return .capacitiesExport }
        return .markdownFolder
    }
}
