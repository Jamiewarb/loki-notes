import SwiftUI
import LociCore

/// Public entry for Tasks feature (PR19) — Today / Open aggregation via `IndexQuerying`.
///
/// Writes vault? **yes** on checkbox toggle (via `ObjectServing.save`). Reads index for lists.
/// Typing path unchanged — editor toggles still debounce through `EditorSessionBridge`.
enum TasksFeature {
    @MainActor
    static func destination(services: AppServices) -> some View {
        TasksView(services: services)
    }

    @MainActor
    static func openTasksPanel(services: AppServices, day: Date) -> some View {
        OpenTasksPanel(services: services, day: day)
    }
}
