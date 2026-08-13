import SwiftUI
import LociCore

/// Public entry for Graph feature (PR24 / PR45 polish).
///
/// Topology comes from `IndexQuerying.graph` (links table) — never scraped from
/// markdown in this feature. Hide hubs / focus neighbors are session-only.
/// Node selection navigates via `Navigating.open`.
enum GraphFeature {
    @MainActor
    static func destination(services: AppServices) -> some View {
        GraphView(services: services)
    }

    @MainActor
    static func inspector(services: AppServices) -> some View {
        GraphInspectorView(services: services)
    }
}
