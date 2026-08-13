import XCTest
import LociCore

final class DomainModelTests: XCTestCase {
    func testPropertyValueFormattingAndKeys() {
        XCTAssertEqual(PropertyKey.fromName("Status"), "status")
        XCTAssertEqual(PropertyKey.fromName("Page URL"), "page-url")
        XCTAssertEqual(
            PropertyValueFormatting.coerce(draft: "Reading", kind: .select),
            .select("Reading")
        )
        XCTAssertEqual(PropertyValueFormatting.coerce(draft: "4.5", kind: .number), .number(4.5))
        XCTAssertEqual(PropertyValueFormatting.displayString(.number(5)), "5")
        XCTAssertEqual(PropertyValueFormatting.displayString(.bool(true)), "true")
    }

    func testObjectTypePageBuiltInCodableRoundTrip() throws {
        let original = ObjectType.builtInPage
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ObjectType.self, from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.id, .page)
        XCTAssertTrue(decoded.isBuiltIn)
        XCTAssertFalse(decoded.isDaily)
    }

    func testObjectTypeDailyFlag() {
        let daily = ObjectType.builtInDaily
        XCTAssertEqual(daily.id, .daily)
        XCTAssertTrue(daily.isDaily)
        XCTAssertTrue(daily.isBuiltIn)
    }

    func testPropertyDefAndKindRoundTrip() throws {
        let def = PropertyDef(
            id: "status",
            name: "Status",
            kind: .select,
            options: ["Todo", "Doing", "Done"],
            required: true
        )
        let data = try JSONEncoder().encode(def)
        let decoded = try JSONDecoder().decode(PropertyDef.self, from: data)
        XCTAssertEqual(decoded, def)
        XCTAssertEqual(PropertyKind.multiSelect.rawValue, "multi-select")
        XCTAssertEqual(PropertyKind.objectSelect.rawValue, "object-select")
    }

    func testPropertyValueTaggedRoundTrip() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let values: [PropertyValue] = [
            .text("hello"),
            .number(4.5),
            .bool(true),
            .url("https://example.com"),
            .select("Reading"),
            .multiSelect(["a", "b"]),
            .objectSelect(["8f3c2a1e-0000-0000-0000-000000000001"]),
            .null,
        ]
        for value in values {
            let data = try encoder.encode(value)
            let decoded = try decoder.decode(PropertyValue.self, from: data)
            XCTAssertEqual(decoded, value)
        }
    }

    func testPropertyValueBareJSONPrimitives() throws {
        let text = try JSONDecoder().decode(PropertyValue.self, from: Data("\"note\"".utf8))
        XCTAssertEqual(text, .text("note"))
        let num = try JSONDecoder().decode(PropertyValue.self, from: Data("3".utf8))
        XCTAssertEqual(num, .number(3))
        let flag = try JSONDecoder().decode(PropertyValue.self, from: Data("true".utf8))
        XCTAssertEqual(flag, .bool(true))
        let arr = try JSONDecoder().decode(PropertyValue.self, from: Data("[\"x\",\"y\"]".utf8))
        XCTAssertEqual(arr, .multiSelect(["x", "y"]))
    }

    func testSpaceSettingsPinsRoundTrip() throws {
        var settings = SpaceSettings(name: "Lab", schemaVersion: 1, pins: ["page", "inbox"])
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(SpaceSettings.self, from: data)
        XCTAssertEqual(decoded, settings)
        settings.pins.append("daily")
        XCTAssertEqual(settings.pins.count, 3)
    }

    func testSpaceSettingsDecodesWithoutPinsKey() throws {
        let json = Data(#"{"name":"Legacy","schemaVersion":1}"#.utf8)
        let settings = try JSONDecoder().decode(SpaceSettings.self, from: json)
        XCTAssertEqual(settings.name, "Legacy")
        XCTAssertTrue(settings.pins.isEmpty)
    }

    func testLociObjectMetaWithTagsAndProperties() throws {
        let meta = LociObjectMeta(
            id: ObjectID(),
            typeID: .page,
            title: "Deep Work",
            relativePath: "objects/page/deep-work.md",
            tags: ["focus"],
            properties: ["rating": .number(5), "status": .select("Reading")]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = try encoder.encode(meta)
        let decoded = try decoder.decode(LociObjectMeta.self, from: data)
        XCTAssertEqual(decoded.title, "Deep Work")
        XCTAssertEqual(decoded.tags, ["focus"])
        XCTAssertEqual(decoded.properties["rating"], .number(5))
        XCTAssertEqual(decoded.properties["status"], .select("Reading"))
    }

    func testTypeDashboardConfigDefaults() {
        let dash = TypeDashboardConfig()
        XCTAssertTrue(dash.cardPreviewPropertyIDs.isEmpty)
        XCTAssertNil(dash.defaultSort)
    }

    func testTypeSlugFromName() throws {
        XCTAssertEqual(TypeSlug.fromName("Books"), "books")
        XCTAssertEqual(TypeSlug.fromName("  Deep  Work!! "), "deep-work")
        let resolved = try TypeSlug.resolve(explicit: nil, fromName: "People")
        XCTAssertEqual(resolved, "people")
        XCTAssertThrowsError(try TypeSlug.resolve(explicit: "page", fromName: "X")) { error in
            guard case LociError.invalidTypeSlug("page") = error else {
                return XCTFail("expected invalidTypeSlug, got \(error)")
            }
        }
        XCTAssertTrue(TypeSlug.isProtected(.page))
        XCTAssertTrue(TypeSlug.isProtected(.daily))
        XCTAssertFalse(TypeSlug.isProtected(ObjectTypeID("book")))
    }

    func testObjectTemplateCodableAndTemplateID() throws {
        let template = ObjectTemplate(
            id: "book.default",
            typeID: ObjectTypeID("book"),
            name: "Default Book",
            bodyMarkdown: "## Summary\n",
            defaultProperties: ["status": .select("To Read")]
        )
        let data = try JSONEncoder().encode(template)
        let decoded = try JSONDecoder().decode(ObjectTemplate.self, from: data)
        XCTAssertEqual(decoded, template)
        XCTAssertEqual(
            try TemplateID.make(typeID: ObjectTypeID("daily"), name: "Default", explicitSlug: "default"),
            "daily.default"
        )
        XCTAssertTrue(TemplateID.isValid("book.default"))
        XCTAssertFalse(TemplateID.isValid("invalid"))
    }

    func testOpenedObjectCodable() throws {
        let meta = LociObjectMeta(
            id: ObjectID(),
            typeID: .page,
            title: "Hello",
            relativePath: "objects/page/hello.md"
        )
        let opened = OpenedObject(meta: meta, bodyMarkdown: "Body text")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = try encoder.encode(opened)
        let decoded = try decoder.decode(OpenedObject.self, from: data)
        XCTAssertEqual(decoded.bodyMarkdown, "Body text")
        XCTAssertEqual(decoded.meta.title, "Hello")
    }
}
