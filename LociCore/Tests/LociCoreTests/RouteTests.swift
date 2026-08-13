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
        XCTAssertFalse(Route.types.subtitle.isEmpty)
    }

    func testCodableRoundTripPrimary() throws {
        let routes: [Route] = [
            .daily, .tasks, .search, .types, .settings, .designGallery, .tags, .graph,
            .calendar,
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
