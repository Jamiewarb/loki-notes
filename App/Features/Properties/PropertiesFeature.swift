import SwiftUI
import LociCore

/// Public entry for Properties feature (PR13 / PR40 object-select picker).
enum PropertiesFeature {
    /// Object inspector: edit property values for an open object.
    @MainActor
    static func editor(services: AppServices, objectID: ObjectID) -> some View {
        PropertyEditorView(services: services, objectID: objectID)
    }

    /// Type schema: add/edit property definitions.
    @MainActor
    static func defsEditor(services: AppServices, typeID: ObjectTypeID) -> some View {
        PropertyDefsEditorView(services: services, typeID: typeID)
    }
}
