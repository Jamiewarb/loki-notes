import Foundation

/// Definition of a property on an `ObjectType` (stored in `.loci/types/<slug>.json`).
public struct PropertyDef: Hashable, Sendable, Codable, Equatable {
    public var id: String
    public var name: String
    public var kind: PropertyKind
    /// Select / multi-select option labels (ignored for other kinds).
    public var options: [String]
    public var required: Bool

    public init(
        id: String,
        name: String,
        kind: PropertyKind,
        options: [String] = [],
        required: Bool = false
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.options = options
        self.required = required
    }
}
