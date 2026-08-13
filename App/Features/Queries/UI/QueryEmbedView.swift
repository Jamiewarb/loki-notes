import SwiftUI
import LociCore
import LociDesignSystem

/// Live `/query` embed renderer — slug in markdown, results from index (PR23).
struct QueryEmbedView: View {
    var services: AppServices
    let queryID: String
    var onOpen: (ObjectID) async -> Void

    @State private var query: SavedQuery?
    @State private var results: [LociObjectMeta] = []
    @State private var errorMessage: String?
    @State private var isLoading = true

    private var store: QueryStore {
        QueryStore(schema: services.schema, index: services.index)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.sm)) {
            HStack(spacing: LociSpacing.stack(.sm)) {
                Text("/query")
                    .font(LociTypography.font(.overline))
                    .foregroundStyle(LociColors.accent)
                Text(query?.name ?? queryID)
                    .font(LociTypography.font(.callout))
                    .foregroundStyle(LociColors.ink)
                Spacer(minLength: 0)
                Text(isLoading ? "…" : "\(results.count)")
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.inkSoft)
            }

            Text("Live from index · definition `.loci/queries/\(queryID).json`")
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.inkSoft)

            if let errorMessage {
                Text(errorMessage)
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.danger)
            } else if !isLoading && results.isEmpty {
                Text("No matches")
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.inkSoft)
            } else {
                ForEach(results.prefix(12), id: \.id.uuidString) { item in
                    Button {
                        Task { await onOpen(item.id) }
                    } label: {
                        Text(item.title.isEmpty ? "Untitled" : item.title)
                            .font(LociTypography.font(.body))
                            .foregroundStyle(LociColors.ink)
                    }
                    .buttonStyle(.plain)
                }
                if results.count > 12 {
                    Text("+\(results.count - 12) more")
                        .font(LociTypography.font(.caption))
                        .foregroundStyle(LociColors.inkSoft)
                }
            }
        }
        .padding(LociSpacing.stack(.md))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LociColors.inkSoft.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityIdentifier("query-embed-\(queryID)")
        .task(id: queryID) { await reload() }
    }

    private func reload() async {
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await services.ensureIndex()
            let loaded = try await store.load(queryID)
            query = loaded
            results = try await store.execute(loaded)
            errorMessage = nil
        } catch {
            query = nil
            results = []
            errorMessage = error.localizedDescription
        }
    }
}
