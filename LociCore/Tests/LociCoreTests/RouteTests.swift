import XCTest
@testable import LociCore

final class RouteTests: XCTestCase {
    func testPrimaryDestinationsOrder() {
        XCTAssertEqual(
            Route.primaryDestinations,
            [.daily, .search, .types, .settings]
        )
    }

    func testPrimaryFlags() {
        XCTAssertTrue(Route.daily.isPrimaryDestination)
        XCTAssertTrue(Route.settings.isPrimaryDestination)
        XCTAssertFalse(Route.designGallery.isPrimaryDestination)
        XCTAssertFalse(Route.tags.isPrimaryDestination)
        XCTAssertFalse(Route.object(ObjectID()).isPrimaryDestination)
    }

    func testTitlesAndIcons() {
        XCTAssertEqual(Route.daily.title, "Daily")
        XCTAssertEqual(Route.search.systemImage, "magnifyingglass")
        XCTAssertEqual(Route.designGallery.title, "Design")
        XCTAssertEqual(Route.tags.title, "Tags")
        XCTAssertEqual(Route.tags.systemImage, "number")
        XCTAssertFalse(Route.types.subtitle.isEmpty)
    }

    func testCodableRoundTripPrimary() throws {
        let routes: [Route] = [.daily, .search, .types, .settings, .designGallery, .tags]
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
