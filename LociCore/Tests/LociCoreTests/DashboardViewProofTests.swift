import LociCore
import XCTest

final class DashboardViewProofTests: XCTestCase {
    func testEvaluateAllFlags() {
        let proof = DashboardViewProof.evaluate(
            filteredTitles: ["Deep Work", "Range"],
            expectedFilteredTitles: ["Deep Work", "Range"],
            sortedTitles: ["Deep Work", "Range"],
            expectedSortedTitles: ["Deep Work", "Range"],
            sectionKeys: ["Reading"],
            expectedSectionKey: "Reading",
            objectMarkdownUnchanged: true,
            dailyUnchanged: true,
            indexInsideVault: false
        )
        XCTAssertTrue(proof.filterApplied)
        XCTAssertTrue(proof.sortApplied)
        XCTAssertTrue(proof.groupApplied)
        XCTAssertTrue(proof.resultsNotWrittenToMarkdown)
        XCTAssertFalse(proof.indexInsideVault)
        XCTAssertTrue(DashboardViewNotes.usesQueryEngine)
        XCTAssertEqual(DashboardViewNotes.queryProtocol, "IndexQuerying.execute")
        XCTAssertTrue(DashboardViewNotes.groupByIsDerivedUI)
        XCTAssertTrue(DashboardViewNotes.resultsNotWrittenToMarkdown)
        XCTAssertTrue(DashboardViewNotes.mustNotImportQueriesFeature)
    }

    func testFailsWhenMarkdownRewritten() {
        let proof = DashboardViewProof.evaluate(
            filteredTitles: ["Deep Work"],
            expectedFilteredTitles: ["Deep Work"],
            sortedTitles: ["Deep Work"],
            expectedSortedTitles: ["Deep Work"],
            sectionKeys: ["Reading"],
            expectedSectionKey: "Reading",
            objectMarkdownUnchanged: false,
            dailyUnchanged: true,
            indexInsideVault: false
        )
        XCTAssertFalse(proof.resultsNotWrittenToMarkdown)
        XCTAssertTrue(proof.filterApplied)
    }

    func testFailsWhenIndexInsideVault() {
        let proof = DashboardViewProof.evaluate(
            filteredTitles: ["Deep Work"],
            expectedFilteredTitles: ["Range"],
            sortedTitles: ["Range", "Deep Work"],
            expectedSortedTitles: ["Deep Work", "Range"],
            sectionKeys: ["Done"],
            expectedSectionKey: "Reading",
            objectMarkdownUnchanged: true,
            dailyUnchanged: false,
            indexInsideVault: true
        )
        XCTAssertFalse(proof.filterApplied)
        XCTAssertFalse(proof.sortApplied)
        XCTAssertFalse(proof.groupApplied)
        XCTAssertFalse(proof.resultsNotWrittenToMarkdown)
        XCTAssertTrue(proof.indexInsideVault)
    }
}
