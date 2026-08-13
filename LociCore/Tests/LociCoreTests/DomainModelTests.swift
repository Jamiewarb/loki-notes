import XCTest
import LociCore

final class DomainModelTests: XCTestCase {
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
}
