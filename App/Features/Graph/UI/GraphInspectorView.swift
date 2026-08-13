import SwiftUI
import LociCore
import LociDesignSystem

/// Graph inspector — selected node + caps + hide-hubs (PR45).
struct GraphInspectorView: View {
    @Bindable var services: AppServices

    @State private var snapshot = GraphSnapshot()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LociSpacing.stack(.md)) {
                Text("Graph")
                    .font(LociTypography.font(.overline))
                    .tracking(0.08)
                    .foregroundStyle(LociColors.inkSoft)

                if let node = selectedNode {
                    Text(node.title)
                        .font(LociTypography.font(.headline))
                        .foregroundStyle(LociColors.ink)
                        .accessibilityIdentifier("graph-inspector-title")
                    Text(node.typeID.rawValue)
                        .font(LociTypography.font(.callout))
                        .foregroundStyle(LociColors.inkSoft)
                        .accessibilityIdentifier("graph-inspector-type")
                    Text("Degree \(snapshot.degree(of: node.id)) · \(snapshot.neighborCount(of: node.id)) neighbors")
                        .font(LociTypography.font(.caption))
                        .foregroundStyle(LociColors.inkSoft)
                        .accessibilityIdentifier("graph-inspector-degree")
                    Button("Open") {
                        Task { await services.open(objectID: node.id) }
                    }
                    .font(LociTypography.font(.caption))
                    .accessibilityIdentifier("graph-inspector-open")
                } else {
                    Text("Links table")
                        .font(LociTypography.font(.headline))
                        .foregroundStyle(LociColors.ink)
                    Text("Tap a node to select it. Open still uses Navigating.open(objectID:).")
                        .font(LociTypography.font(.callout))
                        .foregroundStyle(LociColors.inkSoft)
                }

                LociDivider()

                flagRow(
                    label: "Truncated",
                    on: snapshot.truncated,
                    id: "graph-inspector-truncated"
                )
                flagRow(
                    label: "Hidden hubs",
                    on: snapshot.hiddenHubs,
                    id: "graph-inspector-hidden-hubs"
                )
                flagRow(
                    label: "Focus neighbors",
                    on: snapshot.isolatedFocus,
                    id: "graph-inspector-isolated-focus"
                )

                Text(
                    "Default caps: 150 nodes · 400 edges. Hide hubs / focus are session-only — layout is never written to markdown. Index never lives in the vault."
                )
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
        .task(id: reloadToken) {
            await reload()
        }
        .accessibilityIdentifier("graph-inspector")
    }

    private var selectedNode: GraphNode? {
        guard let id = services.graphSelectedObjectID else { return nil }
        return snapshot.node(id: id)
    }

    private var reloadToken: String {
        let hide = services.graphHideHubs ? "\(services.graphHideDegree)" : "off"
        let focus =
            services.graphFocusNeighbors
            ? (services.graphSelectedObjectID?.uuidString.lowercased() ?? "none")
            : "off"
        let selected = services.graphSelectedObjectID?.uuidString.lowercased() ?? "none"
        return "\(hide)|\(focus)|\(selected)|\(services.index == nil ? "0" : "1")"
    }

    private func flagRow(label: String, on: Bool, id: String) -> some View {
        HStack {
            Text(label)
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.inkSoft)
            Spacer(minLength: 0)
            Text(on ? "yes" : "no")
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.ink)
                .accessibilityIdentifier(id)
        }
    }

    private func reload() async {
        do {
            _ = try await services.ensureIndex()
            let store = GraphStore(index: services.index)
            snapshot = try await store.load(
                options: GraphBuildOptions(
                    hideDegreeAtOrAbove: services.graphHideHubs ? services.graphHideDegree : nil,
                    focusObjectID: services.graphFocusNeighbors
                        ? services.graphSelectedObjectID : nil
                )
            )
        } catch {
            snapshot = GraphSnapshot()
        }
    }
}
