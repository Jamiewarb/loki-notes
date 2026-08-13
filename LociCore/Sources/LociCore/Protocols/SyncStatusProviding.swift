import Foundation

/// iCloud / local / offline / conflict chrome (PR21). Features read status; Vault owns ubiquity.
public protocol SyncStatusProviding: Sendable {
    /// Current sync / vault-availability chip state.
    var status: SyncStatus { get async }

    /// Absolute vault path for Settings display (all platforms).
    var vaultPathDisplay: String { get async throws }

    /// Conflicted-copy paths under the vault (markdown + media).
    func listConflictedCopies() async throws -> [SyncConflictItem]

    /// Ensure a vault-relative file is present locally (download-on-demand).
    /// Linux / local roots: no-op success.
    func ensureDownloaded(atRelativePath path: String) async throws

    /// Rebuild the disposable SQLite index from vault files (Application Support).
    func rebuildIndex() async throws

    /// Reveal vault root in Finder (macOS) / Files (iOS). Returns the path string on all platforms.
    @discardableResult
    func revealVaultPath() async throws -> String
}

/// Chip states for sync / vault availability.
public enum SyncStatus: String, Sendable, Codable, Equatable, CaseIterable {
    case localOnly
    case iCloudAvailable
    case syncing
    case offline
    case conflict
    case error

    public var displayLabel: String {
        switch self {
        case .localOnly: return "Local only"
        case .iCloudAvailable: return "iCloud available"
        case .syncing: return "Syncing"
        case .offline: return "Offline"
        case .conflict: return "Conflict"
        case .error: return "Error"
        }
    }

    public var systemImage: String {
        switch self {
        case .localOnly: return "internaldrive"
        case .iCloudAvailable: return "checkmark.icloud"
        case .syncing: return "arrow.triangle.2.circlepath.icloud"
        case .offline: return "icloud.slash"
        case .conflict: return "exclamationmark.triangle"
        case .error: return "xmark.icloud"
        }
    }
}

/// One conflicted-copy file surfaced in Sync UX (includes media under `media/`).
public struct SyncConflictItem: Hashable, Sendable, Codable, Equatable {
    public var relativePath: String
    public var kind: SyncConflictKind

    public init(relativePath: String, kind: SyncConflictKind) {
        self.relativePath = relativePath
        self.kind = kind
    }

    public var filename: String {
        (relativePath as NSString).lastPathComponent
    }
}

public enum SyncConflictKind: String, Sendable, Codable, Equatable {
    case markdown
    case media
    case other

    public static func infer(fromRelativePath path: String) -> SyncConflictKind {
        let lower = path.lowercased()
        if lower.hasPrefix("media/") {
            return .media
        }
        if lower.hasSuffix(".md") {
            return .markdown
        }
        return .other
    }
}

/// Pure status derivation — unit-tested; Vault/AppServices supply inputs.
public enum SyncStatusDerivation: Sendable {
    /// Priority: simulated override → error → conflict → syncing → offline → root kind.
    public static func derive(
        rootKind: VaultRootKind,
        isNetworkAvailable: Bool = true,
        isSyncing: Bool = false,
        hasConflicts: Bool = false,
        hasError: Bool = false,
        simulatedOverride: SyncStatus? = nil
    ) -> SyncStatus {
        if let simulatedOverride {
            return simulatedOverride
        }
        if hasError {
            return .error
        }
        if hasConflicts {
            return .conflict
        }
        switch rootKind {
        case .localDocuments:
            return .localOnly
        case .iCloudUbiquity:
            if isSyncing {
                return .syncing
            }
            if !isNetworkAvailable {
                return .offline
            }
            return .iCloudAvailable
        }
    }
}
