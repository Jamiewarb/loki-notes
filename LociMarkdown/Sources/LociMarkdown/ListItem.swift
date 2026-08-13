import Foundation

/// Bullet, numbered, or task-list item.
public struct ListItem: Hashable, Sendable, Equatable {
    /// `nil` = plain list item; `true`/`false` = GFM task checkbox.
    public var checked: Bool?
    public var inlines: [InlineNode]

    public init(checked: Bool? = nil, inlines: [InlineNode]) {
        self.checked = checked
        self.inlines = inlines
    }

    public var isTask: Bool { checked != nil }
}
