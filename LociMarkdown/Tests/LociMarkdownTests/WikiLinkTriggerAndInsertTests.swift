import XCTest
@testable import LociMarkdown

final class WikiLinkTriggerAndInsertTests: XCTestCase {
    func testDetectAtMention() {
        let t = WikiLinkTriggerDetector.detect(in: "Hello @pag")
        XCTAssertEqual(t?.kind, .atMention)
        XCTAssertEqual(t?.query, "pag")
    }

    func testDetectOpenWikiBrackets() {
        let t = WikiLinkTriggerDetector.detect(in: "See [[deep")
        XCTAssertEqual(t?.kind, .wikiBrackets)
        XCTAssertEqual(t?.query, "deep")
    }

    func testCompletedWikiLinkIsNotTrigger() {
        let t = WikiLinkTriggerDetector.detect(in: "See [[id|Title]] done")
        XCTAssertNil(t)
    }

    func testWikiBracketsPreferOverAt() {
        let t = WikiLinkTriggerDetector.detect(in: "x @a [[b")
        XCTAssertEqual(t?.kind, .wikiBrackets)
        XCTAssertEqual(t?.query, "b")
    }

    func testInsertWikiLinkReplacesTrigger() throws {
        let session = try EditorSession(bodyMarkdown: "Hello @pag")
        let ok = session.insertWikiLink(
            blockIndex: 0,
            target: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1",
            label: "Page",
            trigger: WikiLinkTriggerDetector.detect(in: "Hello @pag")
        )
        XCTAssertTrue(ok)
        let plain = EditorSession.plainText(of: session.blocks[0])
        XCTAssertEqual(
            plain,
            "Hello [[aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1|Page]]"
        )
        XCTAssertTrue(session.isDirty)
    }

    func testWikiLinkStyleClassifyBroken() {
        let links = [WikiLink(target: "missing", label: "X")]
        let styles = WikiLinkStyle.classify(links: links, resolvedTitlesByTarget: [:])
        XCTAssertEqual(styles.count, 1)
        XCTAssertTrue(styles[0].isBroken)
        XCTAssertEqual(styles[0].styleClass, "wiki-link is-broken")
    }

    func testWikiLinkStyleClassifyResolved() {
        let links = [WikiLink(target: "id-1", label: nil)]
        let styles = WikiLinkStyle.classify(
            links: links,
            resolvedTitlesByTarget: ["id-1": "Title"]
        )
        XCTAssertFalse(styles[0].isBroken)
        XCTAssertEqual(styles[0].displayText, "Title")
    }
}
