import Foundation
import LociCore
import LociVault

/// Feature-facing Image object factory (PR20).
/// Wraps `LociVault.ImageObjectFactory` — blobs in `media/`, metadata in `objects/image/`.
enum ImageObjectFactory {
    static func make(media: MediaServing, objects: ObjectServing) -> LociVault.ImageObjectFactory {
        LociVault.ImageObjectFactory(media: media, objects: objects)
    }

    static func create(
        services: AppServices,
        fileURL: URL,
        title: String? = nil
    ) async throws -> OpenedObject {
        let objects = try await services.ensureObjectService()
        let factory = LociVault.ImageObjectFactory(media: services.media, objects: objects)
        return try await factory.create(fileURL: fileURL, title: title)
    }
}
