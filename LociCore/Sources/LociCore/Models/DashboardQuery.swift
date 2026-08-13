import Foundation

/// Builds a `QueryDefinition` for a type dashboard list (PR41).
///
/// Type + tags + property equals + sort go to `IndexQuerying.execute`.
/// Archive hiding and collection membership stay post-filters (collections
/// are vault JSON, not SQL). Results are derived — never written to markdown.
public enum DashboardQuery: Sendable {
    /// Assemble the QueryEngine definition for the current dashboard controls.
    public static func definition(
        typeID: ObjectTypeID,
        tags: [String] = [],
        filterKey: String?,
        filterText: String?,
        sort: QuerySort
    ) -> QueryDefinition {
        var properties: [PropertyFilter] = []
        let key = filterKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let text = filterText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !key.isEmpty, !text.isEmpty {
            properties.append(.equals(key, text: text))
        }
        let normalizedTags = tags
            .map { TagNormalization.normalize($0) }
            .filter { !$0.isEmpty }
        return QueryDefinition(
            typeID: typeID,
            tags: normalizedTags,
            properties: properties,
            sort: sort
        )
    }

    /// Keep collection-tab membership as a post-filter on vault `memberIDs`.
    /// Preserves QuerySort / property-sort order (does not re-order by membership).
    public static func applyCollectionMembership(
        _ objects: [LociObjectMeta],
        memberIDs: [ObjectID]?
    ) -> [LociObjectMeta] {
        guard let memberIDs else { return objects }
        let allowed = Set(memberIDs)
        return objects.filter { allowed.contains($0.id) }
    }
}
