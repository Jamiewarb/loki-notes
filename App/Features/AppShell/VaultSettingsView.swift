import SwiftUI
import LociCore
import LociDesignSystem
import LociVault

/// Settings destination — vault path status + Create vault (PR04).
struct VaultSettingsView: View {
    @Bindable var services: AppServices
    @State private var rootPath: String = "…"
    @State private var rootKindLabel: String = "…"
    @State private var spaceExists = false
    @State private var statusMessage: String?
    @State private var isBusy = false

    var body: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.lg)) {
            HStack(spacing: LociSpacing.stack(.md)) {
                LociIcon(Route.settings.systemImage, size: 22)
                    .foregroundStyle(LociColors.accent)
                Text(Route.settings.title)
                    .font(LociTypography.font(.display))
                    .foregroundStyle(LociColors.ink)
            }
            .lociAppear(.soft)

            Text("Vault is the source of truth. The SQLite index stays in Application Support — never inside the vault.")
                .font(LociTypography.font(.body))
                .foregroundStyle(LociColors.inkSoft)
                .frame(maxWidth: 520, alignment: .leading)

            VStack(alignment: .leading, spacing: LociSpacing.stack(.sm)) {
                Text("Root kind")
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.inkSoft)
                Text(rootKindLabel)
                    .font(LociTypography.font(.headline))
                    .foregroundStyle(LociColors.ink)

                Text("Vault path")
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.inkSoft)
                    .padding(.top, LociSpacing.stack(.sm))
                Text(rootPath)
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.ink)
                    .textSelection(.enabled)

                Text(spaceExists ? ".loci/space.json present" : ".loci/space.json not created yet")
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(spaceExists ? LociColors.accent : LociColors.inkSoft)
                    .padding(.top, LociSpacing.stack(.sm))
            }
            .lociAppear(.soft)

            LociButton(spaceExists ? "Refresh vault status" : "Create vault", style: .primary) {
                Task { await createOrRefresh() }
            }
            .disabled(isBusy)

            OnboardingFeature.settingsHint()

            PARAFeature.settingsSection(services: services)
                .padding(.top, LociSpacing.stack(.md))

            SyncStatusFeature.settingsSection(services: services)
                .padding(.top, LociSpacing.stack(.md))

            AIFeature.settingsSection(services: services)
                .padding(.top, LociSpacing.stack(.md))

            AppleIntegrationsFeature.settingsSection(services: services)
                .padding(.top, LociSpacing.stack(.md))

            if let statusMessage {
                Text(statusMessage)
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.inkSoft)
            }

            Text("Linux CI uses local Documents only. On Apple, ubiquity is preferred when signed in; otherwise local fallback.")
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.inkSoft)
                .frame(maxWidth: 520, alignment: .leading)
                .padding(.top, LociSpacing.stack(.md))
        }
        .padding(LociSpacing.stack(.xl))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task { await refreshStatus() }
    }

    private func refreshStatus() async {
        do {
            let url = try await services.vault.vaultRootURL
            let kind = await services.vault.rootKind
            rootPath = url.path
            rootKindLabel = kind == .iCloudUbiquity ? "iCloud Documents" : "Local Documents (fallback)"
            spaceExists = try await services.vault.fileExists(atRelativePath: VaultLayout.spaceJSON)
        } catch {
            statusMessage = "Could not resolve vault: \(error.localizedDescription)"
        }
    }

    private func createOrRefresh() async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await OnboardingFeature.completeVaultOpen(services: services)
            let typeCount = try await services.schema.knownTypeIDs().count
            let pageCount = try await services.index?.objects(typeID: .page).count ?? 0
            statusMessage =
                "Vault ready (.loci/space.json + types/ + index). \(typeCount) type(s), \(pageCount) page(s)."
            await refreshStatus()
        } catch {
            statusMessage = "Create failed: \(error.localizedDescription)"
        }
    }
}
