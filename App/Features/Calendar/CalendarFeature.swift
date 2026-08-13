import SwiftUI
import LociCore

/// Public entry for Calendar feature (PR25).
///
/// Month/week grid anchored to `daily/YYYY-MM-DD.md`. Dots come from
/// `IndexQuerying.calendarMarkers` (never rewritten into daily markdown).
/// Day select → `DailyNoteServing.ensure` + `Navigating.open`.
enum CalendarFeature {
    @MainActor
    static func destination(services: AppServices) -> some View {
        CalendarView(services: services)
    }

    @MainActor
    static func inspector(services: AppServices) -> some View {
        CalendarInspectorView(services: services)
    }
}
