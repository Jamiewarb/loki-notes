import SwiftUI
import LociCore

/// Public entry for Queries feature (PR23).
///
/// Saved query *definitions* live in `.loci/queries/<slug>.json`. Results are
/// always derived from `IndexQuerying.execute` — never written into note bodies
/// unless the user inserts a `/query` embed (slug reference only).
enum QueriesFeature {
    /// Pinned saved queries on a type dashboard.
    @MainActor
    static func pinned(
        services: AppServices,
        typeID: ObjectTypeID,
        onOpen: @escaping (ObjectID) async -> Void
    ) -> some View {
        PinnedQueriesView(services: services, typeID: typeID, onOpen: onOpen)
    }

    /// Live results for a `/query` embed block (slug → SavedQuery → Index).
    @MainActor
    static func embed(
        services: AppServices,
        queryID: String,
        onOpen: @escaping (ObjectID) async -> Void
    ) -> some View {
        QueryEmbedView(services: services, queryID: queryID, onOpen: onOpen)
    }
}
