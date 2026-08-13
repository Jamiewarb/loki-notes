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
    @Environment(\.scenePhase) private var scenePhase
    #if os(macOS)
    @State private var menuBar = MenuBarCaptureController()
    #endif

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
                    #if os(macOS)
                    menuBar.install(
                        capture: { services.capture },
                        vault: { services.vault },
                        onOpenToday: {
                            Task { await services.handleOpenURL(LociDeepLink.dailyTodayURL) }
                        }
                    )
                    #endif
                }
                .onOpenURL { url in
                    Task { await services.handleOpenURL(url) }
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    // Share / widget enqueue `.loci/inbox/`; drain on foreground (no index in extensions).
                    Task { _ = try? await services.drainCaptureInbox() }
                }
        }
        #if os(macOS)
        .defaultSize(width: 1100, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Page") {
                    Task { _ = try? await services.createPage() }
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            CommandGroup(after: .newItem) {
                Button("Quick Capture") {
                    Task { await services.open(route: .capture) }
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }
            CommandGroup(after: .sidebar) {
                Button("Search") {
                    Task { await services.openSearch() }
                }
                .keyboardShortcut("k", modifiers: .command)
                Button("Go to Today") {
                    Task { await services.handleOpenURL(LociDeepLink.dailyTodayURL) }
                }
                .keyboardShortcut("t", modifiers: .command)
            }
        }
        #endif
    }
}
