import XCTest
import LociMarkdown

final class ImportDocumentProbeTests: XCTestCase {
    func testProbeObsidianFrontMatterAndTitle() {
        let md = """
        ---
        tags: [start]
        aliases: [Home]
        ---

        # Welcome

        See [[Alpha]].
        """
        let result = ImportDocumentProbe.probe(markdown: md, fallbackTitle: "Welcome.md")
        XCTAssertEqual(result.title, "Welcome")
        XCTAssertEqual(result.frontMatter?.tags, ["start"])
        XCTAssertEqual(result.frontMatter?.aliases, ["Home"])
        XCTAssertEqual(result.wikiLinkTargets, ["Alpha"])
    }

    func testProbeCapacitiesIDAndType() {
        let md = """
        ---
        id: 11111111-2222-4333-8444-555555555555
        type: Book
        title: Deep Work
        author: Cal Newport
        ---

        Notes.
        """
        let result = ImportDocumentProbe.probe(markdown: md, fallbackTitle: "x.md")
        XCTAssertEqual(result.title, "Deep Work")
        XCTAssertEqual(result.frontMatter?.id, "11111111-2222-4333-8444-555555555555")
        XCTAssertEqual(result.frontMatter?.type, "Book")
        XCTAssertEqual(result.frontMatter?.properties["author"], "Cal Newport")
    }

    func testObsidianEmbedRewriter() {
        let body = "Pic ![[sketch.png]] and note ![[Welcome]]."
        let out = ObsidianEmbedRewriter.rewriteEmbedsToMarkdownImages(body)
        XCTAssertTrue(out.contains("![sketch](sketch.png)"))
        XCTAssertTrue(out.contains("![[Welcome]]"))
    }

    func testFallbackTitleFromFilename() {
        let result = ImportDocumentProbe.probe(markdown: "Just text.\n", fallbackTitle: "hello.md")
        XCTAssertEqual(result.title, "hello")
    }
}
