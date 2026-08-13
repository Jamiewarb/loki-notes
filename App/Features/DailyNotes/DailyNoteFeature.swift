import SwiftUI
import LociCore

/// Public entry for DailyNotes feature (PR10/PR11). Composition wires services.
/// Created-today lives in `CreatedTodayPanel` (inspector) — never written into daily markdown.
enum DailyNoteFeature {
    @MainActor
    static func root(services: AppServices) -> some View {
        DailyNoteView(services: services)
    }
}
