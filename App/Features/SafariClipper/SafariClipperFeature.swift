import SwiftUI
import LociCore

/// Public entry for Safari web clipper (PR32).
///
/// Extension enqueues `.loci/inbox/*.json`; main app drains into today’s daily or
/// a Weblink object via `SafariClipServing` + `CaptureServing` + `ObjectServing`.
enum SafariClipperFeature {
    @MainActor
    static func destination(services: AppServices) -> some View {
        SafariClipperPanelView(services: services)
    }

    @MainActor
    static func inspector(services: AppServices) -> some View {
        SafariClipperInspectorView(services: services)
    }

    @MainActor
    static func settingsNote(services: AppServices) -> some View {
        SafariClipperSettingsNote(services: services)
    }
}
