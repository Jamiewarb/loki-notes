import SwiftUI
import LociCore
import LociDesignSystem
import LociVault

/// Type dashboard: All objects of this type + collection tabs (PR12 / PR22).
struct TypeDashboardView: View {
    var services: AppServices
    let typeID: ObjectTypeID
    var onBack: () -> Void

    @State private var type: ObjectType?
    @State private var objects: [LociObjectMeta] = []
    @State private var renameDraft: String = ""
    @State private var errorMessage: String?
    @State private var isBusy = false
    @State private var showRename = false
    @State private var hideArchived = false
    @State private var archivedHiddenCount = 0
    @State private var tagFilterDraft: String = ""
    @State private var activeTagFilter: String?
    @State private var tagAliases = TagAliasTable.empty
    @State private var tagFilterHiddenCount = 0
    @State private var selectedCollectionID: String?
    @State private var activeCollection: ObjectCollection?

    private var displayedObjects: [LociObjectMeta] {
        guard let activeCollection else { return objects }
        let order = Dictionary(
            uniqueKeysWithValues: activeCollection.memberIDs.enumerated().map { ($0.element, $0.offset) }
        )
        return objects
            .filter { order[$0.id] != nil }
            .sorted { (order[$0.id] ?? 0) < (order[$1.id] ?? 0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.lg)) {
            HStack(spacing: LociSpacing.stack(.md)) {
                LociButton("← Types", style: .secondary) { onBack() }
                Spacer(minLength: 0)
                if let type, !type.isBuiltIn {
                    LociButton("Rename", style: .secondary) {
                        renameDraft = type.name
                        showRename = true
                    }
                    .disabled(isBusy)
                    LociButton("Delete", style: .secondary) {
                        Task { await deleteType() }
                    }
                    .disabled(isBusy)
                }
                LociButton("New \(type?.name ?? "object")", style: .primary) {
                    Task { await createObject() }
                }
                .disabled(isBusy)
            }

            HStack(spacing: LociSpacing.stack(.md)) {
                LociIcon(type?.icon ?? "square.grid.2x2", size: 22)
                    .foregroundStyle(LociColors.accent)
                Text(type?.name ?? typeID.rawValue)
                    .font(LociTypography.font(.display))
                    .foregroundStyle(LociColors.ink)
            }
            .lociAppear(.soft)

            Text(".\(typeID.rawValue) · objects live under objects/\(typeID.rawValue)/ — filesystem sharding only.")
                .font(LociTypography.font(.body))
                .foregroundStyle(LociColors.inkSoft)
                .frame(maxWidth: 520, alignment: .leading)

            HStack(spacing: LociSpacing.stack(.sm)) {
                TextField("Filter by #tag", text: $tagFilterDraft)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 220)
                    .onSubmit { applyTagFilter() }
                LociButton("Filter", style: .secondary) { applyTagFilter() }
                if activeTagFilter != nil {
                    LociButton("Clear", style: .secondary) {
                        tagFilterDraft = ""
                        activeTagFilter = nil
                        Task { await reload() }
                    }
                }
            }

            if let activeTagFilter {
                Text(
                    tagFilterHiddenCount > 0
                        ? "Showing \(TagNormalization.display(activeTagFilter)) · \(tagFilterHiddenCount) hidden."
                        : "Showing \(TagNormalization.display(activeTagFilter))."
                )
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.inkSoft)
            }

