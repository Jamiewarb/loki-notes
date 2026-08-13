import Foundation

/// Filter DSL for QueryEngine (PR23). Executed against the disposable index —
/// results are derived and must not be written into note bodies by default.
public struct QueryDefinition: Hashable, Sendable, Codable, Equatable {
    /// Restrict to one object type when set.
    public var typeID: ObjectTypeID?
    /// Tag filters (normalized on execute). Empty = no tag constraint.
    public var tags: [String]
    /// How multiple tags combine (default: all must match).
    public var tagMode: QueryTagMode
    /// Property column filters (AND).
    public var properties: [PropertyFilter]
    /// Inclusive created timestamp range.
    public var created: DateRangeFilter?
    /// Inclusive updated timestamp range.
    public var updated: DateRangeFilter?
    /// Max rows (nil = unbounded).
    public var limit: Int?
    /// Sort order (default title ascending).
    public var sort: QuerySort

    public init(
        typeID: ObjectTypeID? = nil,
        tags: [String] = [],
        tagMode: QueryTagMode = .all,
        properties: [PropertyFilter] = [],
        created: DateRangeFilter? = nil,
        updated: DateRangeFilter? = nil,
        limit: Int? = nil,
        sort: QuerySort = .titleAsc
    ) {
        self.typeID = typeID
        self.tags = tags
        self.tagMode = tagMode
        self.properties = properties
        self.created = created
        self.updated = updated
        self.limit = limit
        self.sort = sort
    }
}

public enum QueryTagMode: String, Sendable, Codable, Hashable, CaseIterable {
    /// Object must carry every listed tag.
    case all
    /// Object must carry at least one listed tag.
    case any
}

public enum QuerySort: String, Sendable, Codable, Hashable, CaseIterable {
    case titleAsc
    case titleDesc
    case updatedDesc
    case updatedAsc
    case createdDesc
    case createdAsc
}

/// Inclusive date range on object created/updated timestamps.
public struct DateRangeFilter: Hashable, Sendable, Codable, Equatable {
    public var from: Date?
    public var to: Date?

    public init(from: Date? = nil, to: Date? = nil) {
        self.from = from
        self.to = to
    }

    public var isEmpty: Bool { from == nil && to == nil }
}

/// One property predicate against `properties_idx`.
public struct PropertyFilter: Hashable, Sendable, Codable, Equatable {
    public var key: String
    public var op: PropertyFilterOp
    /// Text / select / url compare value (equals, notEquals, contains).
    public var text: String?
    /// Numeric compare value (gt / gte / lt / lte).
    public var number: Double?
    /// Bool equals when op is `.equals` and `bool` is set.
    public var bool: Bool?

    public init(
        key: String,
        op: PropertyFilterOp,
        text: String? = nil,
        number: Double? = nil,
        bool: Bool? = nil
    ) {
        self.key = key
        self.op = op
        self.text = text
        self.number = number
        self.bool = bool
    }

    /// Convenience: text equality.
    public static func equals(_ key: String, text: String) -> PropertyFilter {
        PropertyFilter(key: key, op: .equals, text: text)
    }

    /// Convenience: numeric greater-than.
    public static func greaterThan(_ key: String, number: Double) -> PropertyFilter {
        PropertyFilter(key: key, op: .greaterThan, number: number)
    }
}

public enum PropertyFilterOp: String, Sendable, Codable, Hashable, CaseIterable {
    case equals
    case notEquals
    case contains
    case greaterThan
    case greaterThanOrEqual
    case lessThan
    case lessThanOrEqual
    case exists
    case notExists
}
