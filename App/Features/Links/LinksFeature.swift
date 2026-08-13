import SwiftUI
import LociCore

/// Public entry for Links feature (PR16 / PR44) — picker + backlinks + unlinked mentions.
/// No cross-feature imports.
enum LinksFeature {
    /// Inspector backlinks panel for an open object.
    @MainActor
    static func backlinks(services: AppServices, objectID: ObjectID) -> some View {
        BacklinksPanel(services: services, objectID: objectID)
    }

    /// Inspector unlinked-mentions panel (title scan). Derived UI only.
    @MainActor
    static func unlinkedMentions(services: AppServices, objectID: ObjectID) -> some View {
        UnlinkedMentionsPanel(services: services, objectID: objectID)
    }

    /// `@` / `[[` link picker overlay.
    @MainActor
    static func picker(
        services: AppServices,
        query: String,
        excluding excludeID: ObjectID?,
        onSelect: @escaping (LociObjectMeta) -> Void
    ) -> some View {
        LinkPickerView(
            services: services,
            query: query,
            excluding: excludeID,
            onSelect: onSelect
        )
    }
}
