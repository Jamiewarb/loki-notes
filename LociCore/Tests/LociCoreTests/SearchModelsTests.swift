import XCTest
@testable import LociCore

final class SearchModelsTests: XCTestCase {
    private func meta(title: String, type: ObjectTypeID, idSeed: String) -> LociObjectMeta {
        let uuid = UUID(uuidString: idSeed)!
        return LociObjectMeta(
            id: ObjectID(uuid),
            typeID: type,
            title: title,
            relativePath: "objects/\(type.rawValue)/\(title.lowercased()).md"
        )
    }

    func testGroupingPreservesFirstSeenTypeAndRankOrder() {
        let a = meta(
            title: "Alpha",
            type: .page,
            idSeed: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1"
        )
        let b = meta(
            title: "Beta",
            type: .daily,
            idSeed: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2"
        )
        let c = meta(
            title: "Gamma",
            type: .page,
            idSeed: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3"
        )
        let d = meta(
            title: "Delta",
            type: ObjectTypeID("book"),
            idSeed: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa4"
        )

        // Simulated FTS rank order: page, daily, page, book
        let groups = SearchGrouping.byType([a, b, c, d])
        XCTAssertEqual(groups.map(\.typeID), [.page, .daily, ObjectTypeID("book")])
        XCTAssertEqual(groups[0].items.map(\.title), ["Alpha", "Gamma"])
        XCTAssertEqual(groups[1].items.map(\.title), ["Beta"])
        XCTAssertEqual(groups[2].items.map(\.title), ["Delta"])
        XCTAssertEqual(SearchGrouping.flatten(groups).map(\.title), ["Alpha", "Gamma", "Beta", "Delta"])
    }

    func testFilterByType() {
        let page = meta(
            title: "P",
            type: .page,
            idSeed: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1"
        )
        let daily = meta(
            title: "D",
            type: .daily,
            idSeed: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2"
        )
        XCTAssertEqual(SearchGrouping.filter([page, daily], typeID: nil).count, 2)
        XCTAssertEqual(SearchGrouping.filter([page, daily], typeID: .page).map(\.title), ["P"])
    }

    func testPreferTitleMatchesReorders() {
        let bodyOnly = meta(
            title: "Unrelated",
            type: .page,
            idSeed: "cccccccc-cccc-4ccc-8ccc-ccccccccccc1"
        )
        let titleHit = meta(
            title: "Focus Rituals",
            type: .page,
            idSeed: "cccccccc-cccc-4ccc-8ccc-ccccccccccc2"
        )
        let anotherBody = meta(
            title: "Notes",
            type: .daily,
            idSeed: "cccccccc-cccc-4ccc-8ccc-ccccccccccc3"
        )
        // FTS might return body hit first; UI polish bubbles title matches.
        let ranked = SearchRanking.preferTitleMatches(
            [bodyOnly, titleHit, anotherBody],
            query: "focus"
        )
        XCTAssertEqual(ranked.map(\.title), ["Focus Rituals", "Unrelated", "Notes"])
    }

    func testNormalizeQuery() {
        XCTAssertEqual(SearchRanking.normalizeQuery("  deep   work  "), "deep work")
        XCTAssertEqual(SearchRanking.normalizeQuery("   "), "")
        XCTAssertTrue(SearchRanking.titleMatches("Deep Work Notes", query: "deep work"))
        XCTAssertFalse(SearchRanking.titleMatches("Shallow", query: "deep"))
    }

    func testRecentSearchStoreDedupesAndCaps() {
        var store = RecentSearchStore(limit: 3)
        store.record("focus")
        store.record("daily")
        store.record("FOCUS") // case-insensitive move-to-front
        store.record("tags")
        store.record("para")
        XCTAssertEqual(store.queries, ["para", "tags", "focus"])
        store.clear()
        XCTAssertTrue(store.queries.isEmpty)
        store.record("   ")
        XCTAssertTrue(store.queries.isEmpty)
    }
}
