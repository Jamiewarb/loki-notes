import Foundation

/// Stable identity for a vault object. Persisted in frontmatter `id`; never a file URL.
public struct ObjectID: Hashable, Sendable, Codable, CustomStringConvertible {
    public let rawValue: UUID

    public init(_ rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }

    public init?(uuidString: String) {
        guard let uuid = UUID(uuidString: uuidString) else { return nil }
        self.rawValue = uuid
    }

    /// Deterministic daily-note id: `daily-YYYY-MM-DD` mapped into a UUID namespace later;
    /// for now expose the date key used by PR10.
    public static func dailyDateKey(year: Int, month: Int, day: Int) -> String {
        String(format: "daily-%04d-%02d-%02d", year, month, day)
    }

    public var uuidString: String { rawValue.uuidString }

    public var description: String { uuidString }
}
