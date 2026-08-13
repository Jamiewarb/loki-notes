import LociCore
import XCTest

final class DashboardGroupingTests: XCTestCase {
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

    func testNilGroupByIsSingleAllSection() {
        let objects = [
            book(title: "Deep Work", properties: ["status": .select("Reading")]),
            book(title: "Range", properties: ["status": .select("Reading")]),
        ]
        let sections = DashboardGrouping.sections(objects: objects, groupBy: nil)
        XCTAssertEqual(sections.map(\.key), [DashboardGrouping.allKey])
        XCTAssertEqual(sections.first?.objects.map(\.title), ["Deep Work", "Range"])
    }

    func testGroupByTagUsesPrimaryTagOrUntagged() {
        let objects = [
            book(title: "Deep Work", tags: ["focus"]),
            book(title: "Untitled"),
            book(title: "Range", tags: ["focus", "general"]),
        ]
        let sections = DashboardGrouping.sections(objects: objects, groupBy: "tag")
        XCTAssertEqual(sections.map(\.key), ["#focus", DashboardGrouping.untaggedKey])
        XCTAssertEqual(sections[0].objects.map(\.title), ["Deep Work", "Range"])
        XCTAssertEqual(sections[1].objects.map(\.title), ["Untitled"])
    }

    func testGroupByPropertyUsesDisplayStringOrEmpty() {
        let objects = [
            book(title: "Atomic Habits", properties: ["status": .select("Done")]),
            book(title: "Deep Work", properties: ["status": .select("Reading")]),
            book(title: "Notes"),
        ]
        let sections = DashboardGrouping.sections(
            objects: objects,
            groupBy: "status",
            properties: [
                PropertyDef(
                    id: "status",
                    name: "Status",
                    kind: .select,
                    options: ["To Read", "Reading", "Done"]
                )
            ]
        )
        XCTAssertEqual(
            sections.map(\.key),
            ["Done", DashboardGrouping.emptyKey, "Reading"]
        )
        XCTAssertEqual(sections[0].objects.map(\.title), ["Atomic Habits"])
        XCTAssertEqual(sections[2].objects.map(\.title), ["Deep Work"])
    }

    func testSectionKeysAreSortedStablyAndPreserveObjectOrder() {
        let objects = [
            book(title: "Zebra", properties: ["status": .select("Reading")]),
            book(title: "Alpha", properties: ["status": .select("Reading")]),
            book(title: "Middle", properties: ["status": .select("Done")]),
        ]
        let sections = DashboardGrouping.sections(objects: objects, groupBy: "status")
        XCTAssertEqual(sections.map(\.key), ["Done", "Reading"])
        XCTAssertEqual(sections[1].objects.map(\.title), ["Zebra", "Alpha"])
    }

    func testGroupablePropertiesAreSelectOrText() {
        let defs = [
            PropertyDef(id: "status", name: "Status", kind: .select),
            PropertyDef(id: "subtitle", name: "Subtitle", kind: .text),
            PropertyDef(id: "pages", name: "Pages", kind: .number),
            PropertyDef(id: "author", name: "Author", kind: .objectSelect),
        ]
        XCTAssertEqual(
            DashboardGrouping.groupableProperties(defs).map(\.id),
            ["status", "subtitle"]
        )
    }

    func testPropertySortOrdersByDisplayString() {
        let objects = [
            book(title: "Deep Work", properties: ["status": .select("Reading")]),
            book(title: "Atomic Habits", properties: ["status": .select("Done")]),
            book(title: "Range", properties: ["status": .select("To Read")]),
        ]
        let sorted = DashboardSort.applyPropertySort(objects, sortKey: "status")
        XCTAssertEqual(sorted.map(\.title), ["Atomic Habits", "Deep Work", "Range"])
        XCTAssertEqual(
            DashboardSort.applyPropertySort(objects, sortKey: "titleAsc").map(\.title),
            objects.map(\.title)
        )
    }
}

final class DashboardSortTests: XCTestCase {
    func testMapsTitleUpdatedCreatedTokens() {
        XCTAssertEqual(DashboardSort.querySort(from: nil), .titleAsc)
        XCTAssertEqual(DashboardSort.querySort(from: "title"), .titleAsc)
        XCTAssertEqual(DashboardSort.querySort(from: "titleAsc"), .titleAsc)
        XCTAssertEqual(DashboardSort.querySort(from: "titleDesc"), .titleDesc)
        XCTAssertEqual(DashboardSort.querySort(from: "updated"), .updatedDesc)
        XCTAssertEqual(DashboardSort.querySort(from: "updatedDesc"), .updatedDesc)
        XCTAssertEqual(DashboardSort.querySort(from: "updatedAsc"), .updatedAsc)
        XCTAssertEqual(DashboardSort.querySort(from: "created"), .createdDesc)
        XCTAssertEqual(DashboardSort.querySort(from: "createdDesc"), .createdDesc)
        XCTAssertEqual(DashboardSort.querySort(from: "createdAsc"), .createdAsc)
    }

    func testPropertyIdFallsBackToTitleAsc() {
        XCTAssertEqual(DashboardSort.querySort(from: "status"), .titleAsc)
        XCTAssertFalse(DashboardSort.isBuiltIn("status"))
        XCTAssertTrue(DashboardSort.isBuiltIn("updated"))
        XCTAssertTrue(DashboardSort.isBuiltIn(nil))
    }
}

final class DashboardQueryTests: XCTestCase {
    func testDefinitionEncodesTypeTagsPropertyEqualsAndSort() {
        let definition = DashboardQuery.definition(
            typeID: ObjectTypeID("book"),
            tags: ["#Focus"],
            filterKey: "status",
            filterText: "Reading",
            sort: .titleAsc
        )
        XCTAssertEqual(definition.typeID, ObjectTypeID("book"))
        XCTAssertEqual(definition.tags, ["focus"])
        XCTAssertEqual(definition.properties, [.equals("status", text: "Reading")])
        XCTAssertEqual(definition.sort, .titleAsc)
    }

    func testEmptyFilterTextOmitsPropertyPredicate() {
        let definition = DashboardQuery.definition(
            typeID: ObjectTypeID("book"),
            filterKey: "status",
            filterText: "  ",
            sort: .updatedDesc
        )
        XCTAssertTrue(definition.properties.isEmpty)
        XCTAssertEqual(definition.sort, .updatedDesc)
    }

    func testCollectionMembershipPreservesIncomingOrder() {
        let a = LociObjectMeta(
            id: ObjectID(),
            typeID: ObjectTypeID("book"),
            title: "A",
            relativePath: "objects/book/a.md"
        )
        let b = LociObjectMeta(
            id: ObjectID(),
            typeID: ObjectTypeID("book"),
            title: "B",
            relativePath: "objects/book/b.md"
        )
        let c = LociObjectMeta(
            id: ObjectID(),
            typeID: ObjectTypeID("book"),
            title: "C",
            relativePath: "objects/book/c.md"
        )
        let filtered = DashboardQuery.applyCollectionMembership(
            [a, b, c],
            memberIDs: [c.id, a.id]
        )
        XCTAssertEqual(filtered.map(\.title), ["A", "C"])
        XCTAssertEqual(
            DashboardQuery.applyCollectionMembership([a, b], memberIDs: nil).map(\.title),
            ["A", "B"]
        )
    }
}
