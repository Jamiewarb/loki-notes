import Foundation

/// Next frontmatter `properties` / `tags` after a kanban card move (PR42).
///
/// Pure: no I/O and **no markdown body**. Callers persist via `ObjectServing.save`
/// of the same body plus this frontmatter. Layout is never written into notes.
public struct KanbanMoveResult: Hashable, Sendable, Equatable {
    public var properties: [String: PropertyValue]
    public var tags: [String]

    public init(properties: [String: PropertyValue], tags: [String]) {
        self.properties = properties
        self.tags = tags
    }
}

/// Board columns + card-move helper. Columns are derived from
/// `DashboardGrouping.sections` (select option order / observed tags).
public enum KanbanMove: Sendable {
    public static let ungroupedCaption =
        "Group by a select property or tag to use the board."

    /// Destination frontmatter for `groupBy` + column key.
    public static func next(
        meta: LociObjectMeta,
        groupBy: String?,
        destinationKey: String,
        properties: [PropertyDef] = []
    ) -> KanbanMoveResult {
        let trimmed = groupBy?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let dest = destinationKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return KanbanMoveResult(properties: meta.properties, tags: meta.tags)
        }
        if trimmed == DashboardGrouping.tagGroupBy {
            return KanbanMoveResult(
                properties: meta.properties,
                tags: movedTags(existing: meta.tags, destinationKey: dest)
            )
        }
        return KanbanMoveResult(
            properties: movedProperties(
                existing: meta.properties,
                propertyID: trimmed,
                destinationKey: dest,
                defs: properties
            ),
            tags: meta.tags
        )
    }

    /// Columns from grouping: select options (then Empty if needed), tags + Untagged,
    /// or a single All column when `groupBy` is nil.
    public static func columns(
        objects: [LociObjectMeta],
        groupBy: String?,
        properties: [PropertyDef] = []
    ) -> [DashboardSection] {
        let grouped = DashboardGrouping.sections(
            objects: objects,
            groupBy: groupBy,
            properties: properties
        )
        let trimmed = groupBy?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return grouped }

        let byKey: [String: [LociObjectMeta]] = Dictionary(
            uniqueKeysWithValues: grouped.map { ($0.key, $0.objects) }
        )

        if trimmed == DashboardGrouping.tagGroupBy {
            var keys = grouped.map(\.key).filter { $0 != DashboardGrouping.untaggedKey }
            keys.append(DashboardGrouping.untaggedKey)
            return keys.map { DashboardSection(key: $0, objects: byKey[$0] ?? []) }
        }

        if let def = properties.first(where: { $0.id == trimmed }),
            def.kind == .select,
            !def.options.isEmpty
        {
            var keys = def.options
            let extras = grouped.map(\.key).filter { key in
                key != DashboardGrouping.emptyKey && !keys.contains(key)
            }
            keys.append(contentsOf: extras)
            if byKey[DashboardGrouping.emptyKey] != nil {
                keys.append(DashboardGrouping.emptyKey)
            }
            return keys.map { DashboardSection(key: $0, objects: byKey[$0] ?? []) }
        }

        return grouped
    }

    /// True when `groupBy` is unset — board is a single All column plus caption.
    public static func isUngrouped(_ groupBy: String?) -> Bool {
        let trimmed = groupBy?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty
    }

    private static func movedTags(existing: [String], destinationKey: String) -> [String] {
        let previous = existing.first { !TagNormalization.normalize($0).isEmpty }
        var next = existing
        if let previous {
            let prevNorm = TagNormalization.normalize(previous)
            next.removeAll { TagNormalization.normalize($0) == prevNorm }
        }
        if destinationKey.isEmpty
            || destinationKey.caseInsensitiveCompare(DashboardGrouping.untaggedKey)
                == .orderedSame
        {
            return TagNormalization.uniquing(next)
        }
        let destNorm = TagNormalization.normalize(destinationKey)
        guard !destNorm.isEmpty else { return TagNormalization.uniquing(next) }
        next.removeAll { TagNormalization.normalize($0) == destNorm }
        return TagNormalization.uniquing([destNorm] + next)
    }

    private static func movedProperties(
        existing: [String: PropertyValue],
        propertyID: String,
        destinationKey: String,
        defs: [PropertyDef]
    ) -> [String: PropertyValue] {
        var next = existing
        if destinationKey.isEmpty
            || destinationKey.caseInsensitiveCompare(DashboardGrouping.emptyKey) == .orderedSame
        {
            next.removeValue(forKey: propertyID)
            return next
        }
        if let def = defs.first(where: { $0.id == propertyID }) {
            next[propertyID] = PropertyValueFormatting.coerce(draft: destinationKey, kind: def.kind)
        } else {
            next[propertyID] = .select(destinationKey)
        }
        return next
    }
}
