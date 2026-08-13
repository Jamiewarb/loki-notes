import Foundation

/// Applies vault events to the local SQLite projection (PR07). Not for feature use directly.
public protocol IndexUpdating: Sendable {
    func rebuild() async throws
    func applyVaultEvent(relativePath: String, kind: VaultEventKind) async throws
}

public enum VaultEventKind: String, Sendable, Codable {
    case created
    case modified
    case deleted
    case renamed
}
