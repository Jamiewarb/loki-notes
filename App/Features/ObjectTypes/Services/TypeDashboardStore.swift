import Foundation
import LociCore

/// Thin ObjectTypes-local facade over `IndexQuerying.execute` (PR41).
/// Must not import `App/Features/Queries` — the list uses Core `QueryDefinition`.
@MainActor
final class TypeDashboardStore {
    struct Snapshot {
        var type: ObjectType?
        var allObjects: [LociObjectMeta]
        var sections: [DashboardSection]
        var columns: [DashboardSection]
        var hideArchived: Bool
        var archivedHiddenCount: Int
    }

    struct QueryState {
        var sortKey: String
        var groupBy: String?
        var filterKey: String?
        var filterText: String
        var tagFilter: String?
        var collectionMemberIDs: [ObjectID]?
    }

    private let services: AppServices

    init(services: AppServices) {
        self.services = services
    }

    func load(typeID: ObjectTypeID, state: QueryState) async throws -> Snapshot {
        let index = try await services.ensureIndex()
        let type = try await services.schema.loadType(typeID)
        let space = try? await services.schema.loadSpaceSettings()
        let hideArchived = (type.dashboard.hideArchived == true) || (space?.hideArchived == true)

        let sort = DashboardSort.querySort(from: state.sortKey)
        let definition = DashboardQuery.definition(
            typeID: typeID,
            tags: state.tagFilter.map { [$0] } ?? [],
            filterKey: state.filterKey,
            filterText: state.filterText,
            sort: sort
        )
        var objects = try await index.execute(definition)
        objects = DashboardSort.applyPropertySort(objects, sortKey: state.sortKey)

        let unarchived = ArchiveFilter.visible(objects, hideArchived: hideArchived)
        let archivedHiddenCount = objects.count - unarchived.count
        let listed = DashboardQuery.applyCollectionMembership(
            unarchived,
            memberIDs: state.collectionMemberIDs
        )
        let sections = DashboardGrouping.sections(
            objects: listed,
            groupBy: state.groupBy,
            properties: type.properties
        )
        let columns = KanbanMove.columns(
            objects: listed,
            groupBy: state.groupBy,
            properties: type.properties
        )
        return Snapshot(
            type: type,
            allObjects: unarchived,
            sections: sections,
            columns: columns,
            hideArchived: hideArchived,
            archivedHiddenCount: archivedHiddenCount
        )
    }

    func persistDefaults(
        type: ObjectType,
        sortKey: String,
        groupBy: String?,
        filterKey: String?,
        filterText: String,
        defaultView: String
    ) async throws -> ObjectType {
        var updated = type
        let sort = sortKey.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.dashboard.defaultSort = sort.isEmpty ? nil : sort
        let group = groupBy?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        updated.dashboard.defaultGroupBy = group.isEmpty ? nil : group
        let key = filterKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        updated.dashboard.defaultFilterKey = key.isEmpty ? nil : key
        let text = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.dashboard.defaultFilterText = text.isEmpty ? nil : text
        updated.dashboard.defaultView = TypeDashboardConfig.normalizedView(defaultView)
        try await services.schema.saveType(updated)
        return updated
    }

    /// Move a card: open + save YAML property/tag via ObjectServing. Body is unchanged.
    func moveCard(
        objectID: ObjectID,
        groupBy: String?,
        destinationKey: String,
        properties: [PropertyDef]
    ) async throws {
        let objects = try await services.ensureObjectService()
        let opened = try await objects.open(id: objectID)
        var meta = opened.meta
        let next = KanbanMove.next(
            meta: meta,
            groupBy: groupBy,
            destinationKey: destinationKey,
            properties: properties
        )
        meta.properties = next.properties
        meta.tags = next.tags
        try await objects.save(meta: meta, bodyMarkdown: opened.bodyMarkdown)
    }

    func loadCollection(_ id: String?) async throws -> ObjectCollection? {
        guard let id else { return nil }
        return try await services.schema.loadCollection(id)
    }
}
