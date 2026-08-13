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
    /// Built-in Meeting type (PR31) — created from Apple Calendar / fake events.
    public static let meeting = ObjectTypeID("meeting")
    /// Built-in Weblink type (PR32) — Safari clipper / web captures.
    public static let weblink = ObjectTypeID("weblink")
    /// PARA Project type (PR15 starter pack).
    public static let project = ObjectTypeID("project")
    /// PARA Area type (PR15 starter pack).
    public static let area = ObjectTypeID("area")
}
