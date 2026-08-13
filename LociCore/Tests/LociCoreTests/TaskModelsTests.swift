import XCTest
@testable import LociCore

final class TaskModelsTests: XCTestCase {
    func testMakeIDAndAggregation() {
        let id = ObjectID()
        let open = IndexedTask(
            objectID: id,
            objectTitle: "Page",
            objectTypeID: .page,
            relativePath: "objects/page/a.md",
            blockIndex: 0,
            itemIndex: 0,
            text: "Ship PR19",
            isCompleted: false
        )
        let done = IndexedTask(
            objectID: id,
            objectTitle: "Page",
            objectTypeID: .page,
            relativePath: "objects/page/a.md",
            blockIndex: 0,
            itemIndex: 1,
            text: "Done",
            isCompleted: true
        )
        let dailyOpen = IndexedTask(
            objectID: ObjectID.daily(for: Date()),
            objectTitle: "2026-08-13",
            objectTypeID: .daily,
            relativePath: DailyNoteIdentity.relativePath(for: Date()),
            blockIndex: 1,
            itemIndex: 0,
            text: "Inbox",
            isCompleted: false
        )

        XCTAssertEqual(
            open.id,
            IndexedTask.makeID(objectID: id, blockIndex: 0, itemIndex: 0)
        )
        XCTAssertEqual(TaskAggregation.open([open, done]).map(\.text), ["Ship PR19"])
        let dayTasks = TaskAggregation.inDailyNote([open, dailyOpen], on: Date())
        XCTAssertEqual(dayTasks.map(\.text), ["Inbox"])
        let sorted = TaskAggregation.sorted([done, open])
        XCTAssertEqual(sorted.map(\.isCompleted), [false, true])
    }
}
