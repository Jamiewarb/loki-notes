import XCTest
import LociCore

final class AppleIntegrationModelsTests: XCTestCase {
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

    func testDayFilterOverlappingEvents() {
        let day = date(y: 2026, m: 8, d: 13, h: 0, min: 0)
        let onDay = AppleCalendarEvent(
            id: "a",
            title: "Design review",
            start: date(y: 2026, m: 8, d: 13, h: 10, min: 0),
            end: date(y: 2026, m: 8, d: 13, h: 11, min: 0)
        )
        let nextDay = AppleCalendarEvent(
            id: "b",
            title: "Tomorrow",
            start: date(y: 2026, m: 8, d: 14, h: 9, min: 0),
            end: date(y: 2026, m: 8, d: 14, h: 10, min: 0)
        )
        let filtered = AppleEventDayFilter.events([onDay, nextDay], on: day, calendar: utc)
        XCTAssertEqual(filtered.map(\.id), ["a"])
    }

    func testMeetingFactoryBodyAndProperties() {
        let event = AppleCalendarEvent(
            id: "evt-1",
            title: "Design review",
            start: date(y: 2026, m: 8, d: 13, h: 10, min: 0),
            end: date(y: 2026, m: 8, d: 13, h: 11, min: 0),
            location: "Studio A",
            calendarName: "Work",
            notes: "Ship it"
        )
        XCTAssertEqual(MeetingObjectFactory.title(from: event), "Design review")
        let body = MeetingObjectFactory.bodyMarkdown(from: event)
        XCTAssertTrue(body.contains("10:00–11:00 UTC"))
        XCTAssertTrue(body.contains("Location: Studio A"))
        XCTAssertTrue(body.contains("Ship it"))
        let props = MeetingObjectFactory.properties(from: event)
        XCTAssertEqual(props["event-id"], .text("evt-1"))
        XCTAssertEqual(props["location"], .text("Studio A"))
        XCTAssertEqual(props["calendar"], .text("Work"))
        if case .date(let start)? = props["start"] {
            XCTAssertEqual(start, event.start)
        } else {
            XCTFail("expected start date")
        }
    }

    func testReminderTaskMapper() {
        let item = AppleReminderItem(id: "r1", title: "Ship PR31", isCompleted: false)
        XCTAssertEqual(ReminderTaskMapper.taskLine(from: item), "- [ ] Ship PR31")
        XCTAssertEqual(ReminderTaskMapper.titleFromTaskLine("- [x] Done"), "Done")
        XCTAssertTrue(ReminderTaskMapper.bodyContainsTask(title: "Ship PR31", body: "- [ ] Ship PR31\n"))
        XCTAssertFalse(ReminderTaskMapper.bodyContainsTask(title: "Other", body: "- [ ] Ship PR31\n"))
        let appended = ReminderTaskMapper.appendMissingTask(title: "Ship PR31", toBody: "Notes\n")
        XCTAssertTrue(appended.contains("- [ ] Ship PR31"))
        let again = ReminderTaskMapper.appendMissingTask(title: "Ship PR31", toBody: appended)
        XCTAssertEqual(again, appended)
    }

    func testBuiltInMeetingType() throws {
        let meeting = ObjectType.builtInMeeting
        XCTAssertEqual(meeting.id, .meeting)
        XCTAssertTrue(meeting.isBuiltIn)
        XCTAssertTrue(meeting.properties.contains { $0.id == "event-id" })
        XCTAssertTrue(TypeSlug.isProtected(.meeting))
        XCTAssertThrowsError(try TypeSlug.resolve(explicit: "meeting", fromName: "X"))
        let data = try JSONEncoder().encode(meeting)
        let decoded = try JSONDecoder().decode(ObjectType.self, from: data)
        XCTAssertEqual(decoded, meeting)
    }

    func testFakeStores() {
        let cal = FakeAppleCalendarStore()
        let day = date(y: 2026, m: 8, d: 13, h: 0, min: 0)
        cal.replaceAllForTesting([
            AppleCalendarEvent(
                id: "e",
                title: "T",
                start: date(y: 2026, m: 8, d: 13, h: 12, min: 0),
                end: date(y: 2026, m: 8, d: 13, h: 13, min: 0)
            )
        ])
        XCTAssertEqual(cal.events(on: day, calendar: utc).count, 1)
        let rem = FakeAppleRemindersStore()
        rem.upsert(AppleReminderItem(id: "1", title: "A", dueDayKey: "2026-08-13"))
        XCTAssertEqual(rem.reminders(dueOn: day, calendar: utc).count, 1)
    }
}
