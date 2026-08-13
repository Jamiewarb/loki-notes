import XCTest
import LociCore

/// Mapper tests that must not import EventKit (PR36).
final class AppleEventMapperTests: XCTestCase {
    private var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }

    private func date(y: Int, m: Int, d: Int, h: Int, min: Int) -> Date {
        var comps = DateComponents()
        comps.year = y
        comps.month = m
        comps.day = d
        comps.hour = h
        comps.minute = min
        return utc.date(from: comps)!
    }

    func testMapEventFromSampleFields() {
        let start = date(y: 2026, m: 8, d: 13, h: 10, min: 0)
        let end = date(y: 2026, m: 8, d: 13, h: 11, min: 0)
        let event = AppleCalendarEventMapper.map(
            id: "ek-1",
            title: " Design review ",
            start: start,
            end: end,
            location: "Studio A",
            calendarName: "Work",
            notes: "Ship it"
        )
        XCTAssertEqual(event?.id, "ek-1")
        XCTAssertEqual(event?.title, "Design review")
        XCTAssertEqual(event?.location, "Studio A")
        XCTAssertEqual(event?.calendarName, "Work")
        XCTAssertEqual(event?.notes, "Ship it")
        XCTAssertEqual(event?.start, start)
        XCTAssertEqual(event?.end, end)
    }

    func testMapEventMissingDatesIsNil() {
        XCTAssertNil(
            AppleCalendarEventMapper.map(
                id: "x",
                title: "T",
                start: nil,
                end: date(y: 2026, m: 8, d: 13, h: 11, min: 0),
                location: nil,
                calendarName: nil,
                notes: nil
            )
        )
    }

    func testMapEventEmptyTitleAndId() {
        let start = date(y: 2026, m: 8, d: 13, h: 10, min: 0)
        let end = date(y: 2026, m: 8, d: 13, h: 11, min: 0)
        let event = AppleCalendarEventMapper.map(
            id: "  ",
            title: nil,
            start: start,
            end: end,
            location: "",
            calendarName: nil,
            notes: "  "
        )
        XCTAssertEqual(event?.title, "Untitled event")
        XCTAssertTrue(event?.id.hasPrefix("event-") == true)
        XCTAssertNil(event?.location)
        XCTAssertNil(event?.notes)
    }

    func testMapReminderFromSampleFields() {
        let due = date(y: 2026, m: 8, d: 13, h: 0, min: 0)
        let item = AppleReminderItemMapper.map(
            id: "rem-1",
            title: " Ship PR36 ",
            isCompleted: false,
            due: due,
            calendar: utc
        )
        XCTAssertEqual(item?.id, "rem-1")
        XCTAssertEqual(item?.title, "Ship PR36")
        XCTAssertEqual(item?.dueDayKey, "2026-08-13")
        XCTAssertFalse(item?.isCompleted ?? true)
    }

    func testMapReminderEmptyTitleIsNil() {
        XCTAssertNil(
            AppleReminderItemMapper.map(
                id: "r",
                title: "  ",
                isCompleted: false,
                due: nil
            )
        )
    }

    func testAuthStatusFromEventKitRawValues() {
        XCTAssertEqual(AppleAuthStatusMapper.fromEventKitRawValue(0), .notDetermined)
        XCTAssertEqual(AppleAuthStatusMapper.fromEventKitRawValue(1), .denied)
        XCTAssertEqual(AppleAuthStatusMapper.fromEventKitRawValue(2), .denied)
        XCTAssertEqual(AppleAuthStatusMapper.fromEventKitRawValue(3), .authorized)
        XCTAssertEqual(AppleAuthStatusMapper.fromEventKitRawValue(4), .denied)  // writeOnly
        XCTAssertEqual(AppleAuthStatusMapper.fromEventKitRawValue(5), .authorized)  // fullAccess
        XCTAssertEqual(AppleAuthStatus.denied.permissionLabel, "Denied")
        XCTAssertEqual(AppleAuthStatus.authorized.permissionLabel, "Authorized")
    }

    func testDayKeyRoundTrip() {
        let day = date(y: 2026, m: 8, d: 13, h: 10, min: 0)
        let key = ReminderTaskMapper.dayKey(for: day, calendar: utc)
        XCTAssertEqual(key, "2026-08-13")
        let parsed = ReminderTaskMapper.date(fromDayKey: key, calendar: utc)
        XCTAssertEqual(ReminderTaskMapper.dayKey(for: parsed!, calendar: utc), key)
        XCTAssertNil(ReminderTaskMapper.date(fromDayKey: "nope"))
    }

    func testEventKitProofFlagsWithoutEventKitImport() {
        XCTAssertTrue(EventKitNotes.eventKitStaysOutOfCore)
        XCTAssertTrue(EventKitNotes.eventKitWired)
        #if canImport(EventKit)
        XCTAssertTrue(EventKitNotes.eventKitAvailable)
        XCTAssertFalse(EventKitNotes.linuxUsesFakes)
        #else
        XCTAssertFalse(EventKitNotes.eventKitAvailable)
        XCTAssertTrue(EventKitNotes.linuxUsesFakes)
        #endif
        let proof = EventKitProof.evaluate(dailyUnchanged: true, indexInsideVault: false)
        XCTAssertTrue(proof.eventKitWired)
        XCTAssertTrue(proof.dailyUnchanged)
        XCTAssertFalse(proof.indexInsideVault)
        XCTAssertEqual(proof.linuxUsesFakes, EventKitNotes.linuxUsesFakes)
    }
}
