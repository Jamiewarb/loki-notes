import XCTest
import LociCore
import LociMarkdown

final class TemplateCodecTests: XCTestCase {
    func testEncodeDecodeRoundTrip() throws {
        let original = ObjectTemplate(
            id: "book.default",
            typeID: ObjectTypeID("book"),
            name: "Default Book",
            bodyMarkdown: "## Summary\n\n## Quotes",
            defaultProperties: [
                "status": .select("To Read"),
                "rating": .number(0),
            ]
        )
        let markdown = TemplateCodec.encode(original)
        XCTAssertTrue(markdown.hasPrefix("---"))
        XCTAssertTrue(markdown.contains("id: book.default"))
        XCTAssertTrue(markdown.contains("## Summary"))

        let decoded = try TemplateCodec.decode(markdown)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.typeID, original.typeID)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.bodyMarkdown, original.bodyMarkdown)
        XCTAssertEqual(decoded.defaultProperties["status"], .select("To Read"))
        XCTAssertEqual(decoded.defaultProperties["rating"], .number(0))
    }

    func testTemplateIDHelpers() throws {
        XCTAssertEqual(
            try TemplateID.make(typeID: ObjectTypeID("book"), name: "Default Book", explicitSlug: "default"),
            "book.default"
        )
        XCTAssertTrue(TemplateID.isValid("daily.default"))
        XCTAssertFalse(TemplateID.isValid("nope"))
        XCTAssertFalse(TemplateID.isValid(".default"))
    }
}
