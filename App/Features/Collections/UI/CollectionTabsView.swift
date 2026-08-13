import SwiftUI
import LociCore
import LociDesignSystem

/// Collection tabs + create/delete + membership add/remove for a type dashboard (PR22).
struct CollectionTabsView: View {
    var services: AppServices
    let typeID: ObjectTypeID
    let allObjects: [LociObjectMeta]
    @Binding var selectedCollectionID: String?
    var onChanged: () async -> Void

    @State private var collections: [ObjectCollection] = []
    @State private var newName: String = ""
    @State private var newSlug: String = ""
    @State private var showCreate = false
    @State private var errorMessage: String?
    @State private var isBusy = false
    @State private var addPickerID: ObjectID?

    private var store: CollectionStore { CollectionStore(schema: services.schema) }

    private var activeCollection: ObjectCollection? {
        guard let selectedCollectionID else { return nil }
        return collections.first { $0.id == selectedCollectionID }
    }

    private var candidatesToAdd: [LociObjectMeta] {
        guard let active = activeCollection else { return [] }
        let members = Set(active.memberIDs)
        return allObjects.filter { !members.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.md)) {
            Text("COLLECTIONS")
                .font(LociTypography.font(.overline))
                .tracking(0.08)
                .foregroundStyle(LociColors.inkSoft)

            Text("Membership lives in `.loci/collections/<type>.<slug>.json` — vault truth, not the index.")
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.inkSoft)
                .frame(maxWidth: 520, alignment: .leading)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: LociSpacing.stack(.sm)) {
                    tabButton(title: "All", id: nil)
                    ForEach(collections, id: \.id) { collection in
                        tabButton(title: collection.name, id: collection.id)
                    }
                    LociButton(showCreate ? "Cancel" : "+ Collection", style: .secondary) {
                        showCreate.toggle()
                    }
                    .disabled(isBusy)
                }
            }

            if showCreate {
                HStack(spacing: LociSpacing.stack(.md)) {
                    TextField("Name", text: $newName)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 180)
                    TextField("Slug (optional)", text: $newSlug)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 140)
                    LociButton("Create", style: .primary) {
                        Task { await createCollection() }
                    }
                    .disabled(isBusy || newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            if let active = activeCollection {
                membershipChrome(active)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.danger)
            }
        }
        .task { await reload() }
        .onChange(of: typeID) { _, _ in
            selectedCollectionID = nil
            Task { await reload() }
        }
    }

    private func tabButton(title: String, id: String?) -> some View {
        let isSelected = selectedCollectionID == id
        return Button {
            selectedCollectionID = id
        } label: {
            Text(title)
                .font(LociTypography.font(.callout))
                .foregroundStyle(isSelected ? LociColors.surface : LociColors.ink)
                .padding(.horizontal, LociSpacing.stack(.md))
                .padding(.vertical, LociSpacing.stack(.sm))
                .background(isSelected ? LociColors.accent : LociColors.inkSoft.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id.map { "collection-tab-\($0)" } ?? "collection-tab-all")
    }

    @ViewBuilder
    private func membershipChrome(_ collection: ObjectCollection) -> some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.sm)) {
            HStack(spacing: LociSpacing.stack(.md)) {
                Text("\(collection.memberIDs.count) members · \(collection.id)")
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.inkSoft)
                Spacer(minLength: 0)
                LociButton("Delete collection", style: .secondary) {
                    Task { await deleteCollection(collection.id) }
                }
                .disabled(isBusy)
            }

            if candidatesToAdd.isEmpty {
                Text("All objects of this type are already in this collection.")
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.inkSoft)
            } else {
                HStack(spacing: LociSpacing.stack(.md)) {
                    Picker("Add object", selection: $addPickerID) {
                        Text("Add object…").tag(Optional<ObjectID>.none)
                        ForEach(candidatesToAdd, id: \.id) { item in
                            Text(item.title.isEmpty ? "Untitled" : item.title)
                                .tag(Optional(item.id))
                        }
                    }
                    .frame(maxWidth: 280)
                    LociButton("Add", style: .primary) {
                        Task { await addSelected() }
                    }
                    .disabled(isBusy || addPickerID == nil)
                }
            }
        }
        .padding(.vertical, LociSpacing.stack(.xs))
    }

    private func reload() async {
        do {
            collections = try await store.list(typeID: typeID)
            if let selectedCollectionID,
                !collections.contains(where: { $0.id == selectedCollectionID })
            {
                self.selectedCollectionID = nil
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func createCollection() async {
        isBusy = true
        defer { isBusy = false }
        do {
            let slug = newSlug.trimmingCharacters(in: .whitespacesAndNewlines)
            let created = try await store.create(
                typeID: typeID,
                name: newName,
                slug: slug.isEmpty ? nil : slug
            )
            newName = ""
            newSlug = ""
            showCreate = false
            selectedCollectionID = created.id
            await reload()
            await onChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteCollection(_ id: String) async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await store.delete(id)
            if selectedCollectionID == id {
                selectedCollectionID = nil
            }
            await reload()
            await onChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func addSelected() async {
        guard let selectedCollectionID, let addPickerID else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            _ = try await store.add(collectionID: selectedCollectionID, objectID: addPickerID)
            self.addPickerID = nil
            await reload()
            await onChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
