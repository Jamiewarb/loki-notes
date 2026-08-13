import Foundation

/// One GFM task-list item projected into the local SQLite index (PR19).
///
/// Vault markdown remains source of truth; this row is disposable and rebuilt on index.
public struct IndexedTask: Hashable, Sendable, Equatable, Identifiable {
    /// Stable within one index pass: `objectID|blockIndex|itemIndex`.
    public var id: String
    public var objectID: ObjectID
    public var objectTitle: String
    public var objectTypeID: ObjectTypeID
    public var relativePath: String
    public var blockIndex: Int
    public var itemIndex: Int
    public var text: String
    public var isCompleted: Bool

    public init(
        objectID: ObjectID,
        objectTitle: String,
        objectTypeID: ObjectTypeID,
        relativePath: String,
        blockIndex: Int,
        itemIndex: Int,
        text: String,
        isCompleted: Bool
    ) {
        self.id = Self.makeID(objectID: objectID, blockIndex: blockIndex, itemIndex: itemIndex)
        self.objectID = objectID
        self.objectTitle = objectTitle
        self.objectTypeID = objectTypeID
        self.relativePath = relativePath
        self.blockIndex = blockIndex
        self.itemIndex = itemIndex
        self.text = text
        self.isCompleted = isCompleted
    }

    public static func makeID(objectID: ObjectID, blockIndex: Int, itemIndex: Int) -> String {
        "\(objectID.uuidString.lowercased())|\(blockIndex)|\(itemIndex)"
    }
}

/// Pure helpers for Today / Open task aggregation (no I/O).
public enum TaskAggregation: Sendable {
    /// Incomplete tasks only.
    public static func open(_ tasks: [IndexedTask]) -> [IndexedTask] {
        tasks.filter { !$0.isCompleted }
    }

    /// Tasks whose source file is the daily note for `day`.
    public static func inDailyNote(
        _ tasks: [IndexedTask],
        on day: Date,
        calendar: Calendar = .current
    ) -> [IndexedTask] {
        let path = DailyNoteIdentity.relativePath(for: day, calendar: calendar)
        return tasks.filter { $0.relativePath == path }
    }

    /// Sort: open first, then by object title, then block/item order.
    public static func sorted(_ tasks: [IndexedTask]) -> [IndexedTask] {
        tasks.sorted { a, b in
            if a.isCompleted != b.isCompleted { return !a.isCompleted && b.isCompleted }
            let titleCmp = a.objectTitle.localizedCaseInsensitiveCompare(b.objectTitle)
            if titleCmp != .orderedSame { return titleCmp == .orderedAscending }
            if a.blockIndex != b.blockIndex { return a.blockIndex < b.blockIndex }
            return a.itemIndex < b.itemIndex
        }
    }
}
