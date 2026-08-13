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

    func testMediaPickerProofRelativeMarkdown() {
        let attachment = MediaAttachment(
            relativePath: "media/images/picked.png",
            kind: .image,
            fileName: "picked.png",
            byteCount: 8
        )
        let body = MediaInserter.appendImage(
            to: "Picker note",
            alt: "picked",
            attachment: attachment,
            fromObjectRelativePath: "objects/page/picker.md"
        )
        let proof = MediaPickerProof.evaluate(
            attachment: attachment,
            noteBody: body,
            indexInsideVault: false,
            attachedViaFileURL: true
        )
        XCTAssertTrue(proof.photosPickerWired)
        XCTAssertTrue(proof.dragDropWired)
        XCTAssertTrue(proof.attachedViaFileURL)
        XCTAssertFalse(proof.indexInsideVault)
        XCTAssertTrue(proof.markdownRelativePathStartsWithMedia)
        XCTAssertFalse(proof.noteBodyHasAbsolutePath)
        XCTAssertEqual(
            MediaPickerProof.collapseDotDot("../../media/images/picked.png"),
            "media/images/picked.png"
        )
        XCTAssertTrue(MediaPickerNotes.photosUIStaysInApp)
        XCTAssertTrue(MediaPickerNotes.persistVaultRelativeOnly)
    }

    func testMediaPickerProofRejectsAbsolutePaths() {
        let attachment = MediaAttachment(
            relativePath: "media/images/x.png",
            kind: .image,
            fileName: "x.png",
            byteCount: 1
        )
        let bad = "Dropped ![x](/tmp/absolute.png) must not persist."
        let proof = MediaPickerProof.evaluate(
            attachment: attachment,
            noteBody: bad,
            indexInsideVault: false,
            attachedViaFileURL: true
        )
        XCTAssertTrue(proof.noteBodyHasAbsolutePath)
        XCTAssertFalse(proof.markdownRelativePathStartsWithMedia)
        XCTAssertTrue(MediaPickerProof.isAbsoluteFilesystemPath("/Users/me/photo.png"))
        XCTAssertTrue(MediaPickerProof.isAbsoluteFilesystemPath("file:///tmp/a.png"))
        XCTAssertFalse(MediaPickerProof.isAbsoluteFilesystemPath("../../media/images/a.png"))
    }
}
