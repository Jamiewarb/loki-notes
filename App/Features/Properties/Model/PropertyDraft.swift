import Foundation
import LociCore

/// Draft state for adding or editing a `PropertyDef` on a type.
public struct PropertyDraft: Hashable, Sendable, Equatable {
    public var id: String
    public var name: String
    public var kind: PropertyKind
    public var optionsText: String
    public var required: Bool

    public init(
        id: String = "",
        name: String = "",
        kind: PropertyKind = .text,
        optionsText: String = "",
        required: Bool = false
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.optionsText = optionsText
        self.required = required
    }

    public init(def: PropertyDef) {
        self.id = def.id
        self.name = def.name
        self.kind = def.kind
        self.optionsText = def.options.joined(separator: ", ")
        self.required = def.required
    }

    /// Build a `PropertyDef` (resolves id from name when blank).
    public func makeDef() throws -> PropertyDef {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw LociError.invalidPropertyID("(empty name)")
        }
        let resolvedID = try PropertyKey.resolve(
            explicit: id.isEmpty ? nil : id,
            fromName: trimmedName
        )
        let options = optionsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return PropertyDef(
            id: resolvedID,
            name: trimmedName,
            kind: kind,
            options: options,
            required: required
        )
    }
}

/// Draft string map for editing object property values in the inspector.
public struct PropertyValueDraft: Hashable, Sendable, Equatable {
    public var fields: [String: String]

    public init(fields: [String: String] = [:]) {
        self.fields = fields
    }

    public init(defs: [PropertyDef], values: [String: PropertyValue]) {
        var map: [String: String] = [:]
        for def in defs {
            if let value = values[def.id] {
                map[def.id] = PropertyValueFormatting.draftString(value)
            } else {
                map[def.id] = ""
            }
        }
        self.fields = map
    }

    public func value(for def: PropertyDef) -> PropertyValue {
        let draft = fields[def.id] ?? ""
        if def.kind == .checkbox {
            // Toggle UI stores "true"/"false"; empty → false.
            return PropertyValueFormatting.coerce(draft: draft.isEmpty ? "false" : draft, kind: .checkbox)
        }
        return PropertyValueFormatting.coerce(draft: draft, kind: def.kind)
    }

    public func apply(to values: inout [String: PropertyValue], defs: [PropertyDef]) {
        for def in defs {
            let next = value(for: def)
            if case .null = next {
                values.removeValue(forKey: def.id)
            } else {
                values[def.id] = next
            }
        }
    }
}
