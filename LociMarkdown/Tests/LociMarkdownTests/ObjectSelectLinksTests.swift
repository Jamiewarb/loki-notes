import XCTest
import LociCore
import LociMarkdown

final class ObjectSelectLinksTests: XCTestCase {
    func testWikiLinksFromObjectSelectProperties() {
        let person = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1"
        let extra = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2"
        let links = ObjectSelectLinks.wikiLinks(
            from: [
                "author": .objectSelect([person.uppercased(), person]),
                "status": .select("Reading"),
                "related": .objectSelect([extra]),
            ]
        )
        XCTAssertEqual(links.map(\.target), [person, extra])
        XCTAssertEqual(links.map(\.label), ["author", "related"])
    }

    func testMergeDedupesByTargetKeepingBodyLabel() {
        let person = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1"
        let other = "cccccccc-cccc-4ccc-8ccc-ccccccccccc3"
        let merged = ObjectSelectLinks.merge(
            body: [WikiLink(target: person, label: "Cal")],
            properties: [
                "author": .objectSelect([person, other]),
            ]
        )
        XCTAssertEqual(merged.count, 2)
        XCTAssertEqual(merged[0].target, person)
        XCTAssertEqual(merged[0].label, "Cal")
        XCTAssertEqual(merged[1].target, other)
        XCTAssertEqual(merged[1].label, "author")
    }

    func testBrokenIDsStillEmitWikiLinks() {
        let links = ObjectSelectLinks.wikiLinks(
            from: ["author": .objectSelect(["missing-object-zzzz"])]
        )
        XCTAssertEqual(links.count, 1)
        XCTAssertEqual(links[0].target, "missing-object-zzzz")
        XCTAssertEqual(links[0].label, "author")
    }

    func testIgnoresNonObjectSelectValues() {
        let links = ObjectSelectLinks.wikiLinks(
            from: [
                "status": .select("Reading"),
                "labels": .multiSelect(["a", "b"]),
                "url": .url("https://example.com"),
            ]
        )
        XCTAssertTrue(links.isEmpty)
    }
}
