import Foundation

/// Deterministic path + id scheme for daily notes (PLAN Part 5.1 / Part 14).
///
/// - Path: `daily/YYYY-MM-DD.md`
/// - Logical id: `daily-YYYY-MM-DD` → deterministic `ObjectID`
public enum DailyNoteIdentity: Sendable {
    /// Vault-relative path for a calendar day.
    public static func relativePath(year: Int, month: Int, day: Int) -> String {
        String(format: "daily/%04d-%02d-%02d.md", year, month, day)
    }

    public static func relativePath(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return relativePath(year: c.year ?? 0, month: c.month ?? 0, day: c.day ?? 0)
    }

    public static func dateKey(for date: Date, calendar: Calendar = .current) -> String {
        ObjectID.dailyDateKey(for: date, calendar: calendar)
    }

    public static func objectID(for date: Date, calendar: Calendar = .current) -> ObjectID {
        ObjectID.daily(for: date, calendar: calendar)
    }

    /// Title shown for a daily note (`YYYY-MM-DD`).
    public static func title(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    public static func startOfDay(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    public static func shift(_ date: Date, byDays days: Int, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: days, to: startOfDay(date, calendar: calendar))
            ?? date
    }

    public static func previousDay(of date: Date, calendar: Calendar = .current) -> Date {
        shift(date, byDays: -1, calendar: calendar)
    }

    public static func nextDay(of date: Date, calendar: Calendar = .current) -> Date {
        shift(date, byDays: 1, calendar: calendar)
    }
}
