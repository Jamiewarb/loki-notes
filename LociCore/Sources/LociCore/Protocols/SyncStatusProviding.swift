import Foundation

/// iCloud / local / offline / conflict chrome (PR21). Features read status; Vault owns ubiquity.
public protocol SyncStatusProviding: Sendable {
    var status: SyncStatus { get async }
}

public enum SyncStatus: String, Sendable, Codable, Equatable {
    case localOnly
    case iCloudAvailable
    case syncing
    case offline
    case conflict
    case error
}
