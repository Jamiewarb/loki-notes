import XCTest
import LociCore

final class CaptureModelsTests: XCTestCase {
    func testInboxRelativePath() {
        let path = CaptureInbox.relativePath(forID: "AbC-123")
        XCTAssertEqual(path, ".loci/inbox/abc-123.json")
        XCTAssertTrue(CaptureInbox.isInboxPath(path))
        XCTAssertFalse(CaptureInbox.isInboxPath("daily/2026-08-13.md"))
        XCTAssertFalse(CaptureInbox.isInboxPath(".loci/queries/foo.json"))
    }

    func testSanitizeIDStripsJunk() {
        let safe = CaptureInbox.sanitizeID(" Hello/World!!.json ")
        XCTAssertEqual(safe, "helloworldjson")
    }

    func testLineFormatterBasic() {
        let line = CaptureLineFormatter.line(text: "Hello world", source: .share)
        XCTAssertEqual(line, "- Hello world · share")
    }

    func testLineFormatterURLAndMultiline() {
        let line = CaptureLineFormatter.line(
            text: "Title\nsecond line",
            sourceURL: "https://example.com",
            source: .widget
        )
        XCTAssertEqual(line, "- Title second line — https://example.com · widget")
    }

    func testAppendToBody() {
        XCTAssertEqual(
            CaptureLineFormatter.append(line: "- a", toBody: ""),
            "- a\n"
        )
        XCTAssertEqual(
            CaptureLineFormatter.append(line: "- b", toBody: "hello\n"),
            "hello\n- b\n"
        )
        XCTAssertEqual(
            CaptureLineFormatter.append(line: "- c", toBody: "hello"),
            "hello\n- c\n"
        )
    }

    func testInferredTitle() {
        XCTAssertEqual(CaptureLineFormatter.inferredTitle(from: "  One\nTwo  "), "One")
        XCTAssertEqual(CaptureLineFormatter.inferredTitle(from: "   "), "Captured")
        let long = String(repeating: "x", count: 100)
        let title = CaptureLineFormatter.inferredTitle(from: long)
        XCTAssertEqual(title.count, 78)
        XCTAssertTrue(title.hasSuffix("…"))
    }

    func testCodecRoundTrip() throws {
        let item = CaptureInboxItem.createTyped(
            typeID: .page,
            title: "Shared",
            text: "Body text",
            source: .share,
            sourceURL: "https://loci.app"
        )
        let data = try CaptureInboxCodec.encode(item)
        let decoded = try CaptureInboxCodec.decode(data)
        XCTAssertEqual(decoded.id, item.id)
        XCTAssertEqual(decoded.kind, .createObject)
        XCTAssertEqual(decoded.typeID, .page)
        XCTAssertEqual(decoded.title, "Shared")
        XCTAssertEqual(decoded.text, "Body text")
        XCTAssertEqual(decoded.source, .share)
        XCTAssertEqual(decoded.sourceURL, "https://loci.app")
        XCTAssertEqual(
            CaptureInbox.relativePath(forID: decoded.id),
            ".loci/inbox/\(CaptureInbox.sanitizeID(decoded.id)).json"
        )
    }

    func testAppendConvenience() throws {
        let item = CaptureInboxItem.appendLine("Quick note", source: .menuBar)
        XCTAssertEqual(item.kind, .appendToToday)
        XCTAssertEqual(item.source, .menuBar)
        let data = try CaptureInboxCodec.encode(item)
        let decoded = try CaptureInboxCodec.decode(data)
        XCTAssertEqual(decoded.kind, .appendToToday)
        XCTAssertEqual(decoded.text, "Quick note")
    }
}
