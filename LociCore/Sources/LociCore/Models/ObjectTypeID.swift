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
    /// Built-in Image object type (PR20) — metadata in `objects/image/`; blob in `media/`.
    public static let image = ObjectTypeID("image")
    /// PARA Project type (PR15 starter pack).
    public static let project = ObjectTypeID("project")
    /// PARA Area type (PR15 starter pack).
    public static let area = ObjectTypeID("area")
}
