import SwiftUI
import LociCore
import LociVault

/// Public entry for Media feature (PR20 / PR35) — attach into `media/`, markdown images, Image type.
///
/// Writes vault? **yes** (`media/images|files` + optional `objects/image/`). Never SQLite blobs.
/// iOS: `PhotosPicker` (`#if canImport(PhotosUI)`). macOS: `.onDrop`. Linux: demo bytes +
/// `MediaServing.attach(fileURL:)` — see `MediaPickerProof`.
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

    /// Drop target for the open editor (macOS). No-op modifier on other platforms.
    @MainActor
    static func dropAttachModifier(
        services: AppServices,
        objectRelativePath: String,
        onInserted: @escaping (String) -> Void
    ) -> MediaDropAttachModifier {
        MediaDropAttachModifier(
            services: services,
            objectRelativePath: objectRelativePath,
            onInsertedMarkdown: onInserted
        )
    }
}
