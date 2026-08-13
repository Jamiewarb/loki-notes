import SwiftUI
import LociCore

/// Public entry for Object Types feature (PR12).
enum ObjectTypesFeature {
    @MainActor
    static func root(services: AppServices) -> some View {
        TypeListView(services: services)
    }
}
