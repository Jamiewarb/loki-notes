import SwiftUI
import LociCore

/// Public entry for Import / Export feature (PR27).
///
/// Dry-run summary → apply writes real vault files (`objects/`, `daily/`, `media/`)
/// then indexes via ObjectServing / IndexUpdating — never a parallel store.
enum ImportExportFeature {
    @MainActor
    static func destination(services: AppServices) -> some View {
        ImportPanelView(services: services)
    }

    @MainActor
    static func inspector(services: AppServices) -> some View {
        ImportInspectorView(services: services)
    }
}
