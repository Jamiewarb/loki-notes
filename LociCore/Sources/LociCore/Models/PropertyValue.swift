import Foundation

/// Property value union used by frontmatter / schema (expanded in PR13).
public enum PropertyValue: Hashable, Sendable, Codable {
    case text(String)
    case number(Double)
    case bool(Bool)
    case date(Date)
    case null
}
