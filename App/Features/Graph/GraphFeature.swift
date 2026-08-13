import SwiftUI
import LociCore

/// Public entry for Graph feature (PR24).
///
/// Topology comes from `IndexQuerying.graph` (links table) — never scraped from
/// markdown in this feature. Node selection navigates via `Navigating.open`.
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
