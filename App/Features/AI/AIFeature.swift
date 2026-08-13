import SwiftUI
import LociCore

/// Public entry for AI assist feature (PR30).
///
/// Side-panel summarize / rewrite / translate / property autofill. Explicit actions only —
/// never on the typing path. Apply goes through ObjectServing / EditorSession.
enum AIFeature {
    @MainActor
    static func destination(services: AppServices) -> some View {
        AIAssistPanelView(services: services, objectID: nil)
    }

    @MainActor
    static func panel(services: AppServices, objectID: ObjectID?) -> some View {
        AIAssistPanelView(services: services, objectID: objectID)
    }

    @MainActor
    static func settingsSection(services: AppServices) -> some View {
        AISettingsView(services: services)
    }

    @MainActor
    static func inspector(services: AppServices) -> some View {
        AIAssistPanelView(services: services, objectID: nil)
    }
}
