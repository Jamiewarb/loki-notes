import XCTest
@testable import LociCore

final class RouteTests: XCTestCase {
    func testPrimaryDestinationsOrder() {
        XCTAssertEqual(
            Route.primaryDestinations,
            [.daily, .tasks, .search, .types, .settings]
        )
    }

    func testPrimaryFlags() {
        XCTAssertTrue(Route.daily.isPrimaryDestination)
        XCTAssertTrue(Route.tasks.isPrimaryDestination)
        XCTAssertTrue(Route.settings.isPrimaryDestination)
        XCTAssertFalse(Route.designGallery.isPrimaryDestination)
        XCTAssertFalse(Route.tags.isPrimaryDestination)
        XCTAssertFalse(Route.graph.isPrimaryDestination)
        XCTAssertFalse(Route.calendar.isPrimaryDestination)
        XCTAssertFalse(Route.capture.isPrimaryDestination)
        XCTAssertFalse(Route.importExport.isPrimaryDestination)
        XCTAssertFalse(Route.typeConvert.isPrimaryDestination)
        XCTAssertFalse(Route.ai.isPrimaryDestination)
        XCTAssertFalse(Route.apple.isPrimaryDestination)
        XCTAssertFalse(Route.object(ObjectID()).isPrimaryDestination)
    }

    func testTitlesAndIcons() {
        XCTAssertEqual(Route.daily.title, "Daily")
        XCTAssertEqual(Route.tasks.title, "Tasks")
        XCTAssertEqual(Route.tasks.systemImage, "checklist")
        XCTAssertEqual(Route.search.systemImage, "magnifyingglass")
        XCTAssertEqual(Route.designGallery.title, "Design")
        XCTAssertEqual(Route.tags.title, "Tags")
        XCTAssertEqual(Route.tags.systemImage, "number")
        XCTAssertEqual(Route.graph.title, "Graph")
        XCTAssertFalse(Route.graph.systemImage.isEmpty)
        XCTAssertEqual(Route.calendar.title, "Calendar")
        XCTAssertEqual(Route.calendar.systemImage, "calendar")
        XCTAssertEqual(Route.capture.title, "Capture")
        XCTAssertEqual(Route.capture.systemImage, "tray.and.arrow.down")
        XCTAssertEqual(Route.importExport.title, "Import")
        XCTAssertFalse(Route.importExport.systemImage.isEmpty)
        XCTAssertEqual(Route.typeConvert.title, "Convert")
        XCTAssertFalse(Route.typeConvert.systemImage.isEmpty)
        XCTAssertEqual(Route.ai.title, "AI")
        XCTAssertEqual(Route.ai.subtitle, "Assist · BYOK")
        XCTAssertEqual(Route.ai.systemImage, "sparkles")
        XCTAssertEqual(Route.apple.title, "Apple")
        XCTAssertEqual(Route.apple.subtitle, "Calendar · Reminders")
        XCTAssertFalse(Route.apple.systemImage.isEmpty)
        XCTAssertFalse(Route.types.subtitle.isEmpty)
    }

    func testCodableRoundTripPrimary() throws {
        let routes: [Route] = [
            .daily, .tasks, .search, .types, .settings, .designGallery, .tags, .graph,
            .calendar, .capture, .importExport, .typeConvert, .ai, .apple,
        ]
        let data = try JSONEncoder().encode(routes)
        let decoded = try JSONDecoder().decode([Route].self, from: data)
        XCTAssertEqual(decoded, routes)
    }

    func testCodableRoundTripObject() throws {
        let id = ObjectID()
        let route = Route.object(id)
        let data = try JSONEncoder().encode(route)
        let decoded = try JSONDecoder().decode(Route.self, from: data)
        XCTAssertEqual(decoded, route)
    }
}
