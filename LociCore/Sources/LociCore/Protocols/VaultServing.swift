import Foundation

/// Coordinated vault file I/O. Implementations live in LociVault (PR04).
/// Always support a local Documents fallback — never require iCloud for features/tests.
public protocol VaultServing: Sendable {
    /// Root URL of the active vault (iCloud ubiquity or local fallback).
    var vaultRootURL: URL { get async throws }

    /// Whether the active root is local sandbox or iCloud ubiquity.
    var rootKind: VaultRootKind { get async }

    /// Create `.loci/`, `daily/`, `objects/`, `media/…` and write a bootstrap `space.json` if missing.
    func ensureSkeleton(spaceName: String) async throws

    func readFile(atRelativePath path: String) async throws -> Data
    func writeFile(_ data: Data, atRelativePath path: String) async throws
    func deleteFile(atRelativePath path: String) async throws
    func fileExists(atRelativePath path: String) async throws -> Bool

    /// Coordinated media put into `media/images` or `media/files` (unique name). Prefer `MediaServing`.
    func putMedia(
        _ data: Data,
        kind: MediaKind,
        preferredFileName: String
    ) async throws -> MediaAttachment

    /// Soft-delete: move into `.loci/trash/` and write a tombstone manifest.
    /// Pass `objectID` when known so the tombstone can be matched after delete.
    @discardableResult
    func trashFile(atRelativePath path: String, objectID: ObjectID?) async throws -> TombstoneRecord

    /// Absolute URL for a vault-relative path (locator only — do not persist as sole identity).
    func absoluteURL(forRelativePath path: String) async throws -> URL
}

/// Where the vault root was resolved from.
public enum VaultRootKind: String, Sendable, Codable, Equatable {
    case localDocuments
    case iCloudUbiquity
}

/// Soft-delete tombstone written beside trashed bytes under `.loci/trash/`.
public struct TombstoneRecord: Hashable, Sendable, Codable, Equatable {
    public var originalRelativePath: String
    public var trashedRelativePath: String
    public var trashedAt: Date
    public var objectID: String?

    public init(
        originalRelativePath: String,
        trashedRelativePath: String,
        trashedAt: Date = Date(),
        objectID: String? = nil
    ) {
        self.originalRelativePath = originalRelativePath
        self.trashedRelativePath = trashedRelativePath
        self.trashedAt = trashedAt
        self.objectID = objectID
    }
}

/// File-change event emitted by vault monitors (indexer consumes these in PR07).
public struct VaultFileEvent: Hashable, Sendable, Equatable {
    public var relativePath: String
    public var kind: VaultEventKind
    public var isConflictedCopy: Bool

    public init(relativePath: String, kind: VaultEventKind, isConflictedCopy: Bool = false) {
        self.relativePath = relativePath
        self.kind = kind
        self.isConflictedCopy = isConflictedCopy
    }
}
