import Foundation

/// Callout / admonition kinds (Obsidian / GitHub-alert style) — PR29.
public enum CalloutKind: String, Sendable, Hashable, Codable, CaseIterable {
    case note
    case tip
    case info
    case warning
    case important
    case caution

    public var title: String {
        rawValue.capitalized
    }

    /// Normalize `[!NOTE]` / `note` / `TIP` → canonical kind (unknown → `.note`).
    public static func parse(_ raw: String) -> CalloutKind {
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return CalloutKind(rawValue: key) ?? .note
    }
}
