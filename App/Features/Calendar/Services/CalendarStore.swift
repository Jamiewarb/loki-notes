import Foundation
import LociCore

/// Thin feature-local facade over IndexQuerying for calendar markers (PR25).
@MainActor
final class CalendarStore {
    private let index: (any IndexQuerying)?

    init(index: (any IndexQuerying)?) {
        self.index = index
    }

    func markers(
        from: Date,
        to: Date,
        calendar: Calendar
    ) async throws -> [CalendarDayMarker] {
        guard let index else { return [] }
        return try await index.calendarMarkers(from: from, to: to, calendar: calendar)
    }

    func grid(
        scope: CalendarScope,
        anchor: Date,
        selected: Date?,
        today: Date,
        calendar: Calendar
    ) async throws -> CalendarGrid {
        let range = CalendarGridBuilder.visibleRange(
            scope: scope,
            anchor: anchor,
            calendar: calendar
        )
        let markers = try await markers(from: range.start, to: range.end, calendar: calendar)
        return CalendarGridBuilder.build(
            scope: scope,
            anchor: anchor,
            markers: markers,
            selected: selected,
            today: today,
            calendar: calendar
        )
    }
}
