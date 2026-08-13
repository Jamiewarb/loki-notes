import SwiftUI
import LociCore

/// Public entry for Tags feature (PR17) — browse, completer, object-level tags.
/// No cross-feature imports; composition injects `AppServices`.
enum TagsFeature {
    /// Cross-type tag browse (all tags or a focused tag page).
    @MainActor
    static func browse(services: AppServices) -> some View {
        TagBrowseView(services: services)
    }

    /// `#` completer overlay for the block editor.
    @MainActor
    static func completer(
        services: AppServices,
        query: String,
        onSelect: @escaping (TagSummary) -> Void
    ) -> some View {
        TagCompleterView(services: services, query: query, onSelect: onSelect)
    }

    /// Inspector: edit object-level frontmatter tags.
    @MainActor
    static func objectTags(services: AppServices, objectID: ObjectID) -> some View {
        ObjectTagsEditorView(services: services, objectID: objectID)
    }
}
