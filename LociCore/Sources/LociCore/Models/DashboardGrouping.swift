import Foundation

/// One derived dashboard section. Keys are display labels; objects stay in
/// the incoming (QuerySort) order.
public struct DashboardSection: Hashable, Sendable, Equatable {
    public var key: String
    public var objects: [LociObjectMeta]

    public init(key: String, objects: [LociObjectMeta]) {
        self.key = key
        self.objects = objects
    }
}

/// Pure group-by for type dashboards (PR41). Never persists sections to markdown.
///
/// - `groupBy == nil` → one section `"All"`
/// - `groupBy == "tag"` → first/primary tag, or `"Untagged"`
/// - `groupBy == propertyId` → `PropertyValueFormatting.displayString`, or `"Empty"`
public enum DashboardGrouping: Sendable {
    public static let allKey = "All"
    public static let untaggedKey = "Untagged"
    public static let emptyKey = "Empty"
    public static let tagGroupBy = "tag"

    /// Select / text properties are the v1 group-by targets (plus `"tag"`).
    public static func groupableProperties(_ defs: [PropertyDef]) -> [PropertyDef] {
        defs.filter { $0.kind == .select || $0.kind == .text }
    }

    public static func sections(
        objects: [LociObjectMeta],
        groupBy: String?,
        properties: [PropertyDef] = []
    ) -> [DashboardSection] {
        _ = properties
        let trimmed = groupBy?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else {
            return [DashboardSection(key: allKey, objects: objects)]
        }

        var buckets: [String: [LociObjectMeta]] = [:]
        if trimmed == tagGroupBy {
            for object in objects {
                buckets[tagKey(object), default: []].append(object)
            }
        } else {
            for object in objects {
                buckets[propertyKey(object, propertyID: trimmed), default: []].append(object)
            }
        }

        let keys = buckets.keys.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
        return keys.map { DashboardSection(key: $0, objects: buckets[$0] ?? []) }
    }

    private static func tagKey(_ object: LociObjectMeta) -> String {
        guard let raw = object.tags.first(where: { !TagNormalization.normalize($0).isEmpty })
        else {
            return untaggedKey
        }
        return TagNormalization.display(raw)
    }

    private static func propertyKey(_ object: LociObjectMeta, propertyID: String) -> String {
        guard let value = object.properties[propertyID] else { return emptyKey }
        let shown = PropertyValueFormatting.displayString(value)
        return shown.isEmpty ? emptyKey : shown
    }
}
