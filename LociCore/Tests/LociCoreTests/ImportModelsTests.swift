import XCTest
import LociCore

final class ImportModelsTests: XCTestCase {
    func testDailyPathDetection() {
        XCTAssertTrue(ImportPathRules.looksLikeDaily(relativePath: "Daily Notes/2026-08-01.md"))
        XCTAssertTrue(ImportPathRules.looksLikeDaily(relativePath: "daily/2026-08-01.md"))
        XCTAssertTrue(ImportPathRules.looksLikeDaily(relativePath: "2026-08-01.md"))
        XCTAssertFalse(ImportPathRules.looksLikeDaily(relativePath: "notes/hello.md"))
        let ymd = ImportPathRules.parseDailyDateKey("2026-08-01.md")
        XCTAssertEqual(ymd?.year, 2026)
        XCTAssertEqual(ymd?.month, 8)
        XCTAssertEqual(ymd?.day, 1)
        let dest = ImportPathRules.dailyDestination(year: 2026, month: 8, day: 1)
        XCTAssertEqual(dest.path, "daily/2026-08-01.md")
        XCTAssertEqual(dest.id.frontMatterIDString, "daily-2026-08-01")
    }

    func testSlugifyAndObjectDestination() {
        XCTAssertEqual(ImportPathRules.slugify("Hello World"), "hello-world")
        let id = ObjectID(uuidString: "11111111-2222-4333-8444-555555555555")!
        let path = ImportPathRules.objectDestination(typeID: .page, title: "Hello World", id: id)
        XCTAssertEqual(path, "objects/page/hello-world.md")
    }

    func testTypeNameMapping() {
        XCTAssertEqual(ImportPathRules.mapTypeName("Page"), .page)
        XCTAssertEqual(ImportPathRules.mapTypeName("Book"), ObjectTypeID("book"))
        XCTAssertEqual(ImportPathRules.mapTypeName("Project"), .project)
        XCTAssertEqual(ImportPathRules.mapTypeName(nil), .page)
    }

    func testSourceDetector() {
        XCTAssertEqual(
            ImportSourceDetector.detect(topLevelNames: [".obsidian", "Welcome.md"]),
            .obsidianVault
        )
        XCTAssertEqual(
            ImportSourceDetector.detect(topLevelNames: ["Objects", "capacities.json"]),
            .capacitiesExport
        )
        XCTAssertEqual(
            ImportSourceDetector.detect(topLevelNames: ["notes", "hello.md"]),
            .markdownFolder
        )
    }

    func testWikiLinkRewriter() {
        let body = "See [[Welcome]] and [[Missing]]."
        let (out, unresolved) = ImportWikiLinkRewriter.rewrite(
            body,
            titleIndex: ["welcome": "welcome"]
        )
        XCTAssertTrue(out.contains("[[welcome|Welcome]]") || out.contains("[[welcome]]"))
        XCTAssertEqual(unresolved, ["Missing"])
    }

    func testDryRunSummaryCounts() {
        let id = ObjectID()
        let item = ImportPlanItem(
            sourcePath: "/tmp/a.md",
            sourceRelativePath: "a.md",
            title: "A",
            typeID: .page,
            objectID: id,
            destinationRelativePath: "objects/page/a.md",
            action: .create,
            preservedObjectID: true
        )
        let summary = ImportDryRunSummary(
            sourceKind: .markdownFolder,
            sourceRoot: "/tmp",
            conflictPolicy: .skip,
            items: [item]
        )
        XCTAssertEqual(summary.createCount, 1)
        XCTAssertEqual(summary.preservedIDCount, 1)
    }
}
