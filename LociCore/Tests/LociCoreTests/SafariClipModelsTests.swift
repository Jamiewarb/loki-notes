import XCTest
import LociCore

final class SafariClipModelsTests: XCTestCase {
    func testInboxItemAppendToToday() {
        let clip = SafariClip(
            pageURL: "https://example.com/a",
            pageTitle: "Title",
            selection: "Selected text",
            destination: .appendToToday
        )
        let item = SafariClipFactory.inboxItem(from: clip)
        XCTAssertEqual(item.kind, .appendToToday)
        XCTAssertEqual(item.text, "Selected text")
        XCTAssertEqual(item.source, .safari)
        XCTAssertEqual(item.sourceURL, "https://example.com/a")
    }

    func testInboxItemWeblinkObject() {
        let clip = SafariClip(
            pageURL: "https://example.com/b",
            pageTitle: "Page Title",
            selection: "Quote me",
            destination: .weblinkObject
        )
        let item = SafariClipFactory.inboxItem(from: clip)
        XCTAssertEqual(item.kind, .createObject)
        XCTAssertEqual(item.typeID, .weblink)
        XCTAssertEqual(item.title, "Page Title")
        XCTAssertEqual(item.source, .safari)
        XCTAssertEqual(item.sourceURL, "https://example.com/b")
        XCTAssertTrue(item.text.contains("> Quote me"))
        XCTAssertTrue(item.text.contains("Source: https://example.com/b"))
    }

    func testWeblinkBodyAndProperties() {
        let body = SafariClipFactory.weblinkBody(
            selection: "Line one\nLine two",
            url: "https://loci.app"
        )
        XCTAssertTrue(body.contains("> Line one"))
        XCTAssertTrue(body.contains("> Line two"))
        XCTAssertTrue(body.contains("Source: https://loci.app"))
        let props = SafariClipFactory.weblinkProperties(
            url: "https://loci.app",
            pageTitle: "Loci"
        )
        XCTAssertEqual(props["url"], .url("https://loci.app"))
        XCTAssertEqual(props["clipped-from"], .text("Loci"))
    }

    func testCaptureSourceSafari() {
        let line = CaptureLineFormatter.line(
            text: "Clip",
            sourceURL: "https://x.test",
            source: .safari
        )
        XCTAssertEqual(line, "- Clip — https://x.test · safari")
    }

    func testBuiltInWeblinkType() {
        let type = ObjectType.builtInWeblink
        XCTAssertEqual(type.id, .weblink)
        XCTAssertTrue(type.isBuiltIn)
        XCTAssertEqual(type.icon, "link")
        XCTAssertTrue(type.properties.contains { $0.id == "url" && $0.kind == .url && $0.required })
        XCTAssertTrue(type.properties.contains { $0.id == "clipped-from" })
        XCTAssertTrue(TypeSlug.isProtected(.weblink))
        XCTAssertThrowsError(try TypeSlug.resolve(explicit: "weblink", fromName: "X"))
    }

    func testSafariClipCodable() throws {
        let clip = SafariClip(
            pageURL: "https://a",
            pageTitle: "T",
            selection: "S",
            destination: .weblinkObject
        )
        let data = try JSONEncoder().encode(clip)
        let decoded = try JSONDecoder().decode(SafariClip.self, from: data)
        XCTAssertEqual(decoded, clip)
    }

    func testUserInfoMapsToAppendClip() {
        let userInfo: [String: Any] = [
            SafariClipFactory.userInfoURLKey: "https://example.com/page",
            SafariClipFactory.userInfoTitleKey: "  Page Title  ",
            SafariClipFactory.userInfoSelectionKey: "Quoted selection",
        ]
        let clip = SafariClipFactory.clip(fromUserInfo: userInfo)
        XCTAssertEqual(clip.pageURL, "https://example.com/page")
        XCTAssertEqual(clip.pageTitle, "Page Title")
        XCTAssertEqual(clip.selection, "Quoted selection")
        XCTAssertEqual(clip.destination, .appendToToday)

        let item = SafariClipFactory.inboxItem(fromUserInfo: userInfo)
        XCTAssertEqual(item.kind, .appendToToday)
        XCTAssertEqual(item.text, "Quoted selection")
        XCTAssertEqual(item.source, .safari)
        XCTAssertEqual(item.sourceURL, "https://example.com/page")
        let path = CaptureInbox.relativePath(forID: item.id)
        XCTAssertTrue(MenuBarSafariNotes.isInboxNotIndex(path))
        XCTAssertFalse(path.contains("index.sqlite"))
    }

    func testUserInfoMapsToWeblinkInboxItem() {
        let userInfo: [String: Any] = [
            "url": "https://example.com/weblink",
            "title": "Weblink Title",
            "selection": "Save this quote",
            "destination": "weblinkObject",
        ]
        let item = SafariClipFactory.inboxItem(fromUserInfo: userInfo)
        XCTAssertEqual(item.kind, .createObject)
        XCTAssertEqual(item.typeID, .weblink)
        XCTAssertEqual(item.title, "Weblink Title")
        XCTAssertEqual(item.source, .safari)
        XCTAssertEqual(item.sourceURL, "https://example.com/weblink")
        XCTAssertTrue(item.text.contains("> Save this quote"))
    }

    func testUserInfoURLObjectAndMissingKeys() {
        let userInfo: [String: Any] = [
            "url": URL(string: "https://loci.app/docs")!,
        ]
        let clip = SafariClipFactory.clip(fromUserInfo: userInfo)
        XCTAssertEqual(clip.pageURL, "https://loci.app/docs")
        XCTAssertNil(clip.pageTitle)
        XCTAssertEqual(clip.selection, "")
        XCTAssertEqual(clip.destination, .appendToToday)
        let item = SafariClipFactory.inboxItem(from: clip)
        XCTAssertEqual(item.text, "https://loci.app/docs")
        XCTAssertNil(SafariClipFactory.clip(fromUserInfo: nil).pageTitle)
        XCTAssertEqual(SafariClipFactory.clip(fromUserInfo: [:]).pageURL, "")
    }
}
