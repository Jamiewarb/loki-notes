import Foundation
import XCTest
import LociCore
@testable import LociMarkdown

final class FrontMatterCodecTests: XCTestCase {
    func testEncodeDecodeRoundTrip() throws {
        let id = ObjectID(uuidString: "8f3c2a1e-aaaa-4bbb-8ccc-ddddeeeeffff")!
        let created = FrontMatterDates.parse("2026-08-13T09:12:00Z")!
        let updated = FrontMatterDates.parse("2026-08-13T11:40:00Z")!
        let original = FrontMatter(
            id: id,
            typeID: ObjectTypeID("book"),
            title: "Deep Work",
            created: created,
            updated: updated,
            tags: ["focus", "career"],
            properties: [
                "status": .select("Reading"),
                "rating": .number(5),
                "author": .objectSelect(["people/cal-newport"]),
            ],
            template: "default-book"
        )
        let yaml = FrontMatterCodec.encode(original)
        let decoded = try FrontMatterCodec.decode(yaml)
        XCTAssertEqual(decoded, original)
        XCTAssertTrue(yaml.contains("type: book"))
        XCTAssertFalse(yaml.contains("typeID"))
    }

    func testAcceptsTypeIDAlias() throws {
        let yaml = """
            id: 8f3c2a1e-aaaa-4bbb-8ccc-ddddeeeeff01
            typeID: page
            title: Alias
            created: 2026-08-13T09:12:00Z
            updated: 2026-08-13T09:12:00Z
            """
        let fm = try FrontMatterCodec.decode(yaml)
        XCTAssertEqual(fm.typeID, .page)
    }

    func testBarePropertyPrimitives() throws {
        let yaml = """
            id: 8f3c2a1e-aaaa-4bbb-8ccc-ddddeeeeff02
            type: page
            title: Props
            created: 2026-08-13T09:12:00Z
            updated: 2026-08-13T09:12:00Z
            properties:
              note: hello
              n: 4
              ok: true
              labels: [a, b]
              ref: ["[[people/x]]"]
            """
        let fm = try FrontMatterCodec.decode(yaml)
        XCTAssertEqual(fm.properties["note"], .text("hello"))
        XCTAssertEqual(fm.properties["n"], .number(4))
        XCTAssertEqual(fm.properties["ok"], .bool(true))
        XCTAssertEqual(fm.properties["labels"], .multiSelect(["a", "b"]))
        XCTAssertEqual(fm.properties["ref"], .objectSelect(["people/x"]))
    }

    func testMetaBridge() {
        let meta = LociObjectMeta(
            id: ObjectID(),
            typeID: .page,
            title: "X",
            relativePath: "objects/page/x.md",
            tags: ["t"],
            properties: ["n": .number(1)]
        )
        let fm = FrontMatter(meta: meta)
        let back = fm.toMeta(relativePath: meta.relativePath)
        XCTAssertEqual(back.id, meta.id)
        XCTAssertEqual(back.tags, meta.tags)
        XCTAssertEqual(back.properties, meta.properties)
        XCTAssertEqual(back.relativePath, meta.relativePath)
    }

    func testMissingIdThrows() {
        let yaml = """
            type: page
            title: No ID
            created: 2026-08-13T09:12:00Z
            updated: 2026-08-13T09:12:00Z
            """
        XCTAssertThrowsError(try FrontMatterCodec.decode(yaml)) { error in
            XCTAssertEqual(error as? MarkdownError, .missingRequiredField("id"))
        }
    }
}
