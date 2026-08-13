import SwiftUI
import LociCore
import LociDesignSystem

/// Composition root for the multiplatform Loci app.
/// Wires concrete services into the environment (PR04+). Features must not import each other.
///
/// **Launch preference (PR10):** `AppServices` defaults `selectedRoute` to `.daily`.
/// On iOS the Daily tab is first; opening Daily auto-creates `daily/YYYY-MM-DD.md` if missing.
@main
struct LociApp: App {
    @State private var services = AppServices()

    var body: some Scene {
        WindowGroup {
            AppShellView(services: services)
                .environment(services)
                .task {
                    // Prefer Daily inbox: bootstrap vault/index so ensure-today can run on first paint.
                    // Local Documents fallback works without iCloud (CI / simulator).
                    try? await services.openVaultPipeline(rebuildIfNeeded: true)
                    if services.selectedRoute == .daily {
                        _ = try? await services.ensureTodayDailyNote()
                    }
                }
        }
        #if os(macOS)
        .defaultSize(width: 1100, height: 720)
        #endif
    }
}
