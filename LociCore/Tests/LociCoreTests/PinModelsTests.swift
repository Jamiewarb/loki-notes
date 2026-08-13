import XCTest
import LociCore

final class PinModelsTests: XCTestCase {
    func testPinLimitIs24() {
        XCTAssertEqual(PinLimits.maxCount, 24)
    }

    func testMissingRowTitleAndSubtitle() {
        let id = ObjectID()
        let row = PinnedObjectRow.missing(id)
        XCTAssertEqual(row.id, id)
        XCTAssertEqual(row.title, "Missing pin")
        XCTAssertEqual(row.subtitle, "Missing pin")
        XCTAssertTrue(row.isMissing)
        XCTAssertNil(row.typeID)
        XCTAssertNil(row.relativePath)
    }

    func testResolvedRowUsesMeta() {
        let meta = LociObjectMeta(
            id: ObjectID(),
            typeID: .page,
            title: "Inbox",
            relativePath: "objects/page/inbox.md"
        )
        let row = PinnedObjectRow.resolved(meta)
        XCTAssertEqual(row.title, "Inbox")
        XCTAssertEqual(row.subtitle, "page")
        XCTAssertEqual(row.relativePath, "objects/page/inbox.md")
        XCTAssertFalse(row.isMissing)
    }
}
