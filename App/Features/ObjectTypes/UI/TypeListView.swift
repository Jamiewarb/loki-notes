import SwiftUI
import LociCore
import LociDesignSystem
import LociVault

/// Object-type list + navigation into type dashboards / create editor (PR12).
struct TypeListView: View {
    @Bindable var services: AppServices
    @State private var types: [ObjectType] = []
    @State private var spaceName: String = "…"
    @State private var errorMessage: String?
    @State private var isBusy = false
    @State private var showEditor = false

    var body: some View {
        Group {
            if let focused = services.focusedTypeID {
                TypeDashboardView(services: services, typeID: focused) {
                    services.focusedTypeID = nil
                }
            } else if showEditor {
                TypeEditorView(services: services) {
                    showEditor = false
                    Task { await reload() }
                } onCancel: {
                    showEditor = false
                }
            } else {
                typesBody
            }
        }
    }

    private var typesBody: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.lg)) {
            HStack(spacing: LociSpacing.stack(.md)) {
                LociIcon(Route.types.systemImage, size: 22)
                    .foregroundStyle(LociColors.accent)
                Text(Route.types.title)
                    .font(LociTypography.font(.display))
                    .foregroundStyle(LociColors.ink)
                Spacer(minLength: 0)
                LociButton("New Type", style: .primary) {
                    showEditor = true
                }
                .disabled(isBusy)
            }
            .lociAppear(.soft)

            Text("Create custom types anytime. Schema is merge-friendly — one `.loci/types/<slug>.json` plus `objects/<slug>/`.")
                .font(LociTypography.font(.body))
                .foregroundStyle(LociColors.inkSoft)
                .frame(maxWidth: 520, alignment: .leading)

            Text("Space: \(spaceName)")
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.inkSoft)

            if types.isEmpty {
                LociEmptyState(
                    title: "No types yet",
                    message: "Create a vault in Settings to bootstrap Page + Daily, then add custom types.",
                    systemImage: Route.types.systemImage
                )
            } else {
                VStack(alignment: .leading, spacing: LociSpacing.stack(.sm)) {
                    ForEach(types, id: \.id.rawValue) { type in
                        typeRow(type)
                    }
                }
                .lociAppear(.soft)
            }

            LociButton("Refresh types", style: .secondary) {
                Task { await reload() }
            }
            .disabled(isBusy)

            if let errorMessage {
                Text(errorMessage)
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.danger)
            }
        }
        .padding(LociSpacing.stack(.xl))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task { await reload() }
    }

    @ViewBuilder
    private func typeRow(_ type: ObjectType) -> some View {
        Button {
            services.focusedTypeID = type.id
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: LociSpacing.stack(.md)) {
                LociIcon(type.icon, size: 18)
                    .foregroundStyle(LociColors.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(type.name)
                        .font(LociTypography.font(.headline))
                        .foregroundStyle(LociColors.ink)
                    Text(".\(type.id.rawValue) · \(type.properties.count) properties\(type.isBuiltIn ? " · built-in" : "")")
                        .font(LociTypography.font(.caption))
                        .foregroundStyle(LociColors.inkSoft)
                    Text("Open dashboard")
                        .font(LociTypography.font(.caption))
                        .foregroundStyle(LociColors.accent)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, LociSpacing.stack(.sm))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("type-row-\(type.id.rawValue)")
    }

    private func reload() async {
        isBusy = true
        defer { isBusy = false }
        do {
            if try await services.vault.fileExists(atRelativePath: VaultLayout.spaceJSON) {
                try await services.schema.seedBuiltInPageIfNeeded()
                try? await services.openVaultPipeline(rebuildIfNeeded: true)
            }
            types = try await services.schema.allTypes()
            if let settings = try? await services.schema.loadSpaceSettings() {
                spaceName = settings.name
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
