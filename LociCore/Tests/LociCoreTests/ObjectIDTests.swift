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

    func testCodableRoundTrip() throws {
        let original = ObjectID()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ObjectID.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
