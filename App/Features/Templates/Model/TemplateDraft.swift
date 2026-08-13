import Foundation
import LociCore

/// Draft state for creating or editing an `ObjectTemplate`.
public struct TemplateDraft: Hashable, Sendable, Equatable {
    public var id: String
    public var name: String
    public var slug: String
    public var bodyMarkdown: String
    /// Draft strings keyed by property id (coerced via defs on save).
    public var propertyDrafts: [String: String]
    public var makeDefault: Bool

    public init(
        id: String = "",
        name: String = "",
        slug: String = "",
        bodyMarkdown: String = "",
        propertyDrafts: [String: String] = [:],
        makeDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.slug = slug
        self.bodyMarkdown = bodyMarkdown
        self.propertyDrafts = propertyDrafts
        self.makeDefault = makeDefault
    }

    public init(template: ObjectTemplate, defs: [PropertyDef], isDefault: Bool) {
        self.id = template.id
        self.name = template.name
        self.slug = ""
        self.bodyMarkdown = template.bodyMarkdown
        var drafts: [String: String] = [:]
        for def in defs {
            if let value = template.defaultProperties[def.id] {
                drafts[def.id] = PropertyValueFormatting.draftString(value)
            } else {
                drafts[def.id] = ""
            }
        }
        // Include any extra keys not in defs.
        for (key, value) in template.defaultProperties where drafts[key] == nil {
            drafts[key] = PropertyValueFormatting.draftString(value)
        }
        self.propertyDrafts = drafts
        self.makeDefault = isDefault
    }

    public func makeDefaultProperties(defs: [PropertyDef]) -> [String: PropertyValue] {
        var result: [String: PropertyValue] = [:]
        for def in defs {
            let draft = propertyDrafts[def.id] ?? ""
            let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let value: PropertyValue
            if def.kind == .checkbox {
                value = PropertyValueFormatting.coerce(draft: trimmed, kind: .checkbox)
            } else {
                value = PropertyValueFormatting.coerce(draft: trimmed, kind: def.kind)
            }
            if case .null = value { continue }
            result[def.id] = value
        }
        return result
    }
}
