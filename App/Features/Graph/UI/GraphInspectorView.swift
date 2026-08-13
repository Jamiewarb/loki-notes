import SwiftUI
import LociCore
import LociDesignSystem

/// Graph inspector — caps + navigation hint (PR24).
struct GraphInspectorView: View {
    var services: AppServices

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LociSpacing.stack(.md)) {
                Text("Graph")
                    .font(LociTypography.font(.overline))
                    .tracking(0.08)
                    .foregroundStyle(LociColors.inkSoft)

                Text("Links table")
                    .font(LociTypography.font(.headline))
                    .foregroundStyle(LociColors.ink)

                Text(
                    "Nodes and edges come from `IndexQuerying.graph` over the disposable links projection. Type filters and node/edge caps keep layout cheap. Selecting a node calls `Navigating.open(objectID:)`."
                )
                .font(LociTypography.font(.callout))
                .foregroundStyle(LociColors.inkSoft)

                LociDivider()

                Text("Default caps: 150 nodes · 400 edges. Index never lives in the vault.")
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.inkSoft)

                if services.index == nil {
                    Text("Index not ready — open or create a vault first.")
                        .font(LociTypography.font(.caption))
                        .foregroundStyle(LociColors.danger)
                }
            }
            .padding(LociSpacing.stack(.lg))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(LociColors.panel.opacity(0.55))
        .lociAppear(.panel)
        .accessibilityIdentifier("graph-inspector")
    }
}
