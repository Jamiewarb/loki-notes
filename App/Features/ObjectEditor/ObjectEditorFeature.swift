import SwiftUI
import LociCore

/// Public entry for ObjectEditor feature (PR08). Composition wires services.
enum ObjectEditorFeature {
    @MainActor
    static func editor(services: AppServices, objectID: ObjectID) -> some View {
        ObjectEditorView(services: services, objectID: objectID)
    }

    @MainActor
    static func pageList(services: AppServices) -> some View {
        PageListView(services: services)
    }
}
