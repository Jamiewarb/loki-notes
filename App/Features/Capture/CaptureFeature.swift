import SwiftUI
import LociCore

/// Public entry for Capture feature (PR26).
///
/// Share / widget / menu bar enqueue `.loci/inbox/*.json`; main app drains into
/// today’s daily (`DailyNoteServing.ensureToday`) or typed objects (`ObjectServing.create`).
/// Extensions never touch the SQLite index.
enum CaptureFeature {
    @MainActor
    static func destination(services: AppServices) -> some View {
        CaptureQuickAddView(services: services)
    }

    @MainActor
    static func inspector(services: AppServices) -> some View {
        CaptureInspectorView(services: services)
    }
}
