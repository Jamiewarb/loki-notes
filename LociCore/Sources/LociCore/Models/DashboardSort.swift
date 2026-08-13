import Foundation

/// Maps type-dashboard `defaultSort` strings onto `QuerySort` (PR41).
///
/// Built-in keys: `title` / `titleAsc` / `titleDesc`, `updated` / `updatedDesc` /
/// `updatedAsc`, `created` / `createdDesc` / `createdAsc`. A **property id** is
/// not a SQL `QuerySort` case — QueryEngine keeps title/date ORDER BY, and
/// `applyPropertySort` orders by `properties_idx` display strings in memory.
public enum DashboardSort: Sendable {
    /// Resolve a stored dashboard sort key to a QueryEngine sort.
    /// Unknown / property-id keys fall back to title ascending.
    public static func querySort(from raw: String?) -> QuerySort {
        guard let raw else { return .titleAsc }
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "title", "titleasc":
            return .titleAsc
        case "titledesc":
            return .titleDesc
        case "updated", "updateddesc":
            return .updatedDesc
        case "updatedasc":
            return .updatedAsc
        case "created", "createddesc":
            return .createdDesc
        case "createdasc":
            return .createdAsc
        default:
            return .titleAsc
        }
    }

    /// True when `raw` is a title/updated/created token (not a property id).
    public static func isBuiltIn(_ raw: String?) -> Bool {
        guard let raw else { return true }
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "", "title", "titleasc", "titledesc",
            "updated", "updateddesc", "updatedasc",
            "created", "createddesc", "createdasc":
            return true
        default:
            return false
        }
    }

    /// In-memory sort when `defaultSort` is a property id. Built-in keys are a no-op
    /// (QueryEngine already ordered the rows).
    public static func applyPropertySort(
        _ objects: [LociObjectMeta],
        sortKey: String?
    ) -> [LociObjectMeta] {
        guard let sortKey, !isBuiltIn(sortKey) else { return objects }
        let key = sortKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return objects }
        return objects.sorted { a, b in
            let av = display(a.properties[key])
            let bv = display(b.properties[key])
            let cmp = av.localizedCaseInsensitiveCompare(bv)
            if cmp == .orderedSame {
                return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            }
            return cmp == .orderedAscending
        }
    }

    private static func display(_ value: PropertyValue?) -> String {
        guard let value else { return "" }
        return PropertyValueFormatting.displayString(value)
    }
}
