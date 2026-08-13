import SwiftUI
import LociCore
import LociDesignSystem

/// Sidebar Pinned section rows resolved from space.json (PR34).
struct PinnedSidebarList: View {
    @Bindable var services: AppServices
    @State private var rows: [PinnedObjectRow] = []

    var body: some View {
        Group {
            if rows.isEmpty {
                Text("No pins yet")
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.inkSoft)
                    .padding(.vertical, LociSpacing.stack(.xs))
            } else {
                ForEach(rows) { row in
                    LociListRow(
                        title: row.title,
                        subtitle: row.subtitle,
                        systemImage: "pin",
                        isSelected: isSelected(row)
                    ) {
                        Task { await open(row) }
                    }
                    .opacity(row.isMissing ? 0.72 : 1)
                    .contextMenu {
                        Button("Unpin") {
                            Task { await unpin(row.id) }
                        }
                    }
                }
            }
        }
        .task { await reload() }
        .onChange(of: services.pinRefreshNonce) { _, _ in
            Task { await reload() }
        }
        .onChange(of: services.selectedRoute) { _, _ in
            Task { await reload() }
        }
    }

    private func isSelected(_ row: PinnedObjectRow) -> Bool {
        if case .object(let id) = services.selectedRoute {
            return id == row.id
        }
        return false
    }

    private func open(_ row: PinnedObjectRow) async {
        guard !row.isMissing else { return }
        await services.open(objectID: row.id)
    }

    private func unpin(_ id: ObjectID) async {
        do {
            _ = try await store().unpin(id)
            services.bumpPinRefresh()
            await reload()
        } catch {
            // Missing / I/O — list reload still safe.
            await reload()
        }
    }

    private func reload() async {
        do {
            rows = try await store().rows()
        } catch {
            rows = []
        }
    }

    private func store() -> PinStore {
        PinStore(pins: services.schema, index: services.index, objects: services.objects)
    }
}
