import Foundation

/// GFM table column alignment (PR29).
public enum TableAlignment: String, Sendable, Hashable, Codable, CaseIterable {
    case left
    case center
    case right
    case none

    /// Parse a GFM separator cell (`---`, `:---`, `---:`, `:---:`).
    public static func parseSeparatorCell(_ raw: String) -> TableAlignment? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let compact = trimmed.filter { $0 == "-" || $0 == ":" }
        guard compact.count == trimmed.count, compact.contains("-") else { return nil }
        let left = compact.hasPrefix(":")
        let right = compact.hasSuffix(":")
        switch (left, right) {
        case (true, true): return .center
        case (true, false): return .left
        case (false, true): return .right
        default: return .none
        }
    }

    public var separatorCell: String {
        switch self {
        case .left: return ":---"
        case .center: return ":---:"
        case .right: return "---:"
        case .none: return "---"
        }
    }
}
