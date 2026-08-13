import Foundation

/// Property type kinds defined by per-type schema files (Part 4 / PR05; UI in PR13).
public enum PropertyKind: String, Hashable, Sendable, Codable, CaseIterable {
    case text
    case number
    case date
    case select
    case multiSelect = "multi-select"
    case objectSelect = "object-select"
    case checkbox
    case url
}
