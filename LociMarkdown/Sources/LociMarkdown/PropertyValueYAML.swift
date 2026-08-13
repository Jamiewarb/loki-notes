import Foundation
import LociCore

/// Map `PropertyValue` ↔ bare YAML-ish scalars used in frontmatter.
///
/// Choice (PR06): hand-rolled simple frontmatter YAML — no YAML SPM dependency.
/// Properties use **bare** primitives (same comfort path as `PropertyValue` bare JSON):
/// string → `.text`, number → `.number`, bool → `.bool`, null → `.null`,
/// string arrays → `.multiSelect` (or `.objectSelect` when every entry looks like a wiki-link / UUID).
/// Tagged `{kind,value}` maps are also accepted for lossless schema-aligned values.
public enum PropertyValueYAML {
    public static func fromYAML(_ value: SimpleYAML.Value) -> PropertyValue {
        switch value {
        case .null:
            return .null
        case .bool(let b):
            return .bool(b)
        case .number(let n):
            return .number(n)
        case .string(let s):
            if let date = FrontMatterDates.parse(s) {
                return .date(date)
            }
            return .text(s)
        case .array(let items):
            let strings = items.compactMap { item -> String? in
                if case .string(let s) = item { return s }
                return nil
            }
            if strings.count == items.count {
                if !strings.isEmpty, strings.allSatisfy(looksLikeObjectRef) {
                    return .objectSelect(strings.map(stripWikiBrackets))
                }
                return .multiSelect(strings)
            }
            return .text(SimpleYAML.stringify(value))
        case .map(let map):
            if let kind = map["kind"].flatMap({ stringScalar($0) }),
                let tagged = fromTagged(kind: kind, value: map["value"])
            {
                return tagged
            }
            return .text(SimpleYAML.stringify(value))
        }
    }

    public static func toYAML(_ value: PropertyValue) -> SimpleYAML.Value {
        switch value {
        case .null:
            return .null
        case .bool(let b):
            return .bool(b)
        case .number(let n):
            return .number(n)
        case .text(let s):
            return .string(s)
        case .date(let d):
            return .string(FrontMatterDates.format(d))
        case .select(let s):
            // Tagged form — bare strings decode as `.text`; keep select lossless.
            return .map(["kind": .string("select"), "value": .string(s)])
        case .url(let s):
            return .map(["kind": .string("url"), "value": .string(s)])
        case .multiSelect(let items):
            return .array(items.map { .string($0) })
        case .objectSelect(let ids):
            // Prefer wiki-link style when values look like path/slug refs; plain UUID otherwise.
            return .array(
                ids.map { id in
                    if id.hasPrefix("[[") {
                        return .string(id)
                    }
                    if id.contains("/") {
                        return .string("[[\(id)]]")
                    }
                    return .string(id)
                }
            )
        }
    }

    private static func fromTagged(kind: String, value: SimpleYAML.Value?) -> PropertyValue? {
        switch kind {
        case "text":
            guard let s = value.flatMap(stringScalar) else { return .text("") }
            return .text(s)
        case "number":
            guard case .number(let n)? = value else { return nil }
            return .number(n)
        case "bool":
            guard case .bool(let b)? = value else { return nil }
            return .bool(b)
        case "date":
            guard let s = value.flatMap(stringScalar), let d = FrontMatterDates.parse(s) else { return nil }
            return .date(d)
        case "url":
            guard let s = value.flatMap(stringScalar) else { return nil }
            return .url(s)
        case "select":
            guard let s = value.flatMap(stringScalar) else { return nil }
            return .select(s)
        case "multiSelect", "multi-select":
            guard case .array(let items)? = value else { return nil }
            return .multiSelect(items.compactMap(stringScalar))
        case "objectSelect", "object-select":
            guard case .array(let items)? = value else { return nil }
            return .objectSelect(items.compactMap(stringScalar).map(stripWikiBrackets))
        case "null":
            return .null
        default:
            return nil
        }
    }

    private static func stringScalar(_ value: SimpleYAML.Value) -> String? {
        if case .string(let s) = value { return s }
        return nil
    }

    private static func looksLikeObjectRef(_ s: String) -> Bool {
        if s.hasPrefix("[["), s.hasSuffix("]]") { return true }
        if UUID(uuidString: s) != nil { return true }
        return false
    }

    private static func stripWikiBrackets(_ s: String) -> String {
        if s.hasPrefix("[["), s.hasSuffix("]]"), s.count >= 4 {
            return String(s.dropFirst(2).dropLast(2))
        }
        return s
    }
}
