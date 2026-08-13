import Foundation

/// Month vs week presentation for the calendar UI (PR25).
public enum CalendarScope: String, Hashable, Sendable, Codable, CaseIterable {
    case month
    case week
}

/// Index-derived activity for one calendar day (never written into vault markdown).
public struct CalendarDayMarker: Hashable, Sendable, Equatable, Codable {
    /// `YYYY-MM-DD` title key (matches `DailyNoteIdentity.title`).
    public var dayKey: String
    /// Daily note object exists at `daily/YYYY-MM-DD.md`.
    public var hasDailyNote: Bool
    /// Daily note FTS body is non-empty (content, not empty shell).
    public var hasContent: Bool
    /// Count of objects whose `created` falls on this day (`IndexQuerying.created(on:)`).
    public var creationCount: Int

    public init(
        dayKey: String,
        hasDailyNote: Bool = false,
        hasContent: Bool = false,
        creationCount: Int = 0
    ) {
        self.dayKey = dayKey
        self.hasDailyNote = hasDailyNote
        self.hasContent = hasContent
        self.creationCount = max(0, creationCount)
    }

    /// UI chrome: show a dot when the day has a daily note, body content, or creations.
    public var showsDot: Bool {
        hasDailyNote || hasContent || creationCount > 0
    }

    public var hasCreations: Bool { creationCount > 0 }
}

/// One cell in a month/week grid.
public struct CalendarCell: Hashable, Sendable, Equatable, Codable, Identifiable {
    public var day: Date
    public var dayKey: String
    /// False for leading/trailing padding days outside the focused month.
    public var inCurrentPeriod: Bool
    public var isToday: Bool
    public var isSelected: Bool
    public var marker: CalendarDayMarker?

    public var id: String { dayKey }

    public init(
        day: Date,
        dayKey: String,
        inCurrentPeriod: Bool,
        isToday: Bool,
        isSelected: Bool,
        marker: CalendarDayMarker? = nil
    ) {
        self.day = day
        self.dayKey = dayKey
        self.inCurrentPeriod = inCurrentPeriod
        self.isToday = isToday
        self.isSelected = isSelected
        self.marker = marker
    }

    public var showsDot: Bool { marker?.showsDot ?? false }
}

/// Flat row-major calendar grid ready for UI / harness.
public struct CalendarGrid: Hashable, Sendable, Equatable, Codable {
    public var scope: CalendarScope
    public var anchor: Date
    public var title: String
    public var weekdaySymbols: [String]
    public var cells: [CalendarCell]
    public var columns: Int

    public init(
        scope: CalendarScope,
        anchor: Date,
        title: String,
        weekdaySymbols: [String],
        cells: [CalendarCell],
        columns: Int = 7
    ) {
        self.scope = scope
        self.anchor = anchor
        self.title = title
        self.weekdaySymbols = weekdaySymbols
        self.cells = cells
        self.columns = columns
    }

    public var markedDayCount: Int {
        cells.filter { $0.inCurrentPeriod && $0.showsDot }.count
    }
}

/// Pure calendar math — Linux-testable, no I/O.
public enum CalendarGridBuilder: Sendable {
    /// Inclusive start/end of the visible grid (padding days included) for index marker queries.
    public static func visibleRange(
        scope: CalendarScope,
        anchor: Date,
        calendar: Calendar = .current
    ) -> (start: Date, end: Date) {
        let grid = build(
            scope: scope,
            anchor: anchor,
            markers: [],
            selected: nil,
            today: nil,
            calendar: calendar
        )
        guard let first = grid.cells.first?.day, let last = grid.cells.last?.day else {
            let day = DailyNoteIdentity.startOfDay(anchor, calendar: calendar)
            return (day, day)
        }
        return (first, last)
    }

    public static func build(
        scope: CalendarScope,
        anchor: Date,
        markers: [CalendarDayMarker],
        selected: Date?,
        today: Date? = Date(),
        calendar: Calendar = .current
    ) -> CalendarGrid {
        let markerByKey = Dictionary(uniqueKeysWithValues: markers.map { ($0.dayKey, $0) })
        let todayStart = today.map { DailyNoteIdentity.startOfDay($0, calendar: calendar) }
        let selectedStart = selected.map { DailyNoteIdentity.startOfDay($0, calendar: calendar) }
        let symbols = orderedWeekdaySymbols(calendar: calendar)

        switch scope {
        case .month:
            return buildMonth(
                anchor: anchor,
                markerByKey: markerByKey,
                selectedStart: selectedStart,
                todayStart: todayStart,
                weekdaySymbols: symbols,
                calendar: calendar
            )
        case .week:
            return buildWeek(
                anchor: anchor,
                markerByKey: markerByKey,
                selectedStart: selectedStart,
                todayStart: todayStart,
                weekdaySymbols: symbols,
                calendar: calendar
            )
        }
    }

