import Foundation
import Observation
import LociCore
import LociVault

/// Composition root for service wiring.
/// Conforms to `Navigating` + `SyncStatusProviding`; features depend on protocols only.
@Observable
public final class AppServices: Navigating, SyncStatusProviding, @unchecked Sendable {
    public var spaceName: String
    /// Currently presented shell destination.
    public var selectedRoute: Route
    /// Concrete vault I/O (local Documents fallback always available).
    public let vault: VaultService

    public init(
        spaceName: String = "Loci",
        selectedRoute: Route = .daily,
        vault: VaultService? = nil
    ) {
        self.spaceName = spaceName
        self.selectedRoute = selectedRoute
        if let vault {
            self.vault = vault
        } else {
            self.vault =
                (try? VaultService(forceLocal: false))
                ?? (try! VaultService(forceLocal: true))
        }
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

    /// Settings “Create vault” — ensures skeleton + bootstrap `space.json`.
    public func createVaultIfNeeded() async throws {
        try await vault.ensureSkeleton(spaceName: spaceName)
    }
}
