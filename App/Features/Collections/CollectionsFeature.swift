import SwiftUI
import LociCore

/// Public entry for Collections feature (PR22).
///
/// Manual curated groups within one type. Membership is vault JSON under
/// `.loci/collections/<type>.<slug>.json` — never index-only truth.
enum CollectionsFeature {
    /// Type dashboard: All / collection tabs + create / membership chrome.
    @MainActor
    static func tabs(
        services: AppServices,
        typeID: ObjectTypeID,
        allObjects: [LociObjectMeta],
        selectedCollectionID: Binding<String?>,
        onChanged: @escaping () async -> Void
    ) -> some View {
        CollectionTabsView(
            services: services,
            typeID: typeID,
            allObjects: allObjects,
            selectedCollectionID: selectedCollectionID,
            onChanged: onChanged
        )
    }

    /// Remove a member via SchemaServing (type dashboard row action).
    @MainActor
    static func removeMember(
        services: AppServices,
        collectionID: String,
        objectID: ObjectID
    ) async throws {
        _ = try await CollectionStore(schema: services.schema)
            .remove(collectionID: collectionID, objectID: objectID)
    }
}