    public static func shiftAnchor(
        _ anchor: Date,
        scope: CalendarScope,
        by periods: Int,
        calendar: Calendar = .current
    ) -> Date {
        let day = DailyNoteIdentity.startOfDay(anchor, calendar: calendar)
        switch scope {
        case .month:
            return calendar.date(byAdding: .month, value: periods, to: day) ?? day
        case .week:
            return calendar.date(byAdding: .weekOfYear, value: periods, to: day) ?? day
        }
    }

    // MARK: - Private

    private static func buildMonth(
        anchor: Date,
        markerByKey: [String: CalendarDayMarker],
        selectedStart: Date?,
        todayStart: Date?,
        weekdaySymbols: [String],
        calendar: Calendar
    ) -> CalendarGrid {
        let monthStart = startOfMonth(anchor, calendar: calendar)
        let gridStart = startOfWeek(containing: monthStart, calendar: calendar)
        let month = calendar.component(.month, from: monthStart)
        let year = calendar.component(.year, from: monthStart)

        var cells: [CalendarCell] = []
        cells.reserveCapacity(42)
        var cursor = gridStart
        for _ in 0..<42 {
            let key = DailyNoteIdentity.title(for: cursor, calendar: calendar)
            let inMonth = calendar.component(.month, from: cursor) == month
            cells.append(
                CalendarCell(
                    day: cursor,
                    dayKey: key,
                    inCurrentPeriod: inMonth,
                    isToday: todayStart.map { calendar.isDate($0, inSameDayAs: cursor) } ?? false,
                    isSelected: selectedStart.map { calendar.isDate($0, inSameDayAs: cursor) }
                        ?? false,
                    marker: markerByKey[key]
                )
            )
            cursor = DailyNoteIdentity.nextDay(of: cursor, calendar: calendar)
        }

        return CalendarGrid(
            scope: .month,
            anchor: monthStart,
            title: monthTitle(month: month, year: year),
            weekdaySymbols: weekdaySymbols,
            cells: cells
        )
    }

    private static func buildWeek(
        anchor: Date,
        markerByKey: [String: CalendarDayMarker],
        selectedStart: Date?,
        todayStart: Date?,
        weekdaySymbols: [String],
        calendar: Calendar
    ) -> CalendarGrid {
        let weekStart = startOfWeek(containing: anchor, calendar: calendar)
        var cells: [CalendarCell] = []
        cells.reserveCapacity(7)
        var cursor = weekStart
        for _ in 0..<7 {
            let key = DailyNoteIdentity.title(for: cursor, calendar: calendar)
            cells.append(
                CalendarCell(
                    day: cursor,
                    dayKey: key,
                    inCurrentPeriod: true,
                    isToday: todayStart.map { calendar.isDate($0, inSameDayAs: cursor) } ?? false,
                    isSelected: selectedStart.map { calendar.isDate($0, inSameDayAs: cursor) }
                        ?? false,
                    marker: markerByKey[key]
                )
            )
            cursor = DailyNoteIdentity.nextDay(of: cursor, calendar: calendar)
        }
        let weekEnd = DailyNoteIdentity.shift(weekStart, byDays: 6, calendar: calendar)
        return CalendarGrid(
            scope: .week,
            anchor: weekStart,
            title: weekTitle(from: weekStart, to: weekEnd, calendar: calendar),
            weekdaySymbols: weekdaySymbols,
            cells: cells
        )
    }

    private static func startOfMonth(_ date: Date, calendar: Calendar) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: comps).map { DailyNoteIdentity.startOfDay($0, calendar: calendar) }
            ?? DailyNoteIdentity.startOfDay(date, calendar: calendar)
    }

    private static func startOfWeek(containing date: Date, calendar: Calendar) -> Date {
        let day = DailyNoteIdentity.startOfDay(date, calendar: calendar)
        let weekday = calendar.component(.weekday, from: day)
        let firstWeekday = calendar.firstWeekday
        let delta = (weekday - firstWeekday + 7) % 7
        return DailyNoteIdentity.shift(day, byDays: -delta, calendar: calendar)
    }

    private static func orderedWeekdaySymbols(calendar: Calendar) -> [String] {
        let raw = calendar.veryShortWeekdaySymbols
        guard !raw.isEmpty else {
            return ["S", "M", "T", "W", "T", "F", "S"]
        }
        let first = calendar.firstWeekday - 1
        if first <= 0 { return Array(raw) }
        return Array(raw[first...]) + Array(raw[..<first])
    }

    private static func monthTitle(month: Int, year: Int) -> String {
        let names = [
            "", "January", "February", "March", "April", "May", "June",
            "July", "August", "September", "October", "November", "December",
        ]
        let name = (month >= 1 && month <= 12) ? names[month] : "Month"
        return "\(name) \(year)"
    }

    private static func weekTitle(from start: Date, to end: Date, calendar: Calendar) -> String {
        let a = DailyNoteIdentity.title(for: start, calendar: calendar)
        let b = DailyNoteIdentity.title(for: end, calendar: calendar)
        return "\(a) – \(b)"
    }
}
