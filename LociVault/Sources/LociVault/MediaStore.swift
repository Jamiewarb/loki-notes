import Foundation
import LociCore

/// Shared media-path allocation + coordinated write used by `VaultService.putMedia` and `MediaService`.
enum MediaStore {
    static func put(
        data: Data,
        kind: MediaKind,
        preferredFileName: String,
        vault: any VaultServing
    ) async throws -> MediaAttachment {
        let sanitized = MediaPath.sanitizeFileName(preferredFileName)
        let relativePath = try await uniqueRelativePath(
            directory: kind.directory,
            fileName: sanitized,
            vault: vault
        )
        try await vault.writeFile(data, atRelativePath: relativePath)
        return MediaAttachment(
            relativePath: relativePath,
            kind: kind,
            fileName: (relativePath as NSString).lastPathComponent,
            byteCount: data.count
        )
    }

    /// `media/<kind>/<stem>.ext` — on collision appends a short UUID fragment before the extension.
    static func uniqueRelativePath(
        directory: String,
        fileName: String,
        vault: any VaultServing
    ) async throws -> String {
        let candidate = "\(directory)/\(fileName)"
        if try await !vault.fileExists(atRelativePath: candidate) {
            return candidate
        }
        let ns = fileName as NSString
        let ext = ns.pathExtension
        let stem = ns.deletingPathExtension
        let suffix = String(UUID().uuidString.lowercased().prefix(8))
        let renamed: String
        if ext.isEmpty {
            renamed = "\(stem)-\(suffix)"
        } else {
            renamed = "\(stem)-\(suffix).\(ext)"
        }
        return "\(directory)/\(renamed)"
    }
}
