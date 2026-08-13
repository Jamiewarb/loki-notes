import SwiftUI
import LociCore
import LociDesignSystem

/// Settings panel: sync chip detail, rebuild index, reveal vault path, conflicts (PR21).
struct SyncSettingsSection: View {
    @Bindable var services: AppServices
    @State private var status: SyncStatus = .localOnly
    @State private var vaultPath: String = "…"
    @State private var isBusy = false
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.md)) {
            Text("Sync & resilience")
                .font(LociTypography.font(.headline))
                .foregroundStyle(LociColors.ink)

            SyncChip(services: services)

            Text(status.displayLabel)
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.inkSoft)

            Text(vaultPath)
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.ink)
                .textSelection(.enabled)
                .accessibilityIdentifier("vault-path-display")

            HStack(spacing: LociSpacing.stack(.sm)) {
                LociButton("Reveal vault path", style: .secondary) {
                    Task { await reveal() }
                }
                .accessibilityIdentifier("reveal-vault-path")

                LociButton("Rebuild index", style: .secondary) {
                    Task { await rebuild() }
                }
                .disabled(isBusy)
                .accessibilityIdentifier("rebuild-index")
            }

            if let message {
                Text(message)
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.inkSoft)
            }

            ConflictListView(services: services)
                .padding(.top, LociSpacing.stack(.sm))
        }
        .task { await refresh() }
        .onChange(of: services.syncRefreshNonce) { _, _ in
            Task { await refresh() }
        }
    }

    private func refresh() async {
        status = await services.status
        do {
            vaultPath = try await services.vaultPathDisplay
        } catch {
            vaultPath = "unavailable"
        }
    }

    private func reveal() async {
        do {
            let path = try await services.revealVaultPath()
            message = "Vault path: \(path)"
            await refresh()
        } catch {
            message = "Reveal failed: \(error.localizedDescription)"
        }
    }

    private func rebuild() async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await services.rebuildIndex()
            message = "Index rebuilt from vault files (Application Support)."
            services.bumpSyncRefresh()
        } catch {
            message = "Rebuild failed: \(error.localizedDescription)"
        }
    }
}
