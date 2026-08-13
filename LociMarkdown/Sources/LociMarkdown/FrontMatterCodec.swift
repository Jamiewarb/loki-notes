import Foundation
import LociCore

/// Encode / decode `FrontMatter` using the hand-rolled SimpleYAML subset.
public enum FrontMatterCodec {
    /// Decode YAML mapping text (without surrounding `---` fences).
    public static func decode(_ yaml: String) throws -> FrontMatter {
        let map = try SimpleYAML.parseMap(yaml)
        guard let idRaw = stringValue(map["id"]) else {
            throw MarkdownError.missingRequiredField("id")
        }
        guard let id = ObjectID(uuidString: idRaw) else {
            throw MarkdownError.invalidObjectID(idRaw)
        }
        guard let typeRaw = stringValue(map["type"]) ?? stringValue(map["typeID"]) else {
            throw MarkdownError.missingRequiredField("type")
        }
        guard let title = stringValue(map["title"]) else {
            throw MarkdownError.missingRequiredField("title")
        }
        let created =
            try dateValue(map["created"], field: "created") ?? Date(timeIntervalSince1970: 0)
        let updated = try dateValue(map["updated"], field: "updated") ?? created

        var tags: [String] = []
        if let tagsValue = map["tags"] {
            switch tagsValue {
            case .array(let items):
                tags = items.compactMap { stringValue($0) }
            case .string(let s):
                tags = [s]
            default:
                throw MarkdownError.invalidFrontMatter("tags must be an array or string")
            }
        }

        var properties: [String: PropertyValue] = [:]
        if let props = map["properties"] {
            guard case .map(let propMap) = props else {
                throw MarkdownError.invalidFrontMatter("properties must be a mapping")
            }
            for (key, value) in propMap {
                properties[key] = PropertyValueYAML.fromYAML(value)
            }
        }

        let template = stringValue(map["template"])

        return FrontMatter(
            id: id,
            typeID: ObjectTypeID(typeRaw),
            title: title,
            created: created,
            updated: updated,
            tags: tags,
            properties: properties,
            template: template
        )
    }

    /// Encode frontmatter YAML (without `---` fences). Keys sorted for stable round-trips.
    public static func encode(_ matter: FrontMatter) -> String {
        var map: [String: SimpleYAML.Value] = [
            "id": .string(matter.id.uuidString.lowercased()),
            "type": .string(matter.typeID.rawValue),
            "title": .string(matter.title),
            "created": .string(FrontMatterDates.format(matter.created)),
            "updated": .string(FrontMatterDates.format(matter.updated)),
        ]
        if !matter.tags.isEmpty {
            map["tags"] = .array(matter.tags.map { .string($0) })
        }
        if !matter.properties.isEmpty {
            var props: [String: SimpleYAML.Value] = [:]
            for (key, value) in matter.properties {
                props[key] = PropertyValueYAML.toYAML(value)
            }
            map["properties"] = .map(props)
        }
        if let template = matter.template {
            map["template"] = .string(template)
        }
        // Prefer document-shape key order: id, type, title, created, updated, tags, properties, template
        let order = ["id", "type", "title", "created", "updated", "tags", "properties", "template"]
        var lines: [String] = []
        for key in order {
            guard let value = map[key] else { continue }
            lines.append(contentsOf: encodeKey(key, value: value))
        }
        return lines.joined(separator: "\n")
    }

    private static func encodeKey(_ key: String, value: SimpleYAML.Value) -> [String] {
        switch value {
        case .map(let nested) where !nested.isEmpty:
            var out = ["\(key):"]
            let body = SimpleYAML.stringify(.map(nested), indent: 2)
            out.append(body)
            return out
        case .array(let items) where !items.isEmpty && !items.allSatisfy(\.isFlowScalar):
            var out = ["\(key):"]
            out.append(SimpleYAML.stringify(.array(items), indent: 2))
            return out
        default:
            return ["\(key): \(SimpleYAML.stringify(value))"]
        }
    }

    private static func stringValue(_ value: SimpleYAML.Value?) -> String? {
        guard let value else { return nil }
        if case .string(let s) = value { return s }
        if case .number(let n) = value {
            if n.rounded() == n { return String(Int(n)) }
            return String(n)
        }
        return nil
    }

    private static func dateValue(_ value: SimpleYAML.Value?, field: String) throws -> Date? {
        guard let value else { return nil }
        guard let s = stringValue(value) else {
            throw MarkdownError.invalidFrontMatter("\(field) must be an ISO-8601 string")
        }
        guard let date = FrontMatterDates.parse(s) else {
            throw MarkdownError.invalidFrontMatter("invalid \(field) date: \(s)")
        }
        return date
    }
}

extension SimpleYAML.Value {
    fileprivate var isFlowScalar: Bool {
        switch self {
        case .null, .bool, .number, .string: return true
        default: return false
        }
    }
}
