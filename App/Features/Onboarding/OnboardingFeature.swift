import SwiftUI
import LociCore
import LociDesignSystem

/// First-run / vault-open helper (PR08). Ensures skeleton, Page schema, and local index.
enum OnboardingFeature {
    /// Run after choosing a vault root (Settings Create vault, or future picker).
    static func completeVaultOpen(services: AppServices) async throws {
        try await services.openVaultPipeline(rebuildIfNeeded: true)
    }

    @MainActor
    static func settingsHint() -> some View {
        Text("Create vault writes .loci/ + Page type, then opens the Application Support index.")
            .font(LociTypography.font(.caption))
            .foregroundStyle(LociColors.inkSoft)
    }
}
