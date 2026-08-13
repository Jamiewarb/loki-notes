import Foundation
import LociCore

/// Creates built-in **Image** objects: blob → `media/images`, metadata → `objects/image/*.md`.
/// Never stores binary payloads in SQLite — only vault-relative paths + markdown.
public struct ImageObjectFactory: Sendable {
    private let media: any MediaServing
    private let objects: any ObjectServing

    public init(media: any MediaServing, objects: any ObjectServing) {
        self.media = media
        self.objects = objects
    }

    /// Attach bytes, create an Image object, write markdown image body + `media-path` property.
    public func create(
        data: Data,
        preferredFileName: String,
        title: String? = nil,
        alt: String? = nil,
        mime: String? = nil
    ) async throws -> OpenedObject {
        let attachment = try await media.attach(
            data: data,
            kind: .image,
            preferredFileName: preferredFileName
        )
        return try await finalize(
            attachment: attachment,
            title: title ?? titleFromFileName(attachment.fileName),
            alt: alt,
            mime: mime
        )
    }

    /// Copy from a local file URL (temp pick / drop / Linux fixture) into the vault.
    public func create(
        fileURL: URL,
        title: String? = nil,
        alt: String? = nil,
        mime: String? = nil
    ) async throws -> OpenedObject {
        let attachment = try await media.attach(
            fileURL: fileURL,
            kind: .image,
            preferredFileName: nil
        )
        return try await finalize(
            attachment: attachment,
            title: title ?? titleFromFileName(attachment.fileName),
            alt: alt,
            mime: mime
        )
    }

    private func finalize(
        attachment: MediaAttachment,
        title: String,
        alt: String?,
        mime: String?
    ) async throws -> OpenedObject {
        var meta = try await objects.create(typeID: .image, title: title)
        let resolvedAlt = (alt?.isEmpty == false) ? alt! : title
        let body = MediaInserter.imageOnlyBody(
            alt: resolvedAlt,
            attachment: attachment,
            fromObjectRelativePath: meta.relativePath
        )
        meta.properties["media-path"] = .text(attachment.relativePath)
        if let mime, !mime.isEmpty {
            meta.properties["mime"] = .text(mime)
        }
        try await objects.save(meta: meta, bodyMarkdown: body)
        return try await objects.open(id: meta.id)
    }

    private func titleFromFileName(_ fileName: String) -> String {
        let stem = (fileName as NSString).deletingPathExtension
        let cleaned = stem.replacingOccurrences(of: "-", with: " ")
        return cleaned.isEmpty ? "Image" : cleaned
    }
}
