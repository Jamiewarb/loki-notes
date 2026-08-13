import XCTest
@testable import LociMarkdown

final class SimpleYAMLTests: XCTestCase {
    func testFlowArrayAndScalars() throws {
        let map = try SimpleYAML.parseMap(
            """
            a: true
            b: 3.5
            c: hello
            d: [x, y]
            e: null
            """
        )
        XCTAssertEqual(map["a"], .bool(true))
        XCTAssertEqual(map["b"], .number(3.5))
        XCTAssertEqual(map["c"], .string("hello"))
        XCTAssertEqual(map["d"], .array([.string("x"), .string("y")]))
        XCTAssertEqual(map["e"], .null)
    }

    func testNestedMapRoundTripStringify() throws {
        let value: SimpleYAML.Value = .map([
            "outer": .map([
                "kind": .string("select"),
                "value": .string("Reading"),
            ]),
            "n": .number(5),
        ])
        let text = SimpleYAML.stringify(value)
        let parsed = try SimpleYAML.parseMap(text)
        XCTAssertEqual(SimpleYAML.Value.map(parsed), value)
    }
}
