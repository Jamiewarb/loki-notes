import LociCore
import XCTest

final class OpenGraphHTMLParserTests: XCTestCase {
    private let source = OpenGraphFixtures.articleURL

    func testParsesOpenGraphTags() {
        let preview = OpenGraphHTMLParser.parse(OpenGraphFixtures.articleHTML, sourceURL: source)
        XCTAssertEqual(preview.title, "Example Article")
        XCTAssertEqual(preview.description, "A clipped paragraph from the page.")
        XCTAssertEqual(preview.imageURL?.absoluteString, "https://example.com/og.png")
        XCTAssertEqual(preview.sourceURL, source)
        XCTAssertTrue(preview.hasContent)
    }

    func testFallsBackToHTMLTitle() {
        let preview = OpenGraphHTMLParser.parse(
            OpenGraphFixtures.titleOnlyHTML,
            sourceURL: source
        )
        XCTAssertEqual(preview.title, "Just a Title")
        XCTAssertNil(preview.description)
        XCTAssertNil(preview.imageURL)
    }

    func testReversedAttributeOrderAndRelativeImage() {
        let preview = OpenGraphHTMLParser.parse(
            OpenGraphFixtures.reversedMetaHTML,
            sourceURL: source
        )
        XCTAssertEqual(preview.title, "Reversed Title")
        XCTAssertEqual(preview.description, "Reversed description.")
        XCTAssertEqual(preview.imageURL?.absoluteString, "https://example.com/images/card.png")
    }

    func testDecodesHTMLEntities() {
        let preview = OpenGraphHTMLParser.parse(
            OpenGraphFixtures.entitiesHTML,
            sourceURL: source
        )
        XCTAssertEqual(preview.title, "Hello & World")
        XCTAssertEqual(preview.description, "A \"quoted\" line")
    }

    func testEmptyHTMLIsPlaceholderNotCrash() {
        let preview = OpenGraphHTMLParser.parse("", sourceURL: source)
        XCTAssertFalse(preview.hasContent)
        XCTAssertEqual(preview.sourceURL, source)
        XCTAssertEqual(LinkPreview.placeholder(sourceURL: source).hasContent, false)
    }

    func testWeblinkURLRejectsNonHTTP() {
        XCTAssertNil(WeblinkURL.parseHTTP("file:///tmp/secret.md"))
        XCTAssertNil(WeblinkURL.parseHTTP("ftp://example.com"))
        XCTAssertEqual(WeblinkURL.parseHTTP("https://example.com/article"), source)
        var meta = LociObjectMeta(
            id: ObjectID(),
            typeID: .weblink,
            title: "Clip",
            relativePath: "objects/weblink/clip.md",
            properties: ["url": .url(OpenGraphFixtures.articleURLString)]
        )
        XCTAssertEqual(WeblinkURL.from(meta), source)
        meta.typeID = .page
        XCTAssertNil(WeblinkURL.from(meta))
    }
}

final class FakeLinkPreviewFetcherTests: XCTestCase {
    func testReturnsFixtureHTMLAndCountsFetches() async throws {
        let fake = FakeLinkPreviewFetcher.withOpenGraphFixtures()
        let html = try await fake.fetchHTML(from: OpenGraphFixtures.articleURL)
        XCTAssertTrue(html.contains("og:title"))
        XCTAssertEqual(fake.fetchCount, 1)
        _ = try await fake.fetchHTML(from: OpenGraphFixtures.weblinkURL)
        XCTAssertEqual(fake.fetchCount, 2)
        fake.resetFetchCount()
        XCTAssertEqual(fake.fetchCount, 0)
    }

    func testMissingURLThrowsWithoutNetwork() async {
        let fake = FakeLinkPreviewFetcher()
        do {
            _ = try await fake.fetchHTML(from: URL(string: "https://example.com/missing")!)
            XCTFail("expected throw")
        } catch let error as LociError {
            guard case .linkPreviewFetchFailed = error else {
                XCTFail("wrong error \(error)")
                return
            }
        } catch {
            XCTFail("unexpected \(error)")
        }
        XCTAssertEqual(fake.fetchCount, 1)
    }
}
