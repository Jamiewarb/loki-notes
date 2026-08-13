import SwiftUI
import LociCore

/// Public entry for Pins (PR34).
///
/// Vault truth is `.loci/space.json` `pins` (ObjectID strings). The index only
/// resolves title/type/path for display. Features talk `PinServing` +
/// `IndexQuerying` / `ObjectServing` / `Navigating`.
enum PinsFeature {
    /// Sidebar list of resolved pins. Tap opens via `Navigating.open(objectID:)`.
    @MainActor
    static func sidebarList(services: AppServices) -> some View {
        PinnedSidebarList(services: services)
    }

    /// Inspector: pin / unpin the open object.
    @MainActor
    static func toggle(services: AppServices, objectID: ObjectID) -> some View {
        PinToggleButton(services: services, objectID: objectID)
    }
}
