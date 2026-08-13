import LociCore
import XCTest

final class LinkPreviewProofTests: XCTestCase {
    func testEvaluateAllFlags() {
        let parsed = OpenGraphHTMLParser.parse(
            OpenGraphFixtures.articleHTML,
            sourceURL: OpenGraphFixtures.articleURL
        )
        let proof = LinkPreviewProof.evaluate(
            parsedTitle: parsed.title,
            expectedTitle: "Example Article",
            cachePath: "/tmp/Application Support/Loci/v1/previews.json",
            vaultRoot: "/tmp/loci-vault",
            fetchCountAfterOpen: 1,
            fetchCountAfterTypingSave: 1,
            indexInsideVault: false
        )
        XCTAssertTrue(proof.parsesOpenGraph)
        XCTAssertTrue(proof.cacheOutsideVault)
        XCTAssertTrue(proof.noFetchOnType)
        XCTAssertFalse(proof.indexInsideVault)
        XCTAssertTrue(LinkPreviewNotes.parsesOpenGraph)
        XCTAssertTrue(LinkPreviewNotes.noFetchOnType)
        XCTAssertTrue(LinkPreviewNotes.linuxUsesFakes)
        XCTAssertEqual(LinkPreviewNotes.maxBytes, 1_048_576)
    }

    func testFailsWhenCacheInsideVault() {
        let proof = LinkPreviewProof.evaluate(
            parsedTitle: "Example Article",
            expectedTitle: "Example Article",
            cachePath: "/tmp/loci-vault/previews.json",
            vaultRoot: "/tmp/loci-vault",
            fetchCountAfterOpen: 1,
            fetchCountAfterTypingSave: 1,
            indexInsideVault: true
        )
        XCTAssertTrue(proof.parsesOpenGraph)
        XCTAssertFalse(proof.cacheOutsideVault)
        XCTAssertTrue(proof.noFetchOnType)
        XCTAssertTrue(proof.indexInsideVault)
        XCTAssertFalse(
            LinkPreviewProof.pathIsOutsideVault(
                "/tmp/loci-vault/objects/weblink/x.md",
                vaultRoot: "/tmp/loci-vault"
            )
        )
    }

    func testFailsWhenFetchOnType() {
        let proof = LinkPreviewProof.evaluate(
            parsedTitle: "Other",
            expectedTitle: "Example Article",
            cachePath: "/tmp/Application Support/Loci/previews.json",
            vaultRoot: "/tmp/loci-vault",
            fetchCountAfterOpen: 1,
            fetchCountAfterTypingSave: 4,
            indexInsideVault: false
        )
        XCTAssertFalse(proof.parsesOpenGraph)
        XCTAssertTrue(proof.cacheOutsideVault)
        XCTAssertFalse(proof.noFetchOnType)
        XCTAssertFalse(proof.indexInsideVault)
    }
}
