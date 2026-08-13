import Foundation

/// Identifier for an object type (e.g. `page`, `book`, `daily`).
public struct ObjectTypeID: Hashable, Sendable, Codable, RawRepresentable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public static let page = ObjectTypeID("page")
    public static let daily = ObjectTypeID("daily")
}
