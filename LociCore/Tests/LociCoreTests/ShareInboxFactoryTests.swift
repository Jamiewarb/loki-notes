import LociCore
import XCTest

final class ShareInboxFactoryTests: XCTestCase {
    func testTextOnlyAppendsLine() {
        let item = ShareInboxFactory.inboxItem(text: "  Hello from share  ", url: nil)
        XCTAssertEqual(item.kind, .appendToToday)
        XCTAssertEqual(item.text, "Hello from share")
        XCTAssertEqual(item.source, .share)
        XCTAssertNil(item.sourceURL)
        XCTAssertNil(item.typeID)
        let path = CaptureInbox.relativePath(forID: item.id)
        XCTAssertTrue(ShareWidgetNotes.isInboxNotIndex(path))
        XCTAssertFalse(path.contains("index"))
        XCTAssertFalse(path.contains("sqlite"))
    }

    func testURLAndTitleCreatesPage() {
        let item = ShareInboxFactory.inboxItem(
            text: "Article Title",
            url: "https://example.com/a"
        )
        XCTAssertEqual(item.kind, .createObject)
        XCTAssertEqual(item.typeID, .page)
        XCTAssertEqual(item.title, "Article Title")
        XCTAssertEqual(item.text, "Article Title")
        XCTAssertEqual(item.source, .share)
        XCTAssertEqual(item.sourceURL, "https://example.com/a")
        let path = CaptureInbox.relativePath(forID: item.id)
        XCTAssertTrue(path.hasPrefix(".loci/inbox/"))
        XCTAssertTrue(path.hasSuffix(".json"))
        XCTAssertFalse(path.contains("index.sqlite"))
    }

    func testURLOnlyCreatesPage() {
        let item = ShareInboxFactory.inboxItem(text: nil, url: "https://loci.app/docs")
        XCTAssertEqual(item.kind, .createObject)
        XCTAssertEqual(item.typeID, .page)
        XCTAssertEqual(item.sourceURL, "https://loci.app/docs")
        XCTAssertEqual(item.title, "Shared link")
    }

    func testPlainTextURLTreatedAsURLShare() {
        let item = ShareInboxFactory.inboxItem(text: "https://example.com/only", url: nil)
        XCTAssertEqual(item.kind, .createObject)
        XCTAssertEqual(item.sourceURL, "https://example.com/only")
        XCTAssertTrue(ShareInboxFactory.looksLikeWebURL("https://example.com/only"))
        XCTAssertFalse(ShareInboxFactory.looksLikeWebURL("not a url"))
        XCTAssertFalse(ShareInboxFactory.looksLikeWebURL("https://example.com/a and more"))
    }

    func testWidgetSourceOverride() {
        let item = ShareInboxFactory.inboxItem(text: "From widget", url: nil, source: .widget)
        XCTAssertEqual(item.kind, .appendToToday)
        XCTAssertEqual(item.source, .widget)
    }

    func testInboxPathIsNeverIndex() {
        XCTAssertEqual(CaptureInbox.directory, ".loci/inbox")
        XCTAssertTrue(ShareWidgetNotes.extensionDoesNotTouchIndex)
        XCTAssertFalse(ShareWidgetNotes.inboxDirectory.contains("index"))
        XCTAssertFalse(ShareWidgetNotes.isInboxNotIndex("index.sqlite"))
        XCTAssertFalse(ShareWidgetNotes.isInboxNotIndex(".loci/queries/foo.json"))
        XCTAssertTrue(ShareWidgetNotes.isInboxNotIndex(".loci/inbox/abc.json"))
    }
}

final class LociDeepLinkTests: XCTestCase {
    func testOpenTodayURL() {
        XCTAssertEqual(LociDeepLink.dailyTodayAbsoluteString, "loci://daily/today")
        XCTAssertEqual(LociDeepLink.parse(LociDeepLink.dailyTodayURL), .dailyToday)
        XCTAssertEqual(LociDeepLink.parse("loci://daily/today"), .dailyToday)
        XCTAssertEqual(LociDeepLink.parse("loci:///daily/today"), .dailyToday)
        XCTAssertEqual(LociDeepLink.dailyToday.route, .daily)
    }

    func testCaptureFallbackURL() {
        XCTAssertEqual(LociDeepLink.parse(LociDeepLink.captureURL), .capture)
        XCTAssertEqual(LociDeepLink.capture.route, .capture)
    }

    func testUnknownScheme() {
        XCTAssertEqual(LociDeepLink.parse("https://example.com"), .unknown)
        XCTAssertNil(LociDeepLink.unknown.route)
    }
}

final class ShareWidgetProofTests: XCTestCase {
    func testEvaluateProofFlags() {
        let append = ShareInboxFactory.inboxItem(text: "Note", url: nil)
        let create = ShareInboxFactory.inboxItem(text: "Title", url: "https://example.com")
        let path = CaptureInbox.relativePath(forID: append.id)
        let proof = ShareWidgetProof.evaluate(
            appendItem: append,
            createItem: create,
            inboxPath: path,
            indexInsideVault: false
        )
        XCTAssertTrue(proof.shareExtractsText)
        XCTAssertTrue(proof.widgetOpenToday)
        XCTAssertTrue(proof.inboxNotIndex)
        XCTAssertFalse(proof.indexInsideVault)
        XCTAssertTrue(ShareWidgetNotes.shareExtractsText)
        XCTAssertTrue(ShareWidgetNotes.widgetOpenToday)
    }
}
