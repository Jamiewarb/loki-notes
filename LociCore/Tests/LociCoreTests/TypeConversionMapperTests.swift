import XCTest
@testable import LociCore

final class TypeConversionMapperTests: XCTestCase {
    func testSuggestMappingExactIDThenName() {
        let source: [PropertyDef] = [
            PropertyDef(id: "status", name: "Status", kind: .select, options: ["A", "B"]),
            PropertyDef(id: "rating", name: "Rating", kind: .number),
            PropertyDef(id: "notes", name: "Notes", kind: .text),
        ]
        let target: [PropertyDef] = [
            PropertyDef(id: "status", name: "Progress", kind: .select, options: ["A", "B"]),
            PropertyDef(id: "score", name: "Rating", kind: .number),
            PropertyDef(id: "summary", name: "Summary", kind: .text),
        ]

        let maps = TypeConversionMapper.suggestMapping(sourceDefs: source, targetDefs: target)
        XCTAssertEqual(maps.count, 3)
        XCTAssertEqual(maps[0].targetPropertyID, "status")
        XCTAssertEqual(maps[1].targetPropertyID, "score")
        XCTAssertNil(maps[2].targetPropertyID)
        XCTAssertEqual(TypeConversionMapper.droppedPropertyIDs(in: maps), ["notes"])
    }

    func testApplyPropertiesCoercesKinds() {
        let mappings = [
            TypeConversionPropertyMap(sourcePropertyID: "rating", targetPropertyID: "score"),
            TypeConversionPropertyMap(sourcePropertyID: "flag", targetPropertyID: "done"),
            TypeConversionPropertyMap(sourcePropertyID: "orphan", targetPropertyID: nil),
        ]
        let targetDefs = [
            PropertyDef(id: "score", name: "Score", kind: .text),
            PropertyDef(id: "done", name: "Done", kind: .checkbox),
        ]
        let source: [String: PropertyValue] = [
            "rating": .number(5),
            "flag": .text("yes"),
            "orphan": .text("gone"),
        ]
        let out = TypeConversionMapper.applyProperties(
            source: source,
            mappings: mappings,
            targetDefs: targetDefs
        )
        XCTAssertEqual(out["score"], .text("5"))
        XCTAssertEqual(out["done"], .bool(true))
        XCTAssertNil(out["orphan"])
        XCTAssertEqual(out.count, 2)
    }

    func testUnmappedRequiredTargets() {
        let defs = [
            PropertyDef(id: "title", name: "Title", kind: .text, required: true),
            PropertyDef(id: "opt", name: "Opt", kind: .text, required: false),
        ]
        let maps = [
            TypeConversionPropertyMap(sourcePropertyID: "a", targetPropertyID: "opt"),
        ]
        XCTAssertEqual(
            TypeConversionMapper.unmappedRequiredTargetIDs(targetDefs: defs, mappings: maps),
            ["title"]
        )
    }
}
