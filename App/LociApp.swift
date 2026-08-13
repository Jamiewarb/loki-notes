import SwiftUI
import LociCore
import LociDesignSystem

/// Composition root for the multiplatform Loci app.
/// Wires concrete services into the environment (PR04+). Features must not import each other.
@main
struct LociApp: App {
    @State private var services = AppServices()

    var body: some Scene {
        WindowGroup {
            AppShellView(services: services)
                .environment(services)
        }
        #if os(macOS)
        .defaultSize(width: 1100, height: 720)
        #endif
    }
}
