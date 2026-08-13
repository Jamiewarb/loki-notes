import SwiftUI
import LociCore

/// Public entry for Weblink Open Graph preview (PR43).
///
/// Inspector card when the open object is type weblink. Cache lives in Application
/// Support via `LinkPreviewServing`. Compose from AppShell / InspectorHostView —
/// ObjectEditor must not import this feature.
enum WeblinksFeature {
    @MainActor
    static func preview(services: AppServices, objectID: ObjectID) -> some View {
        WeblinkPreviewCard(services: services, objectID: objectID)
    }
}
