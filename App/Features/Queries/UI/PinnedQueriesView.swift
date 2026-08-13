import SwiftUI
import LociCore
import LociDesignSystem

/// Pinned saved queries on a type dashboard (PR23).
///
/// Definitions are vault JSON; the object list is live from `IndexQuerying`.
struct PinnedQueriesView: View {
    var services: AppServices
    let typeID: ObjectTypeID
    var onOpen: (ObjectID) async -> Void

    @State private var queries: [SavedQuery] = []
    @State private var selectedID: String?
    @State private var results: [LociObjectMeta] = []
    @State private var newName: String = ""
    @State private var newTag: String = ""
    @State private var showCreate = false
    @State private var errorMessage: String?
    @State private var isBusy = false

    private var store: QueryStore {
        QueryStore(schema: services.schema, index: services.index)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.md)) {
            Text("PINNED QUERIES")
                .font(LociTypography.font(.overline))
                .tracking(0.08)
                .foregroundStyle(LociColors.inkSoft)

            Text(
                "Saved filters in `.loci/queries/<slug>.json` — results are live from the index, not stored in the vault file."
            )
            .font(LociTypography.font(.caption))
            .foregroundStyle(LociColors.inkSoft)
            .frame(maxWidth: 520, alignment: .leading)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: LociSpacing.stack(.sm)) {
                    ForEach(queries, id: \.id) { query in
                        queryChip(query)
                    }
                    LociButton(showCreate ? "Cancel" : "+ Query", style: .secondary) {
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
                    TextField("#tag filter (optional)", text: $newTag)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 160)
                    LociButton("Create & pin", style: .primary) {
                        Task { await createPinned() }
                    }
                    .disabled(isBusy || newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            if let selected = queries.first(where: { $0.id == selectedID }) {
                VStack(alignment: .leading, spacing: LociSpacing.stack(.sm)) {
                    HStack {
                        Text("\(selected.name) · \(selected.id) · \(results.count) hits")
                            .font(LociTypography.font(.caption))
                            .foregroundStyle(LociColors.inkSoft)
                        Spacer(minLength: 0)
                        LociButton("Unpin", style: .secondary) {
                            Task { await unpin(selected.id) }
                        }
                        .disabled(isBusy)
                    }
                    if results.isEmpty {
                        Text("No matches (query is live — add objects that fit the filter).")
                            .font(LociTypography.font(.caption))
                            .foregroundStyle(LociColors.inkSoft)
                    } else {
                        ForEach(results, id: \.id.uuidString) { item in
                            Button {
                                Task { await onOpen(item.id) }
                            } label: {
                                Text(item.title.isEmpty ? "Untitled" : item.title)
                                    .font(LociTypography.font(.callout))
                                    .foregroundStyle(LociColors.ink)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("pinned-query-hit-\(item.id.uuidString.lowercased())")
                        }
                    }
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.danger)
            }
        }
        .task { await reload() }
        .onChange(of: typeID) { _, _ in
            selectedID = nil
            Task { await reload() }
        }
        .onChange(of: selectedID) { _, _ in
            Task { await runSelected() }
        }
    }

    private func queryChip(_ query: SavedQuery) -> some View {
        let isSelected = selectedID == query.id
        return Button {
            selectedID = query.id
        } label: {
            Text(query.name)
                .font(LociTypography.font(.callout))
                .foregroundStyle(isSelected ? LociColors.surface : LociColors.ink)
                .padding(.horizontal, LociSpacing.stack(.md))
                .padding(.vertical, LociSpacing.stack(.sm))
                .background(isSelected ? LociColors.accent : LociColors.inkSoft.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("pinned-query-\(query.id)")
    }

    private func reload() async {
        isBusy = true
        defer { isBusy = false }
        do {
            _ = try await services.ensureIndex()
            queries = try await store.listPinned(typeID: typeID)
            if selectedID == nil {
                selectedID = queries.first?.id
            } else if !queries.contains(where: { $0.id == selectedID }) {
                selectedID = queries.first?.id
            }
            await runSelected()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func runSelected() async {
        guard let selectedID,
            let query = queries.first(where: { $0.id == selectedID })
        else {
            results = []
            return
        }
        do {
            results = try await store.execute(query)
        } catch {
            results = []
            errorMessage = error.localizedDescription
        }
    }

    private func createPinned() async {
        isBusy = true
        defer { isBusy = false }
        let tag = TagNormalization.normalize(newTag)
        var definition = QueryDefinition(typeID: typeID, sort: .titleAsc)
        if !tag.isEmpty {
            definition.tags = [tag]
        }
        do {
            let created = try await store.create(
                name: newName,
                definition: definition,
                slug: nil,
                pinnedTypeID: typeID
            )
            newName = ""
            newTag = ""
            showCreate = false
            selectedID = created.id
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func unpin(_ id: String) async {
        isBusy = true
        defer { isBusy = false }
        do {
            _ = try await store.setPinned(id, typeID: nil)
            if selectedID == id { selectedID = nil }
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
