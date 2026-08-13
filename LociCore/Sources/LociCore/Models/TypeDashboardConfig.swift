import Foundation

/// Lightweight dashboard config embedded in an object-type schema file.
public struct TypeDashboardConfig: Hashable, Sendable, Codable, Equatable {
    /// Property ids shown on type-dashboard cards (PR12).
    public var cardPreviewPropertyIDs: [String]
    /// Optional default sort key (property id or `"updated"` / `"created"` / `"title"`).
    public var defaultSort: String?
    /// When true, type dashboard hides `#archive` / status=Archived (PR15).
    public var hideArchived: Bool
    /// Property id, `"tag"`, or nil (PR41). Group-by is derived UI — never written to markdown.
    public var defaultGroupBy: String?
    /// Optional property id for the dashboard equals filter (PR41).
    public var defaultFilterKey: String?
    /// Equals-text for `defaultFilterKey` (PR41).
    public var defaultFilterText: String?
    /// `"list"` or `"board"` (PR42). Missing / unknown JSON decodes as `"list"`.
    public var defaultView: String

    public static let listView = "list"
    public static let boardView = "board"

    public init(
        cardPreviewPropertyIDs: [String] = [],
        defaultSort: String? = nil,
        hideArchived: Bool = false,
        defaultGroupBy: String? = nil,
        defaultFilterKey: String? = nil,
        defaultFilterText: String? = nil,
        defaultView: String = TypeDashboardConfig.listView
    ) {
        self.cardPreviewPropertyIDs = cardPreviewPropertyIDs
        self.defaultSort = defaultSort
        self.hideArchived = hideArchived
        self.defaultGroupBy = defaultGroupBy
        self.defaultFilterKey = defaultFilterKey
        self.defaultFilterText = defaultFilterText
        self.defaultView = Self.normalizedView(defaultView)
    }

    private enum CodingKeys: String, CodingKey {
        case cardPreviewPropertyIDs, defaultSort, hideArchived
        case defaultGroupBy, defaultFilterKey, defaultFilterText, defaultView
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cardPreviewPropertyIDs =
            try container.decodeIfPresent([String].self, forKey: .cardPreviewPropertyIDs) ?? []
        defaultSort = try container.decodeIfPresent(String.self, forKey: .defaultSort)
        hideArchived = try container.decodeIfPresent(Bool.self, forKey: .hideArchived) ?? false
        defaultGroupBy = try container.decodeIfPresent(String.self, forKey: .defaultGroupBy)
        defaultFilterKey = try container.decodeIfPresent(String.self, forKey: .defaultFilterKey)
        defaultFilterText = try container.decodeIfPresent(String.self, forKey: .defaultFilterText)
        defaultView = Self.normalizedView(
            try container.decodeIfPresent(String.self, forKey: .defaultView)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(cardPreviewPropertyIDs, forKey: .cardPreviewPropertyIDs)
        try container.encodeIfPresent(defaultSort, forKey: .defaultSort)
        try container.encode(hideArchived, forKey: .hideArchived)
        try container.encodeIfPresent(defaultGroupBy, forKey: .defaultGroupBy)
        try container.encodeIfPresent(defaultFilterKey, forKey: .defaultFilterKey)
        try container.encodeIfPresent(defaultFilterText, forKey: .defaultFilterText)
        try container.encode(defaultView, forKey: .defaultView)
    }

    /// `"list"` | `"board"`; anything else (including nil / empty) → list.
    public static func normalizedView(_ raw: String?) -> String {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        return trimmed == boardView ? boardView : listView
    }
}
