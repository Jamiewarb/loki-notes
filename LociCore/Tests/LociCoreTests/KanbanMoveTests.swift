import LociCore
import XCTest

final class KanbanMoveTests: XCTestCase {
    private let statusDef = PropertyDef(
        id: "status",
        name: "Status",
        kind: .select,
        options: ["To Read", "Reading", "Done"]
    )

    private func book(
        title: String,
        tags: [String] = [],
        properties: [String: PropertyValue] = [:]
    ) -> LociObjectMeta {
        LociObjectMeta(
            id: ObjectID(),
            typeID: ObjectTypeID("book"),
            title: title,
            relativePath: "objects/book/\(title.lowercased().replacingOccurrences(of: " ", with: "-")).md",
            tags: tags,
            properties: properties
        )
    }

    func testSelectStatusReadingToDoneUpdatesProperties() {
        let meta = book(title: "Deep Work", properties: ["status": .select("Reading")])
        let next = KanbanMove.next(
            meta: meta,
            groupBy: "status",
            destinationKey: "Done",
            properties: [statusDef]
        )
        XCTAssertEqual(next.properties["status"], .select("Done"))
        XCTAssertEqual(next.tags, meta.tags)
        XCTAssertEqual(next.properties.count, 1)
    }

    func testTagMoveUpdatesTags() {
        let meta = book(title: "Deep Work", tags: ["focus", "career"])
        let next = KanbanMove.next(
            meta: meta,
            groupBy: DashboardGrouping.tagGroupBy,
            destinationKey: "#work",
            properties: []
        )
        XCTAssertEqual(next.tags, ["work", "career"])
        XCTAssertEqual(next.properties, meta.properties)
    }

    func testMoveToUntaggedRemovesGroupingTag() {
        let meta = book(title: "Notes", tags: ["focus", "inbox"])
        let next = KanbanMove.next(
            meta: meta,
            groupBy: "tag",
            destinationKey: DashboardGrouping.untaggedKey
        )
        XCTAssertEqual(next.tags, ["inbox"])
    }

    func testMoveToEmptyClearsSelect() {
        let meta = book(title: "Notes", properties: ["status": .select("Reading")])
        let next = KanbanMove.next(
            meta: meta,
            groupBy: "status",
            destinationKey: DashboardGrouping.emptyKey,
            properties: [statusDef]
        )
        XCTAssertNil(next.properties["status"])
    }

    func testSelectColumnsUseOptionsOrderThenEmpty() {
        let objects = [
            book(title: "Atomic Habits", properties: ["status": .select("Done")]),
            book(title: "Deep Work", properties: ["status": .select("Reading")]),
            book(title: "Notes"),
        ]
        let columns = KanbanMove.columns(
            objects: objects,
            groupBy: "status",
            properties: [statusDef]
        )
        XCTAssertEqual(
            columns.map(\.key),
            ["To Read", "Reading", "Done", DashboardGrouping.emptyKey]
        )
        XCTAssertTrue(columns[0].objects.isEmpty)
        XCTAssertEqual(columns[1].objects.map(\.title), ["Deep Work"])
        XCTAssertEqual(columns[2].objects.map(\.title), ["Atomic Habits"])
        XCTAssertEqual(columns[3].objects.map(\.title), ["Notes"])
    }

    func testTagColumnsObservedPlusUntagged() {
        let objects = [
            book(title: "Deep Work", tags: ["focus"]),
            book(title: "Untitled"),
            book(title: "Range", tags: ["focus", "general"]),
        ]
        let columns = KanbanMove.columns(objects: objects, groupBy: "tag")
        XCTAssertEqual(columns.map(\.key), ["#focus", DashboardGrouping.untaggedKey])
        XCTAssertEqual(columns[0].objects.map(\.title), ["Deep Work", "Range"])
        XCTAssertEqual(columns[1].objects.map(\.title), ["Untitled"])
    }

    func testNilGroupByIsSingleAllColumn() {
        let objects = [
            book(title: "Deep Work", properties: ["status": .select("Reading")]),
            book(title: "Range", properties: ["status": .select("Reading")]),
        ]
        let columns = KanbanMove.columns(objects: objects, groupBy: nil)
        XCTAssertEqual(columns.map(\.key), [DashboardGrouping.allKey])
        XCTAssertTrue(KanbanMove.isUngrouped(nil))
        XCTAssertEqual(KanbanMove.ungroupedCaption, "Group by a select property or tag to use the board.")
        let next = KanbanMove.next(meta: objects[0], groupBy: nil, destinationKey: "Done")
        XCTAssertEqual(next.properties, objects[0].properties)
    }
}

final class KanbanProofTests: XCTestCase {
    func testEvaluateAllFlags() {
        let yaml = """
            properties:
              status:
                kind: select
                value: Done
            """
        let body = "Focus is a skill.\n"
        let proof = KanbanProof.evaluate(
            columnKeys: ["To Read", "Reading", "Done"],
            expectedColumnKeys: ["To Read", "Reading", "Done"],
            yamlSnippet: yaml,
            expectedYAMLValue: "Done",
            bodyBefore: body,
            bodyAfter: body,
            dailyUnchanged: true,
            indexInsideVault: false
        )
        XCTAssertTrue(proof.boardColumnsFromGroup)
        XCTAssertTrue(proof.moveUpdatesVaultYAML)
        XCTAssertTrue(proof.layoutNotWrittenToMarkdown)
        XCTAssertFalse(proof.indexInsideVault)
        XCTAssertTrue(KanbanNotes.boardColumnsFromGroup)
        XCTAssertTrue(KanbanNotes.moveUpdatesVaultYAML)
        XCTAssertTrue(KanbanNotes.layoutNotWrittenToMarkdown)
        XCTAssertEqual(KanbanNotes.saveProtocol, "ObjectServing.open + save")
    }

    func testFailsWhenLayoutWrittenToMarkdown() {
        let body = "Focus is a skill.\n"
        let layout = "<div data-harness=\"kanban-column\">Reading</div>\n"
        let proof = KanbanProof.evaluate(
            columnKeys: ["Reading"],
            expectedColumnKeys: ["To Read", "Reading", "Done"],
            yamlSnippet: "status: Reading",
            expectedYAMLValue: "Done",
            bodyBefore: body,
            bodyAfter: layout,
            dailyUnchanged: true,
            indexInsideVault: false
        )
        XCTAssertFalse(proof.boardColumnsFromGroup)
        XCTAssertFalse(proof.moveUpdatesVaultYAML)
        XCTAssertFalse(proof.layoutNotWrittenToMarkdown)
        XCTAssertTrue(KanbanProof.markdownLooksLikeBoardLayout(layout))
        XCTAssertFalse(KanbanProof.markdownLooksLikeBoardLayout(body))
    }

    func testFailsWhenIndexInsideVault() {
        let proof = KanbanProof.evaluate(
            columnKeys: ["To Read", "Reading", "Done"],
            expectedColumnKeys: ["To Read", "Reading", "Done"],
            yamlSnippet: "value: Done",
            expectedYAMLValue: "Done",
            bodyBefore: "ok\n",
            bodyAfter: "ok\n",
            dailyUnchanged: false,
            indexInsideVault: true
        )
        XCTAssertTrue(proof.boardColumnsFromGroup)
        XCTAssertTrue(proof.moveUpdatesVaultYAML)
        XCTAssertFalse(proof.layoutNotWrittenToMarkdown)
        XCTAssertTrue(proof.indexInsideVault)
    }
}
