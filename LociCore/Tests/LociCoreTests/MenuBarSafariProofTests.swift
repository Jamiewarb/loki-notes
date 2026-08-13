import LociCore
import XCTest

final class MenuBarCaptureFactoryTests: XCTestCase {
    func testInboxItemIsMenuBarAppend() {
        let item = MenuBarCaptureFactory.inboxItem(text: "  Quick from menu  ")
        XCTAssertEqual(item.kind, .appendToToday)
        XCTAssertEqual(item.text, "Quick from menu")
        XCTAssertEqual(item.source, .menuBar)
        XCTAssertNil(item.sourceURL)
        let path = CaptureInbox.relativePath(forID: item.id)
        XCTAssertTrue(MenuBarSafariNotes.isInboxNotIndex(path))
        XCTAssertTrue(path.hasPrefix(".loci/inbox/"))
        XCTAssertFalse(path.contains("index.sqlite"))
    }

    func testRoutePrefersAppendThenInbox() {
        XCTAssertEqual(
            MenuBarCaptureFactory.route(hasCapture: true, hasVault: true),
            .appendToToday
        )
        XCTAssertEqual(
            MenuBarCaptureFactory.route(hasCapture: false, hasVault: true),
            .enqueueInbox
        )
        XCTAssertEqual(
            MenuBarCaptureFactory.route(hasCapture: false, hasVault: false),
            .unavailable
        )
    }

    func testOpenTodayURL() {
        XCTAssertEqual(MenuBarSafariNotes.openTodayURL, "loci://daily/today")
        XCTAssertEqual(LociDeepLink.parse(MenuBarSafariNotes.openTodayURL), .dailyToday)
        XCTAssertEqual(MenuBarSafariNotes.jsPayloadKeys, ["url", "title", "selection"])
        XCTAssertTrue(MenuBarSafariNotes.extensionDoesNotTouchIndex)
    }
}

final class MenuBarSafariProofTests: XCTestCase {
    func testEvaluateProofFlags() {
        let menu = MenuBarCaptureFactory.inboxItem(text: "From menu bar")
        let safari = SafariClipFactory.inboxItem(fromUserInfo: [
            "url": "https://example.com/page",
            "title": "Page",
            "selection": "Quote",
        ])
        let path = CaptureInbox.relativePath(forID: safari.id)
        let proof = MenuBarSafariProof.evaluate(
            menuBarItem: menu,
            safariItem: safari,
            inboxPath: path,
            indexInsideVault: false
        )
        XCTAssertTrue(proof.menuBarWired)
        XCTAssertTrue(proof.safariExtractsPage)
        XCTAssertTrue(proof.inboxNotIndex)
        XCTAssertFalse(proof.indexInsideVault)
        XCTAssertTrue(MenuBarSafariNotes.menuBarWired)
        XCTAssertTrue(MenuBarSafariNotes.safariExtractsPage)
    }
}
