import SwiftUI
import LociCore
import LociDesignSystem

/// Search inspector — recent queries + type filter hint (PR18). No vault writes.
struct SearchInspectorView: View {
    var services: AppServices

    var body: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.md)) {
            Text("Inspector")
                .font(LociTypography.font(.overline))
                .tracking(0.08)
                .foregroundStyle(LociColors.inkSoft)

            Text("Recent & filters")
                .font(LociTypography.font(.headline))
                .foregroundStyle(LociColors.ink)

            Text(
                "Queries hit `IndexQuerying.search` (FTS5). Results group by type; selecting a row navigates via `Navigating.open`."
            )
            .font(LociTypography.font(.callout))
            .foregroundStyle(LociColors.inkSoft)
            .fixedSize(horizontal: false, vertical: true)

            LociDivider()

            if services.recentSearches.queries.isEmpty {
                Text("No recent searches yet.")
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.inkSoft)
            } else {
                Text("Recent")
                    .font(LociTypography.font(.overline))
                    .tracking(0.08)
                    .foregroundStyle(LociColors.inkSoft)
                ForEach(services.recentSearches.queries, id: \.self) { recent in
                    Button {
                        services.searchQueryDraft = recent
                        services.requestSearchFocus()
                        Task { await services.open(route: .search) }
                    } label: {
                        Text(recent)
                            .font(LociTypography.font(.body))
                            .foregroundStyle(LociColors.accent)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, LociSpacing.stack(.xs))
                    }
                    .buttonStyle(.plain)
                }
                LociButton("Clear recent", style: .secondary) {
                    services.clearRecentSearches()
                }
            }

            Spacer(minLength: 0)
        }
        .padding(LociSpacing.stack(.lg))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(LociColors.panel.opacity(0.55))
        .lociAppear(.panel)
        .accessibilityIdentifier("search-inspector")
    }
}
