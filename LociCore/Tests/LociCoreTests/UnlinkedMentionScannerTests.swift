import LociCore
import XCTest

final class UnlinkedMentionScannerTests: XCTestCase {
    func testDetectsPlainTitle() {
        XCTAssertTrue(
            UnlinkedMentionScanner.mentions("I read Deep Work yesterday", title: "Deep Work")
        )
        XCTAssertTrue(
            UnlinkedMentionScanner.mentions("I read deep work yesterday", title: "Deep Work")
        )
        XCTAssertEqual(
            UnlinkedMentionScanner.snippet(
                from: "I read Deep Work yesterday",
                title: "Deep Work"
            ).contains("Deep Work"),
            true
        )
    }

    func testIgnoresExistingWikiLink() {
        XCTAssertFalse(
            UnlinkedMentionScanner.mentions("[[Deep Work]] yesterday", title: "Deep Work")
        )
        XCTAssertFalse(
            UnlinkedMentionScanner.mentions(
                "See [[aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1|Deep Work]] yesterday",
                title: "Deep Work"
            )
        )
        XCTAssertFalse(
            UnlinkedMentionScanner.mentions(
                "I read Deep Work yesterday",
                title: "Deep Work",
                existingWikiTargets: ["Deep Work"]
            )
        )
    }

    func testWordBoundaryDoesNotMatchWorking() {
        XCTAssertFalse(UnlinkedMentionScanner.mentions("deep working", title: "Deep Work"))
        XCTAssertFalse(UnlinkedMentionScanner.mentions("Deep Worked late", title: "Deep Work"))
        XCTAssertTrue(UnlinkedMentionScanner.mentions("Deep Work.", title: "Deep Work"))
        XCTAssertTrue(UnlinkedMentionScanner.mentions("Deep Work,", title: "Deep Work"))
    }

    func testSkipsShortTitles() {
        XCTAssertFalse(UnlinkedMentionScanner.mentions("I saw AI today", title: "AI"))
        XCTAssertFalse(UnlinkedMentionScanner.mentions("ok", title: "ok"))
        XCTAssertFalse(UnlinkedMentionScanner.mentions("anything", title: "  "))
        XCTAssertFalse(UnlinkedMentionScanner.isTitleScannable("ab"))
        XCTAssertTrue(UnlinkedMentionScanner.isTitleScannable("abc"))
    }

    func testReplaceFirstOnlyOnExplicitLink() {
        let body = "I read Deep Work yesterday\n"
        XCTAssertTrue(UnlinkedMentionScanner.mentions(body, title: "Deep Work"))
        let wiki = UnlinkedMentionScanner.wikiLinkMarkdown(
            targetID: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1",
            title: "Deep Work"
        )
        XCTAssertEqual(wiki, "[[aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1|Deep Work]]")
        let linked = UnlinkedMentionScanner.replaceFirst(
            in: body,
            title: "Deep Work",
            withWikiLink: wiki
        )
        XCTAssertEqual(linked, "I read [[aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1|Deep Work]] yesterday\n")
        XCTAssertFalse(
            UnlinkedMentionScanner.mentions(linked ?? "", title: "Deep Work")
        )
        XCTAssertEqual(body, "I read Deep Work yesterday\n", "scanner must not mutate the input")
    }

    func testDoesNotRewriteWhenAlreadyLinked() {
        let body = "[[Deep Work]] yesterday"
        XCTAssertNil(
            UnlinkedMentionScanner.replaceFirst(
                in: body,
                title: "Deep Work",
                withWikiLink: "[[id|Deep Work]]"
            )
        )
    }
}
