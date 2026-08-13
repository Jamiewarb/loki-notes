import XCTest
@testable import LociCore

final class TagModelsTests: XCTestCase {
    func testNormalizationAndUniquing() {
        XCTAssertEqual(TagNormalization.normalize("#Health"), "health")
        XCTAssertEqual(TagNormalization.display("Health"), "#health")
        XCTAssertEqual(
            TagNormalization.uniquing(["#A", "a", "B", "#b"]),
            ["a", "b"]
        )
    }

    func testAliasCanonicalAndExpansion() {
        let table = TagAliasTable(aliasesByCanonical: [
            "health": ["wellness", "fit"],
        ])
        XCTAssertEqual(table.canonical(for: "wellness"), "health")
        XCTAssertEqual(table.canonical(for: "#Health"), "health")
        let expansion = table.expansion(for: "wellness")
        XCTAssertTrue(expansion.contains("health"))
        XCTAssertTrue(expansion.contains("wellness"))
        XCTAssertTrue(expansion.contains("fit"))
    }

    func testTagFilterMatchesAliases() {
        let meta = LociObjectMeta(
            id: ObjectID(),
            typeID: .page,
            title: "Gym",
            relativePath: "objects/page/gym.md",
            tags: ["health"]
        )
        let aliases = TagAliasTable(aliasesByCanonical: ["health": ["wellness"]])
        XCTAssertTrue(TagFilter.matches(meta, tag: "wellness", aliases: aliases))
        XCTAssertFalse(TagFilter.matches(meta, tag: "archive", aliases: aliases))
    }

    func testSpaceSettingsTagAliasesRoundTrip() throws {
        let settings = SpaceSettings(
            name: "Tags Lab",
            tagAliases: ["health": ["wellness", "#Fit"]]
        )
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(SpaceSettings.self, from: data)
        XCTAssertEqual(decoded.tagAliasTable.canonical(for: "fit"), "health")
        XCTAssertEqual(decoded.tagAliases["health"]?.sorted(), ["fit", "wellness"])
    }

    func testSpaceSettingsDecodesWithoutTagAliases() throws {
        let json = Data(#"{"name":"Legacy","schemaVersion":1}"#.utf8)
        let settings = try JSONDecoder().decode(SpaceSettings.self, from: json)
        XCTAssertTrue(settings.tagAliases.isEmpty)
    }
}
