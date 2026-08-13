import XCTest
@testable import LociCore

final class ObjectIDTests: XCTestCase {
    func testRoundTripUUIDString() {
        let original = ObjectID()
        let parsed = ObjectID(uuidString: original.uuidString)
        XCTAssertEqual(parsed, original)
    }

    func testInvalidUUIDStringReturnsNil() {
        XCTAssertNil(ObjectID(uuidString: "not-a-uuid"))
    }

    func testDailyDateKeyFormat() {
        XCTAssertEqual(ObjectID.dailyDateKey(year: 2026, month: 8, day: 13), "daily-2026-08-13")
    }

    func testDailyObjectIDIsDeterministicAndStableAcrossCalls() {
        let a = ObjectID.daily(year: 2026, month: 8, day: 13)
        let b = ObjectID.daily(year: 2026, month: 8, day: 13)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.uuidString.lowercased(), "d01a2026-0813-4000-8000-6461696c7900")
        XCTAssertEqual(a.dailyDateKey, "daily-2026-08-13")
        XCTAssertEqual(a.frontMatterIDString, "daily-2026-08-13")
    }

    func testParsingDailyDateKeyYieldsSameID() {
        let fromKey = ObjectID(parsing: "daily-2026-08-13")
        let fromFactory = ObjectID.daily(year: 2026, month: 8, day: 13)
        XCTAssertEqual(fromKey, fromFactory)
    }

    func testDifferentDaysHaveDifferentIDs() {
        let a = ObjectID.daily(year: 2026, month: 8, day: 13)
        let b = ObjectID.daily(year: 2026, month: 8, day: 14)
        XCTAssertNotEqual(a, b)
        XCTAssertNotEqual(
            DailyNoteIdentity.relativePath(year: 2026, month: 8, day: 13),
            DailyNoteIdentity.relativePath(year: 2026, month: 8, day: 14)
        )
    }

    func testDailyNoteIdentityPathAndNavigation() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = cal.date(from: DateComponents(year: 2026, month: 8, day: 13))!
        XCTAssertEqual(DailyNoteIdentity.relativePath(for: day, calendar: cal), "daily/2026-08-13.md")
        XCTAssertEqual(DailyNoteIdentity.dateKey(for: day, calendar: cal), "daily-2026-08-13")
        XCTAssertEqual(DailyNoteIdentity.title(for: day, calendar: cal), "2026-08-13")
        let prev = DailyNoteIdentity.previousDay(of: day, calendar: cal)
        let next = DailyNoteIdentity.nextDay(of: day, calendar: cal)
        XCTAssertEqual(DailyNoteIdentity.title(for: prev, calendar: cal), "2026-08-12")
        XCTAssertEqual(DailyNoteIdentity.title(for: next, calendar: cal), "2026-08-14")
    }

    func testCodableRoundTrip() throws {
        let original = ObjectID()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ObjectID.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