            if hideArchived {
                Text(
                    archivedHiddenCount > 0
                        ? "Hiding \(archivedHiddenCount) archived (#archive / status=Archived)."
                        : "Archived objects hidden by default (PARA)."
                )
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.inkSoft)
            }

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
                onChanged: { await reloadCollections() }
            )
            .padding(.vertical, LociSpacing.stack(.sm))

            QueriesFeature.pinned(
                services: services,
                typeID: typeID,
                onOpen: { id in await services.open(objectID: id) }
            )
            .padding(.vertical, LociSpacing.stack(.sm))

            if showRename {
                HStack(spacing: LociSpacing.stack(.md)) {
                    TextField("Type name", text: $renameDraft)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 280)
                    LociButton("Save name", style: .primary) {
                        Task { await rename() }
                    }
                    .disabled(isBusy)
                    LociButton("Cancel", style: .secondary) { showRename = false }
                }
            }

            sectionHeader(activeCollection.map { $0.name.uppercased() } ?? "All")
            if displayedObjects.isEmpty {
                LociEmptyState(
                    title: activeCollection == nil
                        ? "No \(type?.name ?? "objects") yet"
                        : "Empty collection",
                    message: activeCollection == nil
                        ? "Create one to write markdown under objects/\(typeID.rawValue)/."
                        : "Add objects from the collection controls above.",
                    systemImage: type?.icon ?? "doc"
                )
            } else {
                VStack(alignment: .leading, spacing: LociSpacing.stack(.sm)) {
                    ForEach(displayedObjects, id: \.id.uuidString) { item in
                        objectRow(item)
                    }
                }
                .lociAppear(.soft)
            }

            sectionHeader("Recently opened")
            Text("Stub — session recents land with navigation polish. Use All for now.")
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.inkSoft)

            LociButton("Refresh", style: .secondary) {
                Task { await reload() }
            }
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
            Task { await reloadCollections() }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(LociTypography.font(.overline))
            .tracking(0.08)
            .foregroundStyle(LociColors.inkSoft)
            .padding(.top, LociSpacing.stack(.sm))
    }

    @ViewBuilder
    private func objectRow(_ item: LociObjectMeta) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: LociSpacing.stack(.md)) {
            Button {
                Task { await services.open(objectID: item.id) }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: LociSpacing.stack(.md)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title.isEmpty ? "Untitled" : item.title)
                            .font(LociTypography.font(.headline))
                            .foregroundStyle(LociColors.ink)
                        Text(propertyPreview(item))
                            .font(LociTypography.font(.caption))
                            .foregroundStyle(LociColors.inkSoft)
                        Text(item.relativePath)
                            .font(LociTypography.font(.caption))
                            .foregroundStyle(LociColors.inkSoft)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, LociSpacing.stack(.sm))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("type-object-\(item.id.uuidString.lowercased())")

            if let selectedCollectionID {
                LociButton("Remove", style: .secondary) {
                    Task { await removeFromCollection(selectedCollectionID, objectID: item.id) }
                }
                .disabled(isBusy)
            }
        }
    }

    private func propertyPreview(_ item: LociObjectMeta) -> String {
        guard let type, !type.properties.isEmpty else { return "" }
        let bits = type.properties.prefix(3).compactMap { def -> String? in
            guard let value = item.properties[def.id] else { return nil }
            let shown = PropertyValueFormatting.displayString(value)
            guard !shown.isEmpty else { return nil }
            return "\(def.name): \(shown)"
        }
        return bits.joined(separator: " · ")
    }

    private func reload() async {
        isBusy = true
        defer { isBusy = false }
        do {
            _ = try await services.ensureIndex()
            type = try await services.schema.loadType(typeID)
            let space = try? await services.schema.loadSpaceSettings()
            hideArchived = (type?.dashboard.hideArchived == true) || (space?.hideArchived == true)
            tagAliases = space?.tagAliasTable ?? .empty
            let all = try await services.index?.objects(typeID: typeID) ?? []
            let unarchived = ArchiveFilter.visible(all, hideArchived: hideArchived)
            archivedHiddenCount = all.count - unarchived.count
            let filtered = TagFilter.visible(unarchived, tag: activeTagFilter, aliases: tagAliases)
            tagFilterHiddenCount = unarchived.count - filtered.count
            objects = filtered
            await reloadCollections()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func reloadCollections() async {
        do {
            if let selectedCollectionID {
                activeCollection = try await services.schema.loadCollection(selectedCollectionID)
            } else {
                activeCollection = nil
            }
        } catch {
            activeCollection = nil
            errorMessage = error.localizedDescription
        }
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
            await reloadCollections()
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
