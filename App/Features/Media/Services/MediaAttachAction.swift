import Foundation
import LociCore

/// Shared attach → vault-relative markdown. Used by Photos, drop, and Linux demo buttons.
/// Never persists the source file URL — only `media/…` via `MediaServing`.
enum MediaAttachAction {
    static func attachData(
        media: MediaServing,
        data: Data,
        kind: MediaKind,
        preferredFileName: String,
        alt: String,
        objectRelativePath: String
    ) async throws -> (attachment: MediaAttachment, markdown: String) {
        let attachment = try await media.attach(
            data: data,
            kind: kind,
            preferredFileName: preferredFileName
        )
        let line = MediaInserter.markdownLine(
            alt: alt,
            attachment: attachment,
            fromObjectRelativePath: objectRelativePath
        )
        return (attachment, line)
    }

    /// Copy a local pick / drop file into the vault. Image kinds return markdown; files do not.
    static func attachFile(
        media: MediaServing,
        fileURL: URL,
        objectRelativePath: String
    ) async throws -> (attachment: MediaAttachment, markdown: String?) {
        let accessed = fileURL.startAccessingSecurityScopedResource()
        defer {
            if accessed { fileURL.stopAccessingSecurityScopedResource() }
        }
        let attachment = try await media.attach(
            fileURL: fileURL,
            kind: nil,
            preferredFileName: nil
        )
        guard attachment.kind == .image else {
            return (attachment, nil)
        }
        let alt = (attachment.fileName as NSString).deletingPathExtension
        let line = MediaInserter.markdownLine(
            alt: alt.isEmpty ? "image" : alt,
            attachment: attachment,
            fromObjectRelativePath: objectRelativePath
        )
        return (attachment, line)
    }
}
