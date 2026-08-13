import LociCore
import XCTest

final class UnlinkedMentionProofTests: XCTestCase {
    func testEvaluateAllFlags() {
        let body = "I read Deep Work yesterday\n"
        let proof = UnlinkedMentionProof.evaluate(
            plainBody: body,
            wikiLinkedBody: "[[Deep Work]] yesterday",
            wordBoundaryBody: "deep working",
            title: "Deep Work",
            bodyBefore: body,
            bodyAfterScan: body,
            indexInsideVault: false
        )
        XCTAssertTrue(proof.detectsPlainTitle)
        XCTAssertTrue(proof.ignoresExistingWikiLink)
        XCTAssertTrue(proof.doesNotRewriteBody)
        XCTAssertFalse(proof.indexInsideVault)
        XCTAssertTrue(UnlinkedMentionNotes.detectsPlainTitle)
        XCTAssertTrue(UnlinkedMentionNotes.doesNotRewriteBody)
        XCTAssertTrue(UnlinkedMentionNotes.neverOnTypingPath)
        XCTAssertEqual(UnlinkedMentionNotes.queryProtocol, "IndexQuerying.unlinkedMentions")
        XCTAssertEqual(UnlinkedMentionNotes.resultLimit, 50)
    }

    func testTrailingNewlineDoesNotCountAsRewrite() {
        let proof = UnlinkedMentionProof.evaluate(
            plainBody: "I read Deep Work yesterday\n",
            wikiLinkedBody: "[[Deep Work]] yesterday",
            wordBoundaryBody: "deep working",
            title: "Deep Work",
            bodyBefore: "I read Deep Work yesterday\n",
            bodyAfterScan: "I read Deep Work yesterday",
            indexInsideVault: false
        )
        XCTAssertTrue(proof.doesNotRewriteBody)
        XCTAssertTrue(proof.detectsPlainTitle)
    }

    func testFailsWhenWikiLinkCountsAsMention() {
        let proof = UnlinkedMentionProof.evaluate(
            plainBody: "nope",
            wikiLinkedBody: "I read Deep Work yesterday",
            wordBoundaryBody: "I read Deep Work yesterday",
            title: "Deep Work",
            bodyBefore: "plain",
            bodyAfterScan: "See [[id|Deep Work]]",
            indexInsideVault: true
        )
        XCTAssertFalse(proof.detectsPlainTitle)
        XCTAssertFalse(proof.ignoresExistingWikiLink)
        XCTAssertFalse(proof.doesNotRewriteBody)
        XCTAssertTrue(proof.indexInsideVault)
    }
}
