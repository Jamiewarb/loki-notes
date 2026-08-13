import SwiftUI
import LociCore

/// Public entry for DailyNotes feature (PR10). Composition wires services.
enum DailyNoteFeature {
    @MainActor
    static func root(services: AppServices) -> some View {
        DailyNoteView(services: services)
    }
}
