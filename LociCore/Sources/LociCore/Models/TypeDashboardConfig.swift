import Foundation

/// Lightweight dashboard config embedded in an object-type schema file.
public struct TypeDashboardConfig: Hashable, Sendable, Codable, Equatable {
    /// Property ids shown on type-dashboard cards (PR12).
    public var cardPreviewPropertyIDs: [String]
    /// Optional default sort key (property id or `"updated"` / `"created"` / `"title"`).
    public var defaultSort: String?

    public init(
        cardPreviewPropertyIDs: [String] = [],
        defaultSort: String? = nil
    ) {
        self.cardPreviewPropertyIDs = cardPreviewPropertyIDs
        self.defaultSort = defaultSort
    }
}
