import XCTest
import LociMarkdown

final class TaskBodyEditsTests: XCTestCase {
    func testTogglePersistsCheckedStateInBody() throws {
        let body = """
            Intro

            - [ ] Ship PR19
            - [x] Already done
            """
        let next = try TaskBodyEdits.toggle(bodyMarkdown: body, blockIndex: 1, itemIndex: 0)
        XCTAssertTrue(next.contains("- [x] Ship PR19"))
        XCTAssertTrue(next.contains("- [x] Already done"))

        let back = try TaskBodyEdits.toggle(bodyMarkdown: next, blockIndex: 1, itemIndex: 0)
        XCTAssertTrue(back.contains("- [ ] Ship PR19"))
    }

    func testToggleRejectsNonTask() {
        XCTAssertThrowsError(
            try TaskBodyEdits.toggle(bodyMarkdown: "Just a paragraph", blockIndex: 0, itemIndex: 0)
        ) { error in
            XCTAssertEqual(error as? TaskBodyEditError, .notATask)
        }
    }
}
