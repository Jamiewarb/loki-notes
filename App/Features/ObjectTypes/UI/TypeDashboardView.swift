import SwiftUI
import LociCore
import LociDesignSystem

/// Type dashboard: QueryEngine list + collection tabs (PR12 / PR22 / PR41).
struct TypeDashboardView: View {
    var services: AppServices
    let typeID: ObjectTypeID
    var onBack: () -> Void

    @State private var type: ObjectType?
    @State private var objects: [LociObjectMeta] = []
    @State private var sections: [DashboardSection] = []
    @State private var renameDraft: String = ""
    @State private var errorMessage: String?
    @State private var isBusy = false
    @State private var showRename = false
    @State private var hideArchived = false
    @State private var archivedHiddenCount = 0
    @State private var tagFilterDraft: String = ""
    @State private var activeTagFilter: String?
    @State private var tagFilterHiddenCount = 0
    @State private var selectedCollectionID: String?
    @State private var activeCollection: ObjectCollection?
    @State private var sortKey: String = QuerySort.titleAsc.rawValue
    @State private var groupByKey: String = "none"
    @State private var filterKey: String = ""
    @State private var filterText: String = ""
    @State private var didLoad = false

    private var store: TypeDashboardStore { TypeDashboardStore(services: services) }

    var body: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.lg)) {
            TypeDashboardHeader(
                type: type,
                typeID: typeID,
                isBusy: isBusy,
                hideArchived: hideArchived,
                archivedHiddenCount: archivedHiddenCount,
                activeTagFilter: activeTagFilter,
                tagFilterHiddenCount: tagFilterHiddenCount,
                tagFilterDraft: $tagFilterDraft,
                renameDraft: $renameDraft,
                showRename: $showRename,
                onBack: onBack,
                onRename: { await rename() },
                onDelete: { await deleteType() },
                onCreate: { await createObject() },
                onApplyTagFilter: { applyTagFilter() },
                onClearTagFilter: {
                    tagFilterDraft = ""
                    activeTagFilter = nil
                    Task { await reload() }
                }
            )
            TypeDashboardControls(
                properties: type?.properties ?? [],
                sortKey: $sortKey,
                groupByKey: $groupByKey,
                filterKey: $filterKey,
                filterText: $filterText,
                onApplyFilter: { Task { await persistAndReload() } },
                onClearFilter: {
                    filterKey = ""
                    filterText = ""
                    Task { await persistAndReload() }
                }
            )
            featureFacades
            TypeDashboardList(
                type: type,
                typeID: typeID,
                sections: sections,
                activeCollection: activeCollection,
                selectedCollectionID: selectedCollectionID,
                isBusy: isBusy,
                onOpen: { id in await services.open(objectID: id) },
                onRemoveFromCollection: { collectionID, objectID in
                    await removeFromCollection(collectionID, objectID: objectID)
                }
            )
            LociButton("Refresh", style: .secondary) { Task { await reload() } }
                .disabled(isBusy)
            if let errorMessage {
                Text(errorMessage)
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.danger)
            }
        }
        .padding(LociSpacing.stack(.xl))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task { await reload() }
        .onChange(of: selectedCollectionID) { _, _ in
            Task { await reload() }
        }
        .onChange(of: sortKey) { _, _ in
            guard didLoad else { return }
            Task { await persistAndReload() }
        }
        .onChange(of: groupByKey) { _, _ in
            guard didLoad else { return }
            Task { await persistAndReload() }
        }
    }

    @ViewBuilder
    private var featureFacades: some View {
        if let type {
            PropertiesFeature.defsEditor(services: services, typeID: type.id)
                .padding(.vertical, LociSpacing.stack(.sm))
            TemplatesFeature.editor(services: services, typeID: type.id)
                .padding(.vertical, LociSpacing.stack(.sm))
        }
        CollectionsFeature.tabs(
            services: services,
            typeID: typeID,
            allObjects: objects,
            selectedCollectionID: $selectedCollectionID,
            onChanged: { await reload() }
        )
        .padding(.vertical, LociSpacing.stack(.sm))
        QueriesFeature.pinned(
            services: services,
            typeID: typeID,
            onOpen: { id in await services.open(objectID: id) }
        )
        .padding(.vertical, LociSpacing.stack(.sm))
    }

    private func queryState(memberIDs: [ObjectID]?) -> TypeDashboardStore.QueryState {
        TypeDashboardStore.QueryState(
            sortKey: sortKey,
            groupBy: groupByKey == "none" ? nil : groupByKey,
            filterKey: filterKey.isEmpty ? nil : filterKey,
            filterText: filterText,
            tagFilter: activeTagFilter,
            collectionMemberIDs: memberIDs
        )
    }

    private func applyDashboardDefaults(from type: ObjectType) {
        if let stored = type.dashboard.defaultSort, !stored.isEmpty {
            sortKey = DashboardSort.isBuiltIn(stored)
                ? DashboardSort.querySort(from: stored).rawValue
                : stored
        }
        if let stored = type.dashboard.defaultGroupBy, !stored.isEmpty {
            groupByKey = stored
        }
        if let stored = type.dashboard.defaultFilterKey, !stored.isEmpty {
            filterKey = stored
        }
        if let stored = type.dashboard.defaultFilterText {
            filterText = stored
        }
    }

    private func reload() async {
        isBusy = true
        defer { isBusy = false }
        do {
            if !didLoad {
                let loaded = try await services.schema.loadType(typeID)
                applyDashboardDefaults(from: loaded)
            }
            let collection = try await store.loadCollection(selectedCollectionID)
            activeCollection = collection
            let snap = try await store.load(
                typeID: typeID,
                state: queryState(memberIDs: collection?.memberIDs)
            )
            type = snap.type
            objects = snap.allObjects
            sections = snap.sections
            hideArchived = snap.hideArchived
            archivedHiddenCount = snap.archivedHiddenCount
            if activeTagFilter != nil {
                let untagged = try await store.load(
                    typeID: typeID,
                    state: TypeDashboardStore.QueryState(
                        sortKey: sortKey,
                        groupBy: nil,
                        filterKey: filterKey.isEmpty ? nil : filterKey,
                        filterText: filterText,
                        tagFilter: nil,
                        collectionMemberIDs: collection?.memberIDs
                    )
                )
                tagFilterHiddenCount = untagged.allObjects.count - snap.allObjects.count
            } else {
                tagFilterHiddenCount = 0
            }
            didLoad = true
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func persistAndReload() async {
        guard let type else {
            await reload()
            return
        }
        do {
            self.type = try await store.persistDefaults(
                type: type,
                sortKey: sortKey,
                groupBy: groupByKey == "none" ? nil : groupByKey,
                filterKey: filterKey.isEmpty ? nil : filterKey,
                filterText: filterText
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        await reload()
    }

    private func removeFromCollection(_ collectionID: String, objectID: ObjectID) async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await CollectionsFeature.removeMember(
                services: services,
                collectionID: collectionID,
                objectID: objectID
            )
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applyTagFilter() {
        let n = TagNormalization.normalize(tagFilterDraft)
        activeTagFilter = n.isEmpty ? nil : n
        Task { await reload() }
    }

    private func createObject() async {
        isBusy = true
        defer { isBusy = false }
        do {
            if typeID == .daily {
                _ = try await services.ensureTodayDailyNote()
            } else {
                _ = try await services.createObject(typeID: typeID, title: "Untitled")
            }
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func rename() async {
        isBusy = true
        defer { isBusy = false }
        do {
            type = try await services.schema.renameType(typeID, name: renameDraft)
            showRename = false
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteType() async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await services.schema.deleteType(typeID, force: false)
            services.focusedTypeID = nil
            onBack()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
