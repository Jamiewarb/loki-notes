import SwiftUI
import LociCore
import LociDesignSystem
import LociVault

/// Read-only object-type list (PR05). Full type dashboards arrive in PR12.
struct TypeListView: View {
    var services: AppServices
    @State private var types: [ObjectType] = []
    @State private var spaceName: String = "…"
    @State private var errorMessage: String?
    @State private var isBusy = false

    var body: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.lg)) {
            HStack(spacing: LociSpacing.stack(.md)) {
                LociIcon(Route.types.systemImage, size: 22)
                    .foregroundStyle(LociColors.accent)
                Text(Route.types.title)
                    .font(LociTypography.font(.display))
                    .foregroundStyle(LociColors.ink)
            }
            .lociAppear(.soft)

            Text("Schema lives under .loci/types/ — one file per type (merge-friendly). Built-in Page is seeded on vault create.")
                .font(LociTypography.font(.body))
                .foregroundStyle(LociColors.inkSoft)
                .frame(maxWidth: 520, alignment: .leading)

            Text("Space: \(spaceName)")
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.inkSoft)

            if types.isEmpty {
                LociEmptyState(
                    title: "No types yet",
                    message: "Create a vault in Settings to bootstrap the built-in Page type.",
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
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, LociSpacing.stack(.sm))
        .accessibilityIdentifier("type-row-\(type.id.rawValue)")
    }

    private func reload() async {
        isBusy = true
        defer { isBusy = false }
        do {
            // Ensure Page exists when vault already has skeleton.
            if try await services.vault.fileExists(atRelativePath: VaultLayout.spaceJSON) {
                try await services.schema.seedBuiltInPageIfNeeded()
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
