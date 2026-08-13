import Foundation
import XCTest
import LociCore
@testable import LociMarkdown

final class MarkdownRoundTripTests: XCTestCase {
    func testFixtureRoundTripsStructural() throws {
        let names = [
            "basic-page.md",
            "deep-work.md",
            "full-flavor.md",
            "tasks-lists.md",
            "frontmatter-only.md",
        ]
        for name in names {
            let original = try loadFixture(name)
            let doc = try MarkdownParser().parse(original)
            let serialized = MarkdownSerializer().serialize(doc)
            let again = try MarkdownParser().parse(serialized)
            XCTAssertEqual(again, doc, "structural round-trip failed for \(name)")

            // Double serialize is byte-stable
            let serialized2 = MarkdownSerializer().serialize(again)
            XCTAssertEqual(serialized2, serialized, "serialize instability for \(name)")
        }
    }

    func testDeepWorkFrontMatterFields() throws {
        let doc = try MarkdownParser().parse(loadFixture("deep-work.md"))
        let fm = try XCTUnwrap(doc.frontMatter)
        XCTAssertEqual(fm.id.uuidString.lowercased(), "8f3c2a1e-0000-4000-8000-000000000099")
        XCTAssertEqual(fm.typeID.rawValue, "book")
        XCTAssertEqual(fm.title, "Deep Work")
        XCTAssertEqual(fm.tags, ["focus", "career"])
        XCTAssertEqual(fm.template, "default-book")
        XCTAssertEqual(fm.properties["rating"], .number(5))
        XCTAssertEqual(fm.properties["status"], .select("Reading"))
        XCTAssertEqual(fm.properties["author"], .objectSelect(["people/cal-newport"]))

        let meta = fm.toMeta(relativePath: "objects/book/deep-work.md")
        XCTAssertEqual(meta.title, "Deep Work")
        XCTAssertEqual(meta.relativePath, "objects/book/deep-work.md")
        XCTAssertEqual(meta.properties["status"], .select("Reading"))
    }

    func testFullFlavorBlockInventory() throws {
        let doc = try MarkdownParser().parse(loadFixture("full-flavor.md"))
        var kinds = Set<String>()
        func walk(_ blocks: [BlockNode]) {
            for block in blocks {
                switch block {
                case .paragraph: kinds.insert("paragraph")
                case .heading(let level, _): kinds.insert("heading-\(level)")
                case .bulletList(let items):
                    kinds.insert("bulletList")
                    if items.contains(where: \.isTask) { kinds.insert("task") }
                case .numberedList: kinds.insert("numberedList")
                case .blockQuote(let children):
                    kinds.insert("blockQuote")
                    walk(children)
                case .codeBlock: kinds.insert("codeBlock")
                case .queryEmbed: kinds.insert("queryEmbed")
                case .image: kinds.insert("image")
                case .thematicBreak: kinds.insert("thematicBreak")
                }
            }
        }
        walk(doc.blocks)
        for expected in [
            "paragraph", "heading-1", "heading-2", "heading-3", "heading-4",
            "bulletList", "numberedList", "task", "blockQuote", "codeBlock", "image",
            "thematicBreak",
        ] {
            XCTAssertTrue(kinds.contains(expected), "missing \(expected) in \(kinds)")
        }

        let inlineBlob = MarkdownSerializer().serialize(doc)
        XCTAssertTrue(inlineBlob.contains("[[slug-a]]"))
        XCTAssertTrue(inlineBlob.contains("#tagOne"))
        XCTAssertTrue(inlineBlob.contains("![Hero](../media/images/hero.png)"))
    }

    func testBodyWithoutFrontMatter() throws {
        let md = "## Hi\n\nHello [[x]] and #y\n"
        let doc = try MarkdownParser().parse(md)
        XCTAssertNil(doc.frontMatter)
        XCTAssertEqual(doc.blocks.count, 2)
        let out = MarkdownSerializer().serialize(doc)
        let again = try MarkdownParser().parse(out)
        XCTAssertEqual(again, doc)
    }

    func testProgrammaticDocumentRoundTrip() throws {
        let id = ObjectID(uuidString: "11111111-2222-4333-8444-555555555555")!
        let created = FrontMatterDates.parse("2026-08-13T10:00:00Z")!
        var fm = FrontMatter(
            id: id,
            typeID: .page,
            title: "Programmatic",
            created: created,
            updated: created,
            tags: ["a", "b"],
            properties: [
                "n": .number(2),
                "flag": .bool(false),
                "note": .text("hi"),
                "url": .url("https://loci.app"),
                "pick": .select("A"),
                "labels": .multiSelect(["x", "y"]),
                "refs": .objectSelect(["objects/page/z"]),
                "when": .date(created),
                "empty": .null,
            ]
        )
        fm.template = "page.default"

        let doc = LociDocument(
            frontMatter: fm,
            blocks: [
                .heading(level: 2, inlines: [.text("Title")]),
                .paragraph([
                    .text("See "),
                    .wikiLink(WikiLink(target: "objects/page/z", label: "Z")),
                    .text(" "),
                    .tag("ship"),
                ]),
                .bulletList([
                    ListItem(checked: false, inlines: [.text("todo")]),
                    ListItem(checked: true, inlines: [.text("done")]),
                ]),
                .numberedList(
                    start: 1,
                    items: [ListItem(inlines: [.text("one")]), ListItem(inlines: [.text("two")])]
                ),
                .blockQuote([.paragraph([.text("quoted")])]),
                .codeBlock(language: "json", code: "{\"a\":1}"),
                .image(alt: "pic", url: "../media/images/pic.png", title: nil),
            ]
        )

        let md = MarkdownSerializer().serialize(doc)
        let parsed = try MarkdownParser().parse(md)
        XCTAssertEqual(parsed, doc)
    }

    private func loadFixture(_ name: String) throws -> String {
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: base, withExtension: ext, subdirectory: "Fixtures")
        )
        return try String(contentsOf: url, encoding: .utf8)
    }
}
