import SwiftUI
import LociCore
import LociDesignSystem

/// Public entry for PARA starter pack (PR15).
enum PARAFeature {
    @MainActor
    static func settingsSection(services: AppServices) -> some View {
        PARAPackSettingsView(services: services)
    }

    @MainActor
    static func explainerText() -> some View {
        Text(PARAPack.explainer)
            .font(LociTypography.font(.caption))
            .foregroundStyle(LociColors.inkSoft)
            .fixedSize(horizontal: false, vertical: true)
    }
}
