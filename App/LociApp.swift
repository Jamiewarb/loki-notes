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
            DesignGalleryView()
                .environment(services)
        }
    }
}
