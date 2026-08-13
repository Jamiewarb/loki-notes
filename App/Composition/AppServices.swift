import Foundation
import Observation
import LociCore
import LociVault
import LociIndex

/// Composition root for service wiring.
/// Conforms to `Navigating` + `SyncStatusProviding`; features depend on protocols only.
@Observable
public final class AppServices: Navigating, SyncStatusProviding, @unchecked Sendable {
    public var spaceName: String
    /// Currently presented shell destination.
    public var selectedRoute: Route
    /// Concrete vault I/O (local Documents fallback always available).
    public let vault: VaultService
    /// Per-type schema + space.json (merge-friendly `.loci/types/*.json`).
    public let schema: SchemaStore
    /// Local SQLite projection (Application Support) — wired for PR08 Object CRUD.
    /// Created lazily after vault root is known; nil until `ensureIndex()` succeeds.
    public private(set) var index: IndexService?

    public init(
        spaceName: String = "Loci",
        selectedRoute: Route = .daily,
        vault: VaultService? = nil,
        schema: SchemaStore? = nil,
        index: IndexService? = nil
    ) {
        self.spaceName = spaceName
        self.selectedRoute = selectedRoute
        let resolvedVault =
            vault
            ?? (try? VaultService(forceLocal: false))
            ?? (try! VaultService(forceLocal: true))
        self.vault = resolvedVault
        self.schema = schema ?? SchemaStore(vault: resolvedVault)
        self.index = index
    }

    /// Open or create the Application Support index for the active vault (never inside vault).
    public func ensureIndex() async throws -> IndexService {
        if let index { return index }
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        let directory = try IndexDatabase.defaultApplicationSupportDirectory()
        #else
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Loci", isDirectory: true)
        #endif
        let service = try await IndexService(vault: vault, indexDirectory: directory)
        self.index = service
        return service
    }

    public func open(route: Route) async {
        selectedRoute = route
    }

    public func open(objectID: ObjectID) async {
        selectedRoute = .object(objectID)
    }

    public var status: SyncStatus {
        get async {
            switch await vault.rootKind {
            case .localDocuments:
                return .localOnly
            case .iCloudUbiquity:
                return .iCloudAvailable
            }
        }
    }

    /// Settings “Create vault” — skeleton + bootstrap built-in Page type.
    public func createVaultIfNeeded() async throws {
        try await schema.bootstrapSchema(spaceName: spaceName)
    }
}
