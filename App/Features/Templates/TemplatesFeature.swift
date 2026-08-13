import SwiftUI
import LociCore

/// Public entry for Templates feature (PR14).
enum TemplatesFeature {
    /// Type schema: list / create / star / edit templates.
    @MainActor
    static func editor(services: AppServices, typeID: ObjectTypeID) -> some View {
        TemplateEditorView(services: services, typeID: typeID)
    }

    /// Compact picker for starring / choosing a template (type dashboard).
    @MainActor
    static func picker(services: AppServices, typeID: ObjectTypeID) -> some View {
        TemplatePickerView(services: services, typeID: typeID)
    }
}
