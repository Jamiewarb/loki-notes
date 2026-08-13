import SwiftUI
import LociCore
import LociDesignSystem

/// First-run / vault-open helper (PR08/PR10). Ensures skeleton, Page+Daily schema, and local index.
enum OnboardingFeature {
    /// Run after choosing a vault root (Settings Create vault, or future picker).
    static func completeVaultOpen(services: AppServices) async throws {
        try await services.openVaultPipeline(rebuildIfNeeded: true)
        // Prefer Daily inbox after vault open (esp. iOS).
        _ = try? await services.ensureTodayDailyNote()
        await services.open(route: .daily)
    }

    @MainActor
    static func settingsHint() -> some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.xs)) {
            Text("Create vault writes .loci/ + Page/Daily types, then opens today’s note (local index in Application Support).")
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.inkSoft)
            Text("Optional: Apply PARA pack for Project/Area types, #resource / #archive guidance, and hide-archived filters.")
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.inkSoft)
        }
    }
}
