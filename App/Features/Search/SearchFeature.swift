import SwiftUI
import LociCore

/// Public entry for Search feature (PR18) — global FTS via `IndexQuerying.search`.
/// Writes vault? **no**. Reads index only; never blocks typing on keystroke path beyond async query.
enum SearchFeature {
    @MainActor
    static func destination(services: AppServices) -> some View {
        SearchView(services: services)
    }
}
