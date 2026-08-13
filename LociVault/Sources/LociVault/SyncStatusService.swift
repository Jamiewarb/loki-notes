import Foundation
import LociCore

/// Derives sync chip state + conflict list for `SyncStatusProviding` (PR21).
///
/// Linux / CI: root is localDocuments → `.localOnly`. Tests may inject
/// `simulatedOverride` / flags to exercise syncing / offline / error chips.
public final class SyncStatusService: @unchecked Sendable {
    private let vault: VaultService
    private let lock = NSLock()
    private var _simulatedOverride: SyncStatus?
    private var _isNetworkAvailable = true
    private var _isSyncing = false
    private var _hasError = false

    public init(vault: VaultService) {
        self.vault = vault
    }

    /// DevHarness / tests: force a chip state without ubiquity.
    public var simulatedOverride: SyncStatus? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _simulatedOverride
        }
        set {
            lock.lock()
            _simulatedOverride = newValue
            lock.unlock()
        }
    }

    public var isNetworkAvailable: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _isNetworkAvailable
        }
        set {
            lock.lock()
            _isNetworkAvailable = newValue
            lock.unlock()
        }
    }

    public var isSyncing: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _isSyncing
        }
        set {
            lock.lock()
            _isSyncing = newValue
            lock.unlock()
        }
    }

    public var hasError: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _hasError
        }
        set {
            lock.lock()
            _hasError = newValue
            lock.unlock()
        }
    }

    public func currentStatus() async -> SyncStatus {
        let kind = await vault.rootKind
        let conflicts: [SyncConflictItem]
        do {
            conflicts = try await vault.listConflictedCopies()
        } catch {
            return SyncStatusDerivation.derive(
                rootKind: kind,
                isNetworkAvailable: isNetworkAvailable,
                isSyncing: isSyncing,
                hasConflicts: false,
                hasError: true,
                simulatedOverride: simulatedOverride
            )
        }
        return SyncStatusDerivation.derive(
            rootKind: kind,
            isNetworkAvailable: isNetworkAvailable,
            isSyncing: isSyncing,
            hasConflicts: !conflicts.isEmpty,
            hasError: hasError,
            simulatedOverride: simulatedOverride
        )
    }

    public func listConflictedCopies() async throws -> [SyncConflictItem] {
        try await vault.listConflictedCopies()
    }

    public func vaultPathDisplay() async throws -> String {
        try await vault.vaultRootURL.path
    }

    @discardableResult
    public func revealVaultPath() async throws -> String {
        let url = try await vault.vaultRootURL
        return VaultPathRevealer.reveal(url)
    }

    public func ensureDownloaded(atRelativePath path: String) async throws {
        try await vault.ensureDownloaded(atRelativePath: path)
    }
}
