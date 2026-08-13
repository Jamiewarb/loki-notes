import Foundation

/// Detects iCloud / Finder conflicted-copy filename patterns.
/// Hook only — SyncStatus UI surfaces these in PR21; indexer may keep both copies.
public enum ConflictedCopyDetector: Sendable {
    /// True when the last path component looks like an iCloud/Finder conflicted copy.
    public static func isConflictedCopy(pathOrFilename: String) -> Bool {
        let name = (pathOrFilename as NSString).lastPathComponent
        let lower = name.lowercased()

        // Classic Finder / iCloud: "Note (Conflicted copy from MacBook).md"
        if lower.contains("(conflicted copy") {
            return true
        }
        // Alternate: "filename 2.md" / "filename 3.md" immediately before extension
        if matchesNumberedConflict(name) {
            return true
        }
        return false
    }

    private static func matchesNumberedConflict(_ name: String) -> Bool {
        // e.g. "Daily 2.md", "page 3.txt"
        let pattern = #"^.+\s[2-9]\.[^./]+$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return false
        }
        let range = NSRange(name.startIndex..<name.endIndex, in: name)
        return regex.firstMatch(in: name, range: range) != nil
    }
}
