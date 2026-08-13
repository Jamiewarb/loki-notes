import SwiftUI
import LociCore
import LociDesignSystem

/// Force-directed link graph from the local index (PR24).
struct GraphView: View {
    var services: AppServices

    @State private var snapshot = GraphSnapshot()
    @State private var layout = GraphLayoutResult()
    @State private var typeFilter: ObjectTypeID?
    @State private var selectedID: ObjectID?
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
            }
            .lociAppear(.soft)

            Text(
                "Wiki-link network from the local links index. Tap a node to open the object."
            )
            .font(LociTypography.font(.body))
            .foregroundStyle(LociColors.inkSoft)
            .frame(maxWidth: 520, alignment: .leading)

            typeFilterChips

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
        "\(typeFilter?.rawValue ?? "all")|\(services.index == nil ? "0" : "1")"
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
                context.stroke(
                    path,
                    with: .color(LociColors.inkSoft.opacity(0.45)),
                    lineWidth: 1.2
                )
            }

            for node in snapshot.nodes {
                guard let p = layout.point(for: node.id) else { continue }
                let center = CGPoint(x: p.x * scaleX, y: p.y * scaleY)
                let selected = selectedID == node.id
                let radius: CGFloat = selected ? 14 : 11
                let rect = CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(selected ? LociColors.accent : LociColors.ink)
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
                        selectedID = hit
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

    private func reload() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            _ = try await services.ensureIndex()
            let store = GraphStore(index: services.index)
            let options = GraphBuildOptions(typeFilter: typeFilter)
            let next = try await store.load(options: options)
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
            // Also surface types from schema so empty filter chips still work.
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
