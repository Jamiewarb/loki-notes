import SwiftUI
import LociCore
import LociDesignSystem

/// Compact sync / vault-availability chip for shell chrome (PR21).
struct SyncChip: View {
    @Bindable var services: AppServices
    @State private var status: SyncStatus = .localOnly

    var body: some View {
        HStack(spacing: LociSpacing.stack(.xs)) {
            Image(systemName: status.systemImage)
                .font(.system(size: 11, weight: .semibold))
            Text(status.displayLabel)
                .font(LociTypography.font(.caption))
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, LociSpacing.stack(.sm))
        .padding(.vertical, LociSpacing.stack(.xs))
        .background(LociColors.panel.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: LociRadius.sm, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Sync status \(status.displayLabel)")
        .accessibilityIdentifier("sync-chip")
        .task { await refresh() }
        .onChange(of: services.syncRefreshNonce) { _, _ in
            Task { await refresh() }
        }
    }

    private var foreground: Color {
        switch status {
        case .error, .conflict:
            return LociColors.danger
        case .syncing, .offline:
            return LociColors.inkSoft
        case .iCloudAvailable, .localOnly:
            return LociColors.accent
        }
    }

    private func refresh() async {
        status = await services.status
    }
}
