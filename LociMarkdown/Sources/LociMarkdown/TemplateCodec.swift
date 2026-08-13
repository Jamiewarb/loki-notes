import Foundation
import LociCore

/// Encode / decode template markdown files under `.loci/templates/<id>.md`.
///
/// Shape:
/// ```text
/// ---
/// id: book.default
/// type: book
/// name: Default Book
/// properties:
///   status:
///     kind: select
///     value: To Read
/// ---
///
/// ## Summary
/// ```
public enum TemplateCodec {
    /// Decode a full template markdown document (with optional `---` fences).
    public static func decode(_ markdown: String) throws -> ObjectTemplate {
        let (yaml, body) = splitFrontMatter(markdown)
        guard !yaml.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MarkdownError.invalidFrontMatter("template missing frontmatter")
        }
        let map = try SimpleYAML.parseMap(yaml)
        guard let id = stringValue(map["id"]) else {
            throw MarkdownError.missingRequiredField("id")
        }
        guard TemplateID.isValid(id) else {
            throw MarkdownError.invalidFrontMatter("invalid template id: \(id)")
        }
        guard let typeRaw = stringValue(map["type"]) ?? stringValue(map["typeID"]) else {
            throw MarkdownError.missingRequiredField("type")
        }
        guard let name = stringValue(map["name"]) else {
            throw MarkdownError.missingRequiredField("name")
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

        return ObjectTemplate(
            id: id,
            typeID: ObjectTypeID(typeRaw),
            name: name,
            bodyMarkdown: normalizeBody(body),
            defaultProperties: properties
        )
    }

    /// Encode a template as markdown with YAML frontmatter.
    public static func encode(_ template: ObjectTemplate) -> String {
        var map: [String: SimpleYAML.Value] = [
            "id": .string(template.id),
            "type": .string(template.typeID.rawValue),
            "name": .string(template.name),
        ]
        if !template.defaultProperties.isEmpty {
            var props: [String: SimpleYAML.Value] = [:]
            for (key, value) in template.defaultProperties {
                props[key] = PropertyValueYAML.toYAML(value)
            }
            map["properties"] = .map(props)
        }

        let order = ["id", "type", "name", "properties"]
        var lines: [String] = []
        for key in order {
            guard let value = map[key] else { continue }
            lines.append(contentsOf: encodeKey(key, value: value))
        }
        let yaml = lines.joined(separator: "\n")
        let body = normalizeBody(template.bodyMarkdown)
        if body.isEmpty {
            return "---\n\(yaml)\n---\n"
        }
        return "---\n\(yaml)\n---\n\n\(body)\n"
    }

    // MARK: - Internals

    private static func splitFrontMatter(_ markdown: String) -> (yaml: String, body: String) {
        let trimmed = markdown
        guard trimmed.hasPrefix("---") else {
            return ("", trimmed)
        }
        let afterOpen = trimmed.dropFirst(3)
        // Allow optional newline after opening fence.
        let rest: Substring
        if afterOpen.hasPrefix("\n") {
            rest = afterOpen.dropFirst()
        } else if afterOpen.hasPrefix("\r\n") {
            rest = afterOpen.dropFirst(2)
        } else {
            return ("", trimmed)
        }
        guard let closeRange = rest.range(of: "\n---") else {
            return ("", trimmed)
        }
        let yaml = String(rest[..<closeRange.lowerBound])
        var body = String(rest[closeRange.upperBound...])
        if body.hasPrefix("\n") {
            body = String(body.dropFirst())
        }
        if body.hasPrefix("\r\n") {
            body = String(body.dropFirst(2))
        }
        return (yaml, body)
    }

    private static func normalizeBody(_ body: String) -> String {
        var text = body
        while text.hasPrefix("\n") {
            text = String(text.dropFirst())
        }
        while text.hasSuffix("\n") {
            text = String(text.dropLast())
        }
        return text
    }

    private static func encodeKey(_ key: String, value: SimpleYAML.Value) -> [String] {
        switch value {
        case .map(let nested) where !nested.isEmpty:
            var out = ["\(key):"]
            out.append(SimpleYAML.stringify(.map(nested), indent: 2))
            return out
        case .array(let items) where !items.isEmpty:
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
}
