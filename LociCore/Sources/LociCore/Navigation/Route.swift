import Foundation

/// App-level navigation destinations. Expanded in PR03 AppShell.
public enum Route: Hashable, Sendable, Codable {
    case daily
    case search
    case types
    case settings
    case object(ObjectID)
}
