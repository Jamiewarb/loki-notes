import XCTest
import LociCore

final class MediaModelsTests: XCTestCase {
    func testRelativeURLFromPageObject() {
        let url = MediaPath.relativeURL(
            fromObjectRelativePath: "objects/page/note.md",
            toMediaRelativePath: "media/images/hero.png"
        )
        XCTAssertEqual(url, "../../media/images/hero.png")
    }

    func testRelativeURLFromDaily() {
        let url = MediaPath.relativeURL(
            fromObjectRelativePath: "daily/2026-08-13.md",
            toMediaRelativePath: "media/images/hero.png"
        )
        XCTAssertEqual(url, "../media/images/hero.png")
    }

    func testMarkdownImageSyntax() {
        let md = MediaPath.markdownImage(
            alt: "Hero",
            mediaRelativePath: "media/images/hero.png",
            fromObjectRelativePath: "objects/page/note.md"
        )
        XCTAssertEqual(md, "![Hero](../../media/images/hero.png)")
    }

    func testSanitizeAndKind() {
        XCTAssertEqual(MediaPath.sanitizeFileName("My Photo!!.PNG"), "my-photo.png")
        XCTAssertEqual(MediaPath.kind(forFileName: "a.jpeg"), .image)
        XCTAssertEqual(MediaPath.kind(forFileName: "notes.pdf"), .file)
    }

    func testMediaInserterAppend() {
        let attachment = MediaAttachment(
            relativePath: "media/images/chip.png",
            kind: .image,
            fileName: "chip.png",
            byteCount: 12
        )
        let body = MediaInserter.appendImage(
            to: "Hello",
            alt: "chip",
            attachment: attachment,
            fromObjectRelativePath: "objects/page/hello.md"
        )
        XCTAssertTrue(body.contains("Hello"))
        XCTAssertTrue(body.contains("![chip](../../media/images/chip.png)"))
    }

    func testBuiltInImageType() throws {
        let image = ObjectType.builtInImage
        XCTAssertEqual(image.id, .image)
        XCTAssertTrue(image.isBuiltIn)
        XCTAssertTrue(image.properties.contains { $0.id == "media-path" })
        let data = try JSONEncoder().encode(image)
        let decoded = try JSONDecoder().decode(ObjectType.self, from: data)
        XCTAssertEqual(decoded, image)
        XCTAssertTrue(TypeSlug.isProtected(.image))
        XCTAssertThrowsError(try TypeSlug.resolve(explicit: "image", fromName: "X"))
    }
}
