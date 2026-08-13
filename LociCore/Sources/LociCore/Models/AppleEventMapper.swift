import Foundation

/// Map EventKit (or any store) field bags → Core models. **Never imports EventKit.**
///
/// Vault `EventKitCalendarStore` extracts `EKEvent` properties and calls these
/// functions so Linux XCTest can cover mapping without the EventKit SDK (PR36).
public enum AppleCalendarEventMapper: Sendable {
    /// Returns nil when start or end is missing (EventKit all-day still supplies both).
    public static func map(
        id: String?,
        title: String?,
        start: Date?,
        end: Date?,
        location: String?,
        calendarName: String?,
        notes: String?
    ) -> AppleCalendarEvent? {
        guard let start, let end else { return nil }
        let trimmedID = id?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return AppleCalendarEvent(
            id: trimmedID.isEmpty ? "event-\(Int(start.timeIntervalSince1970))" : trimmedID,
            title: trimmedTitle.isEmpty ? "Untitled event" : trimmedTitle,
            start: start,
            end: end,
            location: emptyToNil(location),
            calendarName: emptyToNil(calendarName),
            notes: emptyToNil(notes)
        )
    }

    private static func emptyToNil(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

/// Map Reminders field bags → `AppleReminderItem`. No EventKit types.
public enum AppleReminderItemMapper: Sendable {
    public static func map(
        id: String?,
        title: String?,
        isCompleted: Bool,
        due: Date?,
        calendar: Calendar = .current
    ) -> AppleReminderItem? {
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmedTitle.isEmpty else { return nil }
        let trimmedID = id?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return AppleReminderItem(
            id: trimmedID.isEmpty ? "reminder-\(trimmedTitle)" : trimmedID,
            title: trimmedTitle,
            isCompleted: isCompleted,
            dueDayKey: due.map { ReminderTaskMapper.dayKey(for: $0, calendar: calendar) }
        )
    }
}

/// Map EventKit `EKAuthorizationStatus` raw values without importing EventKit.
public enum AppleAuthStatusMapper: Sendable {
    /// Stable `EKAuthorizationStatus` integers:
    /// 0 notDetermined, 1 restricted, 2 denied, 3 authorized (deprecated),
    /// 4 writeOnly (iOS 17 / macOS 14), 5 fullAccess.
    ///
    /// Write-only cannot list events/reminders — treated as denied for reads.
    public static func fromEventKitRawValue(_ raw: Int) -> AppleAuthStatus {
        switch raw {
        case 0:
            return .notDetermined
        case 3, 5:
            return .authorized
        default:
            return .denied
        }
    }
}
