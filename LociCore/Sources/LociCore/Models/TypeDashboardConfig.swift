import Foundation

/// Lightweight dashboard config embedded in an object-type schema file.
public struct TypeDashboardConfig: Hashable, Sendable, Codable, Equatable {
    /// Property ids shown on type-dashboard cards (PR12).
    public var cardPreviewPropertyIDs: [String]
    /// Optional default sort key (property id or `"updated"` / `"created"` / `"title"`).
    public var defaultSort: String?
    /// When true, type dashboard hides `#archive` / status=Archived (PR15).
    public var hideArchived: Bool

    public init(
        cardPreviewPropertyIDs: [String] = [],
        defaultSort: String? = nil,
        hideArchived: Bool = false
    ) {
        self.cardPreviewPropertyIDs = cardPreviewPropertyIDs
        self.defaultSort = defaultSort
        self.hideArchived = hideArchived
    }

    private enum CodingKeys: String, CodingKey {
        case cardPreviewPropertyIDs, defaultSort, hideArchived
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cardPreviewPropertyIDs =
            try container.decodeIfPresent([String].self, forKey: .cardPreviewPropertyIDs) ?? []
        defaultSort = try container.decodeIfPresent(String.self, forKey: .defaultSort)
        hideArchived = try container.decodeIfPresent(Bool.self, forKey: .hideArchived) ?? false
    }
}
