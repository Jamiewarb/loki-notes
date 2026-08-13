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
        Text("Create vault writes .loci/ + Page/Daily types, then opens today’s note (local index in Application Support).")
            .font(LociTypography.font(.caption))
            .foregroundStyle(LociColors.inkSoft)
    }
}
