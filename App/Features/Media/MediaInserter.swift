import Foundation
import LociCore

/// Feature-facing media markdown insertion (PR20).
/// Delegates to `LociCore.MediaInserter` so Linux package tests cover the same API.
enum MediaInserter {
    static func markdownLine(
        alt: String,
        attachment: MediaAttachment,
        fromObjectRelativePath objectPath: String
    ) -> String {
        LociCore.MediaInserter.markdownLine(
            alt: alt,
            attachment: attachment,
            fromObjectRelativePath: objectPath
        )
    }

    static func appendImage(
        to bodyMarkdown: String,
        alt: String,
        attachment: MediaAttachment,
        fromObjectRelativePath objectPath: String
    ) -> String {
        LociCore.MediaInserter.appendImage(
            to: bodyMarkdown,
            alt: alt,
            attachment: attachment,
            fromObjectRelativePath: objectPath
        )
    }

    /// Attach file bytes into the vault and return updated body markdown with an image embed.
    static func attachAndAppend(
        media: MediaServing,
        data: Data,
        preferredFileName: String,
        kind: MediaKind,
        bodyMarkdown: String,
        objectRelativePath: String,
        alt: String
    ) async throws -> (attachment: MediaAttachment, bodyMarkdown: String) {
        let attachment = try await media.attach(
            data: data,
            kind: kind,
            preferredFileName: preferredFileName
        )
        let body = appendImage(
            to: bodyMarkdown,
            alt: alt,
            attachment: attachment,
            fromObjectRelativePath: objectRelativePath
        )
        return (attachment, body)
    }
}
