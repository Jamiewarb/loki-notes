import Foundation
import LociCore

/// Concrete `MediaServing` — copies image/file bytes into vault `media/` via coordinated writes.
/// Never stores blobs in the SQLite index.
public final class MediaService: MediaServing, @unchecked Sendable {
    private let vault: any VaultServing

    public init(vault: any VaultServing) {
        self.vault = vault
    }

    public func attach(
        data: Data,
        kind: MediaKind,
        preferredFileName: String
    ) async throws -> MediaAttachment {
        try await vault.putMedia(data, kind: kind, preferredFileName: preferredFileName)
    }

    public func attach(
        fileURL: URL,
        kind: MediaKind?,
        preferredFileName: String?
    ) async throws -> MediaAttachment {
        let data = try Data(contentsOf: fileURL)
        let name = preferredFileName
            ?? fileURL.lastPathComponent
        let resolvedKind = kind ?? MediaPath.kind(forFileName: name)
        return try await attach(data: data, kind: resolvedKind, preferredFileName: name)
    }

    public func trashMedia(atRelativePath path: String) async throws {
        let normalized = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard normalized.hasPrefix("media/") else {
            throw LociError.invalidRelativePath(path)
        }
        _ = try await vault.trashFile(atRelativePath: normalized, objectID: nil)
    }
}
