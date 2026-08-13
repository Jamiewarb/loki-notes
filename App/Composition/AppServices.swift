import Foundation
import Observation
import LociCore

/// Composition root for service wiring. Concrete Vault/Index/Markdown arrive in later PRs.
@Observable
public final class AppServices: @unchecked Sendable {
    public var spaceName: String

    public init(spaceName: String = "Loci") {
        self.spaceName = spaceName
    }
}
