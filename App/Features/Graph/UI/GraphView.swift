import SwiftUI
import LociCore
import LociDesignSystem

/// Force-directed link graph from the local index (PR24 / PR45 polish).
struct GraphView: View {
    @Bindable var services: AppServices

    @State private var snapshot = GraphSnapshot()
    @State private var layout = GraphLayoutResult()
    @State private var typeFilter: ObjectTypeID?
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var availableTypes: [ObjectTypeID] = []

    private let canvasSize = CGSize(width: 720, height: 480)

    var body: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.lg)) {
            HStack(spacing: LociSpacing.stack(.md)) {
                LociIcon(Route.graph.systemImage, size: 22)
                    .foregroundStyle(LociColors.accent)
                Text(Route.graph.title)
                    .font(LociTypography.font(.display))
                    .foregroundStyle(LociColors.ink)
                Spacer(minLength: 0)
                if snapshot.truncated {
                    Text("capped")
                        .font(LociTypography.font(.caption))
                        .foregroundStyle(LociColors.inkSoft)
                        .accessibilityIdentifier("graph-truncated-badge")
                }
                if snapshot.hiddenHubs {
                    Text("hubs hidden")
                        .font(LociTypography.font(.caption))
                        .foregroundStyle(LociColors.inkSoft)
                        .accessibilityIdentifier("graph-hidden-hubs-badge")
                }
            }
            .lociAppear(.soft)

            Text(
                "Wiki-link network from the local links index. Tap a node to open the object. Hide hubs and focus are session-only — never written to the vault."
            )
            .font(LociTypography.font(.body))
            .foregroundStyle(LociColors.inkSoft)
            .frame(maxWidth: 520, alignment: .leading)

            typeFilterChips
            polishControls

            graphCanvas
                .frame(maxWidth: .infinity)
                .frame(height: canvasSize.height)
                .background(LociColors.panel.opacity(0.45))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(LociColors.ink.opacity(0.08), lineWidth: 1)
                )
                .accessibilityIdentifier("graph-canvas")

            footerStats

            if let errorMessage {
                Text(errorMessage)
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.danger)
            }
        }
        .padding(LociSpacing.stack(.xl))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task(id: reloadToken) {
            await reload()
        }
        .accessibilityIdentifier("graph-destination")
    }

    private var reloadToken: String {
        let hide = services.graphHideHubs ? "\(services.graphHideDegree)" : "off"
        let focus =
            services.graphFocusNeighbors
            ? (services.graphSelectedObjectID?.uuidString.lowercased() ?? "none")
            : "off"
        return "\(typeFilter?.rawValue ?? "all")|\(hide)|\(focus)|\(services.index == nil ? "0" : "1")"
    }

    @ViewBuilder
    private var typeFilterChips: some View {
        let types = availableTypes
        HStack(spacing: LociSpacing.stack(.sm)) {
            filterChip(label: "All", selected: typeFilter == nil) {
                typeFilter = nil
            }
            ForEach(types, id: \.rawValue) { typeID in
                filterChip(
                    label: typeID.rawValue.capitalized,
                    selected: typeFilter == typeID
                ) {
                    typeFilter = typeID
                }
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var polishControls: some View {
        HStack(spacing: LociSpacing.stack(.md)) {
            Toggle("Hide hubs", isOn: $services.graphHideHubs)
                .font(LociTypography.font(.caption))
                .tint(LociColors.accent)
                .accessibilityIdentifier("graph-hide-hubs")
            if services.graphHideHubs {
                Stepper(
                    "degree ≥ \(services.graphHideDegree)",
                    value: $services.graphHideDegree,
                    in: 2...24
                )
                .font(LociTypography.font(.caption))
                .accessibilityIdentifier("graph-hide-degree")
            }
            Toggle("Focus neighbors", isOn: $services.graphFocusNeighbors)
                .font(LociTypography.font(.caption))
                .tint(LociColors.accent)
                .disabled(services.graphSelectedObjectID == nil)
                .accessibilityIdentifier("graph-focus-neighbors")
            Spacer(minLength: 0)
        }
    }

    private func filterChip(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(LociTypography.font(.caption))
                .foregroundStyle(selected ? LociColors.paper : LociColors.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(selected ? LociColors.accent : LociColors.panel)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("graph-filter-\(label.lowercased())")
    }

    private var graphCanvas: some View {
        Canvas { context, size in
            let scaleX = size.width / max(layout.width, 1)
            let scaleY = size.height / max(layout.height, 1)
            let selected = services.graphSelectedObjectID

            for edge in snapshot.edges {
                guard
                    let from = layout.point(for: edge.from),
                    let to = layout.point(for: edge.to)
                else { continue }
                var path = Path()
                path.move(
                    to: CGPoint(x: from.x * scaleX, y: from.y * scaleY)
                )
                path.addLine(
                    to: CGPoint(x: to.x * scaleX, y: to.y * scaleY)
                )
                let incident = selected.map { snapshot.isIncident(edge, to: $0) } ?? false
                context.stroke(
                    path,
                    with: .color(
                        incident ? LociColors.accent : LociColors.inkSoft.opacity(0.45)
                    ),
                    lineWidth: incident ? 2.4 : 1.2
                )
            }

            for node in snapshot.nodes {
                guard let p = layout.point(for: node.id) else { continue }
                let center = CGPoint(x: p.x * scaleX, y: p.y * scaleY)
                let isSelected = selected == node.id
                let radius: CGFloat = isSelected ? 14 : 11
                let rect = CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(isSelected ? LociColors.accent : LociColors.ink)
                )
                context.draw(
                    Text(node.title)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(LociColors.inkSoft),
                    at: CGPoint(x: center.x, y: center.y + radius + 10),
                    anchor: .top
                )
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onEnded { value in
                    if let hit = hitTest(at: value.location, in: canvasSize) {
                        services.graphSelectedObjectID = hit
                        Task { await services.open(objectID: hit) }
                    }
                }
        )
        .overlay {
            if isLoading {
                ProgressView()
                    .tint(LociColors.accent)
            } else if snapshot.isEmpty {
                Text("No resolved wiki-links yet")
                    .font(LociTypography.font(.callout))
                    .foregroundStyle(LociColors.inkSoft)
            }
        }
    }

    private var footerStats: some View {
        HStack(spacing: LociSpacing.stack(.md)) {
            Text("\(snapshot.nodes.count) nodes")
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.inkSoft)
                .accessibilityIdentifier("graph-node-count")
            Text("\(snapshot.edges.count) edges")
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.inkSoft)
                .accessibilityIdentifier("graph-edge-count")
            if snapshot.unresolvedLinkCount > 0 {
                Text("\(snapshot.unresolvedLinkCount) unresolved")
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.inkSoft)
            }
            Spacer(minLength: 0)
        }
    }

    private func hitTest(at point: CGPoint, in size: CGSize) -> ObjectID? {
        let scaleX = size.width / max(layout.width, 1)
        let scaleY = size.height / max(layout.height, 1)
        var best: (ObjectID, CGFloat)?
        for node in snapshot.nodes {
            guard let p = layout.point(for: node.id) else { continue }
            let center = CGPoint(x: p.x * scaleX, y: p.y * scaleY)
            let dx = center.x - point.x
            let dy = center.y - point.y
            let dist = sqrt(dx * dx + dy * dy)
            if dist <= 18 {
                if best == nil || dist < best!.1 {
                    best = (node.id, dist)
                }
            }
        }
        return best?.0
    }

    private func buildOptions() -> GraphBuildOptions {
        GraphBuildOptions(
            typeFilter: typeFilter,
            hideDegreeAtOrAbove: services.graphHideHubs ? services.graphHideDegree : nil,
            focusObjectID: services.graphFocusNeighbors ? services.graphSelectedObjectID : nil
        )
    }

    private func reload() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            _ = try await services.ensureIndex()
            let store = GraphStore(index: services.index)
            let next = try await store.load(options: buildOptions())
            snapshot = next
            layout = GraphLayoutEngine.layout(
                next,
                config: GraphLayoutEngine.Config(
                    width: Double(canvasSize.width),
                    height: Double(canvasSize.height)
                )
            )
            var types = Set(next.nodes.map(\.typeID))
            if let typeFilter { types.insert(typeFilter) }
            availableTypes = types.sorted { $0.rawValue < $1.rawValue }
            if let schemaTypes = try? await services.schema.allTypes() {
                for t in schemaTypes {
                    types.insert(t.id)
                }
                availableTypes = types.sorted { $0.rawValue < $1.rawValue }
            }
        } catch {
            errorMessage = error.localizedDescription
            snapshot = GraphSnapshot()
            layout = GraphLayoutResult(
                width: Double(canvasSize.width),
                height: Double(canvasSize.height)
            )
        }
    }
}
