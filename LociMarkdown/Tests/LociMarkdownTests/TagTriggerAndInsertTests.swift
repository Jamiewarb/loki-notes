import XCTest
@testable import LociMarkdown
import LociCore

final class TagTriggerAndInsertTests: XCTestCase {
    func testDetectOpenTag() {
        let t = TagTriggerDetector.detect(in: "Notes #hea")
        XCTAssertEqual(t?.query, "hea")
        XCTAssertEqual(t?.replaceStartOffset, 6)
    }

    func testHeadingIsNotTagTrigger() {
        XCTAssertNil(TagTriggerDetector.detect(in: "# Title"))
        XCTAssertNil(TagTriggerDetector.detect(in: "## Heading"))
    }

    func testCompletedTagIsNotTrigger() {
        XCTAssertNil(TagTriggerDetector.detect(in: "done #health more"))
    }

    func testInsertTagReplacesTrigger() throws {
        let session = try EditorSession(bodyMarkdown: "Notes #hea")
        let trigger = TagTriggerDetector.detect(in: EditorSession.plainText(of: session.blocks[0]))
        let ok = session.insertTag(blockIndex: 0, tag: "health", trigger: trigger)
        XCTAssertTrue(ok)
        let plain = EditorSession.plainText(of: session.blocks[0])
        XCTAssertEqual(plain, "Notes #health ")
    }

    func testTagSyntaxNormalizePreservesCase() {
        XCTAssertEqual(TagSyntax.normalize("#Health"), "Health")
        XCTAssertEqual(TagNormalization.normalize("#Health"), "health")
        XCTAssertEqual(TagNormalization.display("Health"), "#health")
    }
}
