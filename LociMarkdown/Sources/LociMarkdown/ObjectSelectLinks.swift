import Foundation
import LociCore

/// Pure extraction of wiki-link rows from object-select property values (PR40).
///
/// Indexing merges these with body `[[wiki-links]]` and dedupes by target.
/// Callers must **not** serialize the result back into markdown — object-select
/// links live in YAML + the disposable `links` table only.
public enum ObjectSelectLinks: Sendable {
    /// One `WikiLink` per object-select id. Label is the property key.
    /// Duplicate targets (case-insensitive, after ObjectID normalize) are dropped.
    public static func wikiLinks(from properties: [String: PropertyValue]) -> [WikiLink] {
        var seen = Set<String>()
        var result: [WikiLink] = []
        for key in properties.keys.sorted() {
            guard case .objectSelect(let ids) = properties[key] else { continue }
            for raw in ids {
                let target = normalize(raw)
                guard !target.isEmpty else { continue }
                let dedupe = target.lowercased()
                guard !seen.contains(dedupe) else { continue }
                seen.insert(dedupe)
                result.append(WikiLink(target: target, label: key))
            }
        }
        return result
    }

    /// Body wiki-links first (keep their labels), then object-select extras.
    public static func merge(
        body: [WikiLink],
        properties: [String: PropertyValue]
    ) -> [WikiLink] {
        var seen = Set<String>()
        var result: [WikiLink] = []
        for link in body {
            let target = normalize(link.target)
            guard !target.isEmpty else { continue }
            let dedupe = target.lowercased()
            guard !seen.contains(dedupe) else { continue }
            seen.insert(dedupe)
            result.append(WikiLink(target: target, label: link.label))
        }
        for extra in wikiLinks(from: properties) {
            let dedupe = extra.target.lowercased()
            guard !seen.contains(dedupe) else { continue }
            seen.insert(dedupe)
            result.append(extra)
        }
        return result
    }

    /// Lowercase UUID / daily key when parseable; otherwise the trimmed token.
    public static func normalize(_ raw: String) -> String {
        ObjectSelectID.persistableString(from: raw)
    }
}
