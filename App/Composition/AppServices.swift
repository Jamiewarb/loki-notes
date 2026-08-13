import Foundation
import Observation
import LociCore

/// Composition root for service wiring. Concrete Vault/Index/Markdown arrive in later PRs.
/// Conforms to `Navigating` so AppShell and future features share one route owner.
@Observable
public final class AppServices: Navigating, @unchecked Sendable {
    public var spaceName: String
    /// Currently presented shell destination.
    public var selectedRoute: Route

    public init(spaceName: String = "Loci", selectedRoute: Route = .daily) {
        self.spaceName = spaceName
        self.selectedRoute = selectedRoute
    }

    public func open(route: Route) async {
        selectedRoute = route
    }

    public func open(objectID: ObjectID) async {
        selectedRoute = .object(objectID)
    }
}
