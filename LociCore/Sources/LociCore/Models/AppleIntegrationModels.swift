import Foundation

/// Calendar event mirrored from Apple Calendar or an in-memory fake (PR31).
/// Pure model — no EventKit dependency.
public struct AppleCalendarEvent: Hashable, Sendable, Codable, Equatable, Identifiable {
    public var id: String
    public var title: String
    public var start: Date
    public var end: Date
    public var location: String?
    public var calendarName: String?
    public var notes: String?

    public init(
        id: String,
        title: String,
        start: Date,
        end: Date,
        location: String? = nil,
        calendarName: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.location = location
        self.calendarName = calendarName
        self.notes = notes
    }
}

/// Reminder item mirrored from Apple Reminders or an in-memory fake (PR31).
public struct AppleReminderItem: Hashable, Sendable, Codable, Equatable, Identifiable {
    public var id: String
    public var title: String
    public var isCompleted: Bool
    /// Local calendar day key `YYYY-MM-DD` when due; nil = no due date.
    public var dueDayKey: String?

    public init(
        id: String,
        title: String,
        isCompleted: Bool = false,
        dueDayKey: String? = nil
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.dueDayKey = dueDayKey
    }
}

/// Authorization mirror for Calendar / Reminders (EventKit on Apple; fake on Linux).
public enum AppleAuthStatus: String, Codable, Sendable, Hashable, Equatable {
    case notDetermined
    case denied
    case authorized
    case unavailable

    /// Short status for Settings / Apple panel copy (PR36).
    public var permissionLabel: String {
        switch self {
        case .notDetermined: return "Not determined"
        case .denied: return "Denied"
        case .authorized: return "Authorized"
        case .unavailable: return "Unavailable"
        }
    }
}

/// Settings for Apple Calendar / Reminders integrations (Application Support JSON — never vault).
public struct AppleIntegrationSettings: Hashable, Sendable, Codable, Equatable {
    /// When true, explicit “Sync Reminders” may pull/push task lines. Default false.
    public var remindersSyncEnabled: Bool

    public init(remindersSyncEnabled: Bool = false) {
        self.remindersSyncEnabled = remindersSyncEnabled
    }
}

/// Filter calendar events that overlap a local calendar day (no EventKit).
public enum AppleEventDayFilter: Sendable {
    /// Events whose `[start, end)` interval intersects the local day window.
    public static func events(
        _ events: [AppleCalendarEvent],
        on day: Date,
        calendar: Calendar = .current
    ) -> [AppleCalendarEvent] {
        let startOfDay = calendar.startOfDay(for: day)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }
        return events.filter { event in
            event.start < endOfDay && event.end > startOfDay
        }
        .sorted { $0.start < $1.start }
    }
}

/// Build Meeting object title / body / properties from an `AppleCalendarEvent` (pure).
public enum MeetingObjectFactory: Sendable {
    public static func title(from event: AppleCalendarEvent) -> String {
        let trimmed = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Meeting" : trimmed
    }

    /// Notes + time range markdown. No EventKit.
    public static func bodyMarkdown(from event: AppleCalendarEvent) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "HH:mm"
        let range = "\(formatter.string(from: event.start))–\(formatter.string(from: event.end)) UTC"
        var lines: [String] = ["## \(title(from: event))", "", range]
        if let location = event.location?.trimmingCharacters(in: .whitespacesAndNewlines),
            !location.isEmpty
        {
            lines.append("Location: \(location)")
        }
        if let calendarName = event.calendarName?.trimmingCharacters(in: .whitespacesAndNewlines),
            !calendarName.isEmpty
        {
            lines.append("Calendar: \(calendarName)")
        }
        if let notes = event.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
            lines.append("")
            lines.append(notes)
        }
        lines.append("")
        return lines.joined(separator: "\n")
    }

    public static func properties(from event: AppleCalendarEvent) -> [String: PropertyValue] {
        var props: [String: PropertyValue] = [
            "event-id": .text(event.id),
            "start": .date(event.start),
            "end": .date(event.end),
        ]
        if let location = event.location {
            props["location"] = .text(location)
        }
        if let calendarName = event.calendarName {
            props["calendar"] = .text(calendarName)
        }
        return props
    }
}

/// Map Reminders ↔ GFM task lines (`- [ ] title`).
public enum ReminderTaskMapper: Sendable {
    public static func taskLine(from reminder: AppleReminderItem) -> String {
        let box = reminder.isCompleted ? "[x]" : "[ ]"
        let title = reminder.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return "- \(box) \(title)"
    }

    public static func titleFromTaskLine(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("- [") else { return nil }
        // `- [ ] title` or `- [x] title`
        guard let close = trimmed.firstIndex(of: "]") else { return nil }
        let after = trimmed[trimmed.index(after: close)...]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return after.isEmpty ? nil : String(after)
    }

    /// True when body already contains a task line with the same title text.
    public static func bodyContainsTask(title: String, body: String) -> Bool {
        let needle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return false }
        for line in body.split(separator: "\n", omittingEmptySubsequences: false) {
            if let existing = titleFromTaskLine(String(line)),
                existing.caseInsensitiveCompare(needle) == .orderedSame
            {
                return true
            }
        }
        return false
    }

    public static func appendMissingTask(title: String, toBody body: String) -> String {
        if bodyContainsTask(title: title, body: body) { return body }
        let line = taskLine(
            from: AppleReminderItem(id: "local", title: title, isCompleted: false)
        )
        if body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return line + "\n"
        }
        var out = body
        if !out.hasSuffix("\n") { out += "\n" }
        out += line + "\n"
        return out
    }

    public static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        DailyNoteIdentity.title(for: date, calendar: calendar)
    }

    /// Parse `YYYY-MM-DD` back to a local calendar date (EventKit due components).
    public static func date(fromDayKey key: String, calendar: Calendar = .current) -> Date? {
        let parts = key.split(separator: "-")
        guard parts.count == 3,
            let year = Int(parts[0]),
            let month = Int(parts[1]),
            let day = Int(parts[2])
        else {
            return nil
        }
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        return calendar.date(from: comps)
    }
}
