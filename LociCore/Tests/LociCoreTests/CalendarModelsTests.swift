import XCTest
@testable import LociCore

final class CalendarModelsTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        cal.firstWeekday = 1 // Sunday
        calendar = cal
    }

    func testMonthGridPadsToSixWeeks() {
        let anchor = calendar.date(from: DateComponents(year: 2026, month: 8, day: 13))!
        let grid = CalendarGridBuilder.build(
            scope: .month,
            anchor: anchor,
            markers: [],
            selected: anchor,
            today: anchor,
            calendar: calendar
        )
        XCTAssertEqual(grid.scope, .month)
        XCTAssertEqual(grid.cells.count, 42)
        XCTAssertEqual(grid.columns, 7)
        XCTAssertEqual(grid.title, "August 2026")
        XCTAssertEqual(grid.weekdaySymbols.count, 7)

        let inMonth = grid.cells.filter(\.inCurrentPeriod)
        XCTAssertEqual(inMonth.count, 31)

        let selected = grid.cells.first { $0.isSelected }
        XCTAssertEqual(selected?.dayKey, "2026-08-13")
        XCTAssertTrue(selected?.isToday == true)
    }

    func testWeekGridIsSevenDaysFromWeekStart() {
        let anchor = calendar.date(from: DateComponents(year: 2026, month: 8, day: 13))!
        let grid = CalendarGridBuilder.build(
            scope: .week,
            anchor: anchor,
            markers: [],
            selected: anchor,
            today: nil,
            calendar: calendar
        )
        XCTAssertEqual(grid.cells.count, 7)
        XCTAssertEqual(grid.cells.first?.dayKey, "2026-08-09") // Sunday
        XCTAssertEqual(grid.cells.last?.dayKey, "2026-08-15")
        XCTAssertTrue(grid.cells.allSatisfy(\.inCurrentPeriod))
        XCTAssertTrue(grid.title.contains("2026-08-09"))
        XCTAssertTrue(grid.title.contains("2026-08-15"))
    }

    func testMarkersAttachAndDotFlags() {
        let markers = [
            CalendarDayMarker(
                dayKey: "2026-08-13",
                hasDailyNote: true,
                hasContent: true,
                creationCount: 2
            ),
            CalendarDayMarker(dayKey: "2026-08-12", hasDailyNote: true, creationCount: 0),
        ]
        let anchor = calendar.date(from: DateComponents(year: 2026, month: 8, day: 1))!
        let grid = CalendarGridBuilder.build(
            scope: .month,
            anchor: anchor,
            markers: markers,
            selected: nil,
            today: nil,
            calendar: calendar
        )
        let day13 = grid.cells.first { $0.dayKey == "2026-08-13" }
        XCTAssertEqual(day13?.marker?.creationCount, 2)
        XCTAssertTrue(day13?.showsDot == true)
        let day12 = grid.cells.first { $0.dayKey == "2026-08-12" }
        XCTAssertTrue(day12?.showsDot == true)
        XCTAssertEqual(grid.markedDayCount, 2)
    }

    func testShiftAnchorMonthAndWeek() {
        let anchor = calendar.date(from: DateComponents(year: 2026, month: 8, day: 13))!
        let nextMonth = CalendarGridBuilder.shiftAnchor(
            anchor,
            scope: .month,
            by: 1,
            calendar: calendar
        )
        XCTAssertEqual(DailyNoteIdentity.title(for: nextMonth, calendar: calendar), "2026-09-13")
        let prevWeek = CalendarGridBuilder.shiftAnchor(
            anchor,
            scope: .week,
            by: -1,
            calendar: calendar
        )
        XCTAssertEqual(DailyNoteIdentity.title(for: prevWeek, calendar: calendar), "2026-08-06")
    }

    func testVisibleRangeIncludesPadding() {
        let anchor = calendar.date(from: DateComponents(year: 2026, month: 8, day: 1))!
        let range = CalendarGridBuilder.visibleRange(
            scope: .month,
            anchor: anchor,
            calendar: calendar
        )
        XCTAssertEqual(DailyNoteIdentity.title(for: range.start, calendar: calendar), "2026-07-26")
        XCTAssertEqual(DailyNoteIdentity.title(for: range.end, calendar: calendar), "2026-09-05")
    }

    func testMondayFirstWeekdaySymbols() {
        var cal = calendar!
        cal.firstWeekday = 2
        let symbols = CalendarGridBuilder.build(
            scope: .week,
            anchor: Date(),
            markers: [],
            selected: nil,
            today: nil,
            calendar: cal
        ).weekdaySymbols
        XCTAssertEqual(symbols.first, "M")
    }
}
