import SwiftUI
import LociCore
import LociDesignSystem

/// Global FTS search destination (⌘K / Search tab). Reads `IndexQuerying.search` only.
struct SearchView: View {
    var services: AppServices

    @State private var query: String = ""
    @State private var hits: [LociObjectMeta] = []
    @State private var errorMessage: String?
    @State private var isSearching = false
    @State private var filterTypeID: ObjectTypeID?
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.lg)) {
            HStack(spacing: LociSpacing.stack(.md)) {
                LociIcon(Route.search.systemImage, size: 22)
                    .foregroundStyle(LociColors.accent)
                Text(Route.search.title)
                    .font(LociTypography.font(.display))
                    .foregroundStyle(LociColors.ink)
                Spacer(minLength: 0)
                Text("⌘K")
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.inkSoft)
                    .accessibilityHidden(true)
            }
            .lociAppear(.soft)

            Text("Full-text index over titles and bodies. Index lives in Application Support — never in the vault.")
                .font(LociTypography.font(.body))
                .foregroundStyle(LociColors.inkSoft)
                .frame(maxWidth: 520, alignment: .leading)

            LociTextField("Query", text: $query, placeholder: "Search titles and bodies…")
                .focused($fieldFocused)
                .accessibilityIdentifier(LociAccessibilityCatalog.searchQuery)
                .accessibilityLabel(LociAccessibilityCatalog.searchQueryLabel)
                .onSubmit { Task { await runSearch(recordRecent: true) } }

            typeFilterChips

            resultsBody

            if let errorMessage {
                Text(errorMessage)
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.danger)
            }
        }
        .padding(LociSpacing.stack(.xl))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task(id: services.searchFocusNonce) {
            query = services.searchQueryDraft
            filterTypeID = services.searchFilterTypeID
            fieldFocused = true
            if !SearchRanking.normalizeQuery(query).isEmpty {
                await runSearch(recordRecent: false)
            }
        }
        .task(id: queryTaskID) {
            // Debounce: never block typing; await a short pause then query index.
            let snapshot = query
            try? await Task.sleep(nanoseconds: 180_000_000)
            guard !Task.isCancelled else { return }
            guard snapshot == query else { return }
            services.searchQueryDraft = snapshot
            await runSearch(recordRecent: false)
        }
        .onChange(of: filterTypeID) { _, newValue in
            services.searchFilterTypeID = newValue
        }
        .accessibilityIdentifier(LociAccessibilityCatalog.search)
        .accessibilityLabel(LociAccessibilityCatalog.searchLabel)
    }

    private var queryTaskID: String {
        "\(query)|\(filterTypeID?.rawValue ?? "")|\(services.searchFocusNonce)"
    }

    private var groups: [SearchResultGroup] {
        let filtered = SearchGrouping.filter(hits, typeID: filterTypeID)
        let ranked = SearchRanking.preferTitleMatches(filtered, query: query)
        return SearchGrouping.byType(ranked)
    }

    @ViewBuilder
    private var typeFilterChips: some View {
        let types = Array(Set(hits.map(\.typeID))).sorted { $0.rawValue < $1.rawValue }
        if !types.isEmpty || filterTypeID != nil {
            HStack(spacing: LociSpacing.stack(.sm)) {
                filterChip(label: "All", selected: filterTypeID == nil) {
                    filterTypeID = nil
                }
                ForEach(types, id: \.rawValue) { typeID in
                    filterChip(
                        label: typeID.rawValue.capitalized,
                        selected: filterTypeID == typeID
                    ) {
                        filterTypeID = typeID
                    }
                }
            }
            .accessibilityIdentifier("search-type-filters")
        }
    }

    private func filterChip(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(LociTypography.font(.caption))
                .foregroundStyle(selected ? LociColors.paper : LociColors.inkSoft)
                .padding(.horizontal, LociSpacing.stack(.md))
                .padding(.vertical, LociSpacing.stack(.sm))
                .background(selected ? LociColors.accent : LociColors.panel)
                .clipShape(RoundedRectangle(cornerRadius: LociRadius.control, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: LociRadius.control, style: .continuous)
                        .strokeBorder(LociColors.line, lineWidth: selected ? 0 : 1)
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var resultsBody: some View {
        let q = SearchRanking.normalizeQuery(query)
        if q.isEmpty {
            if services.recentSearches.queries.isEmpty {
                LociEmptyState(
                    title: "Search the vault",
                    message: "Type to query the local FTS index. Results group by type; select to open.",
                    systemImage: Route.search.systemImage
                )
            } else {
                recentList
            }
        } else if isSearching && hits.isEmpty {
            ProgressView()
                .controlSize(.small)
                .padding(.top, LociSpacing.stack(.md))
        } else if groups.isEmpty {
            LociEmptyState(
                title: "No matches",
                message: "Nothing in the index matched “\(q)”.",
                systemImage: Route.search.systemImage
            )
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: LociSpacing.stack(.lg)) {
                    ForEach(groups, id: \.typeID.rawValue) { group in
                        VStack(alignment: .leading, spacing: LociSpacing.stack(.sm)) {
                            Text(group.title)
                                .font(LociTypography.font(.overline))
                                .tracking(0.08)
                                .foregroundStyle(LociColors.inkSoft)
                                .accessibilityIdentifier("search-group-\(group.typeID.rawValue)")

                            ForEach(group.items, id: \.id.uuidString) { item in
                                resultRow(item)
                            }
                        }
                    }
                }
                .lociAppear(.soft)
            }
        }
    }

    private var recentList: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.sm)) {
            Text("Recent")
                .font(LociTypography.font(.overline))
                .tracking(0.08)
                .foregroundStyle(LociColors.inkSoft)
            ForEach(services.recentSearches.queries, id: \.self) { recent in
                Button {
                    query = recent
                    services.searchQueryDraft = recent
                    Task { await runSearch(recordRecent: true) }
                } label: {
                    HStack {
                        LociIcon("clock", size: 14)
                            .foregroundStyle(LociColors.inkSoft)
                        Text(recent)
                            .font(LociTypography.font(.body))
                            .foregroundStyle(LociColors.ink)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, LociSpacing.stack(.sm))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("search-recent-\(recent)")
            }
        }
    }

    private func resultRow(_ item: LociObjectMeta) -> some View {
        Button {
            Task {
                services.recordRecentSearch(query)
                await services.open(objectID: item.id)
            }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: LociSpacing.stack(.md)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title.isEmpty ? "Untitled" : item.title)
                        .font(LociTypography.font(.headline))
                        .foregroundStyle(LociColors.ink)
                    Text(item.relativePath)
                        .font(LociTypography.font(.caption))
                        .foregroundStyle(LociColors.inkSoft)
                }
                Spacer(minLength: 0)
                if SearchRanking.titleMatches(item.title, query: query) {
                    Text("title")
                        .font(LociTypography.font(.caption))
                        .foregroundStyle(LociColors.accent)
                }
            }
            .padding(.vertical, LociSpacing.stack(.sm))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("search-hit-\(item.id.uuidString.lowercased())")
    }

    private func runSearch(recordRecent: Bool) async {
        let q = SearchRanking.normalizeQuery(query)
        guard !q.isEmpty else {
            hits = []
            errorMessage = nil
            isSearching = false
            return
        }
        isSearching = true
        defer { isSearching = false }
        do {
            let index = try await services.ensureIndex()
            // Raw FTS order from index; UI applies title preference + grouping.
            hits = try await index.search(query: q)
            if recordRecent {
                services.recordRecentSearch(q)
            }
            errorMessage = nil
        } catch {
            hits = []
            errorMessage = error.localizedDescription
        }
    }
}
