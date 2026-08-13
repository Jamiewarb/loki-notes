import SwiftUI
import LociCore

/// Public entry for Type conversion (PR28).
///
/// Change an object’s type with property mapping UI; move file under
/// `objects/<type>/`; ObjectID stays stable; index via ObjectServing.
enum TypeConversionFeature {
    @MainActor
    static func destination(services: AppServices) -> some View {
        TypeConversionPanelView(services: services)
    }

    @MainActor
    static func inspector(services: AppServices) -> some View {
        TypeConversionInspectorView(services: services)
    }

    /// Sheet / inspector entry for an open object.
    @MainActor
    static func sheet(services: AppServices, objectID: ObjectID) -> some View {
        TypeConversionSheetView(services: services, objectID: objectID)
    }
}
