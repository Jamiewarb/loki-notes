import LociCore
import XCTest

final class GraphPolishProofTests: XCTestCase {
    func testEvaluateAllFlags() {
        let proof = GraphPolishProof.evaluate(
            fullTitles: ["Hub", "A", "B", "E", "F"],
            hiddenTitles: ["A", "B", "E", "F"],
            hubTitle: "Hub",
            spokeTitles: ["A", "B"],
            focusedTitles: ["Hub", "A"],
            expectedFocusTitles: ["Hub", "A"],
            vaultTexts: [
                "---\nid: aaa\ntitle: Hub\n---\nSee [[bbb|A]].\n",
                #"{"name":"Demo Graph","pins":[]}"#,
            ],
            indexInsideVault: false
        )
        XCTAssertTrue(proof.hidesHighDegree)
        XCTAssertTrue(proof.focusNeighbors)
        XCTAssertTrue(proof.layoutNotWrittenToVault)
        XCTAssertFalse(proof.indexInsideVault)
        XCTAssertTrue(GraphPolishNotes.hidesHighDegree)
        XCTAssertTrue(GraphPolishNotes.layoutNotWrittenToVault)
        XCTAssertTrue(GraphPolishNotes.neverOnTypingPath)
        XCTAssertEqual(GraphPolishNotes.defaultHideHubDegree, 8)
        XCTAssertEqual(GraphPolishNotes.queryProtocol, "IndexQuerying.graph")
    }

    func testFailsWhenHubRemainsOrLayoutWritten() {
        let proof = GraphPolishProof.evaluate(
            fullTitles: ["Hub", "A"],
            hiddenTitles: ["Hub", "A"],
            hubTitle: "Hub",
            spokeTitles: ["A"],
            focusedTitles: ["Hub", "A", "E"],
            expectedFocusTitles: ["Hub", "A"],
            vaultTexts: ["See this graph-node at layout-x 12.\n"],
            indexInsideVault: true
        )
        XCTAssertFalse(proof.hidesHighDegree)
        XCTAssertFalse(proof.focusNeighbors)
        XCTAssertFalse(proof.layoutNotWrittenToVault)
        XCTAssertTrue(proof.indexInsideVault)
    }

    func testMarkdownLooksLikeGraphLayout() {
        XCTAssertTrue(
            GraphPolishProof.markdownLooksLikeGraphLayout("data-harness=\"graph-node\"")
        )
        XCTAssertTrue(GraphPolishProof.markdownLooksLikeGraphLayout("graph-layout coords"))
        XCTAssertFalse(GraphPolishProof.markdownLooksLikeGraphLayout("See [[id|Deep Work]].\n"))
        XCTAssertFalse(GraphPolishProof.markdownLooksLikeGraphLayout("Focus is a skill.\n"))
    }
}
