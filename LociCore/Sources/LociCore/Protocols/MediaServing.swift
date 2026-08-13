import Foundation

/// Copy media blobs into the vault `media/` tree via coordinated writes.
///
/// Features never write absolute paths or put binaries in SQLite — only vault-relative
/// paths and markdown references. Implementations live in LociVault (`MediaService`).
public protocol MediaServing: Sendable {
    /// Copy bytes into `media/images` or `media/files` (unique name on collision).
    func attach(
        data: Data,
        kind: MediaKind,
        preferredFileName: String
    ) async throws -> MediaAttachment

    /// Read a local file (e.g. temp pick / drop) and attach its bytes into the vault.
    func attach(
        fileURL: URL,
        kind: MediaKind?,
        preferredFileName: String?
    ) async throws -> MediaAttachment

    /// Soft-delete a media blob (move to `.loci/trash/`). Does not rewrite notes.
    func trashMedia(atRelativePath path: String) async throws
}
