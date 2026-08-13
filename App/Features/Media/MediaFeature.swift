import SwiftUI
import LociCore
import LociVault

/// Public entry for Media feature (PR20) — attach into `media/`, markdown images, Image type.
///
/// Writes vault? **yes** (`media/images|files` + optional `objects/image/`). Never SQLite blobs.
/// Photos picker / drag-drop are Apple stubs; Linux tests use `MediaServing.attach(fileURL:)`.
enum MediaFeature {
    /// Factory for Image objects wired from composition.
    @MainActor
    static func imageFactory(services: AppServices) -> LociVault.ImageObjectFactory? {
        guard let objects = services.objects else { return nil }
        return LociVault.ImageObjectFactory(media: services.media, objects: objects)
    }

    @MainActor
    static func attachControls(
        services: AppServices,
        objectRelativePath: String,
        onInserted: @escaping (String) -> Void
    ) -> some View {
        MediaAttachControls(
            services: services,
            objectRelativePath: objectRelativePath,
            onInsertedMarkdown: onInserted
        )
    }
}
