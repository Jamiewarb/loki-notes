import Foundation

/// Stable identity for a vault object. Persisted in frontmatter `id`; never a file URL.
///
/// **Daily notes (PR10):** logical id is `daily-YYYY-MM-DD`. That key maps to a
/// deterministic UUID so index/API types stay `ObjectID`-based while two devices
/// never fork a second “today”. Frontmatter may store either the date key or the UUID.
public struct ObjectID: Hashable, Sendable, Codable, CustomStringConvertible {
    public let rawValue: UUID

    public init(_ rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }

    public init?(uuidString: String) {
        guard let uuid = UUID(uuidString: uuidString) else { return nil }
        self.rawValue = uuid
    }

    /// Accept UUID strings **or** daily date keys (`daily-YYYY-MM-DD`).
    public init?(parsing string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if let uuid = UUID(uuidString: trimmed) {
            self.rawValue = uuid
            return
        }
        if let parts = Self.parseDailyDateKey(trimmed) {
            self = Self.daily(year: parts.year, month: parts.month, day: parts.day)
            return
        }
        return nil
    }

    /// Deterministic daily-note id key: `daily-YYYY-MM-DD`.
    public static func dailyDateKey(year: Int, month: Int, day: Int) -> String {
        String(format: "daily-%04d-%02d-%02d", year, month, day)
    }

    public static func dailyDateKey(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return dailyDateKey(year: c.year ?? 0, month: c.month ?? 0, day: c.day ?? 0)
    }

    /// Deterministic `ObjectID` for a calendar day (UUID namespace for `daily-YYYY-MM-DD`).
    public static func daily(year: Int, month: Int, day: Int) -> ObjectID {
        // Layout: d01aYYYY-MMDD-4000-8000-6461696c7900 ("daily\0" marker in node).
        let s = String(
            format: "d01a%04d-%02d%02d-4000-8000-6461696c7900",
            year,
            month,
            day
        )
        guard let uuid = UUID(uuidString: s) else {
            preconditionFailure("daily UUID format must be valid: \(s)")
        }
        return ObjectID(uuid)
    }

    public static func daily(for date: Date, calendar: Calendar = .current) -> ObjectID {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return daily(year: c.year ?? 0, month: c.month ?? 0, day: c.day ?? 0)
    }

    /// When this id is a daily-derived UUID, the matching `daily-YYYY-MM-DD` key.
    public var dailyDateKey: String? {
        guard let parts = Self.ymdFromDailyUUID(rawValue) else { return nil }
        return Self.dailyDateKey(year: parts.year, month: parts.month, day: parts.day)
    }

    /// Frontmatter `id` string: date key for dailies, lowercase UUID otherwise.
    public var frontMatterIDString: String {
        dailyDateKey ?? uuidString.lowercased()
    }

    public var uuidString: String { rawValue.uuidString }

    public var description: String { dailyDateKey ?? uuidString }

    // MARK: - Parsing helpers

    public static func parseDailyDateKey(_ string: String) -> (year: Int, month: Int, day: Int)? {
        let pattern = #"^daily-(\d{4})-(\d{2})-(\d{2})$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(string.startIndex..<string.endIndex, in: string)
        guard let match = regex.firstMatch(in: string, range: range),
            match.numberOfRanges == 4,
            let yRange = Range(match.range(at: 1), in: string),
            let mRange = Range(match.range(at: 2), in: string),
            let dRange = Range(match.range(at: 3), in: string),
            let year = Int(string[yRange]),
            let month = Int(string[mRange]),
            let day = Int(string[dRange]),
            (1...12).contains(month),
            (1...31).contains(day)
        else {
            return nil
        }
        return (year, month, day)
    }

    private static func ymdFromDailyUUID(_ uuid: UUID) -> (year: Int, month: Int, day: Int)? {
        let s = uuid.uuidString.lowercased()
        // d01aYYYY-MMDD-4000-8000-6461696c7900
        guard s.hasPrefix("d01a"),
            s.hasSuffix("-4000-8000-6461696c7900"),
            s.count == 36
        else {
            return nil
        }
        let yearStr = String(s.dropFirst(4).prefix(4))
        let monthStr = String(s.dropFirst(9).prefix(2))
        let dayStr = String(s.dropFirst(11).prefix(2))
        guard let year = Int(yearStr),
            let month = Int(monthStr),
            let day = Int(dayStr),
            (1...12).contains(month),
            (1...31).contains(day)
        else {
            return nil
        }
        return (year, month, day)
    }
}
