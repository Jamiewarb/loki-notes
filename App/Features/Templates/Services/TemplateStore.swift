import Foundation
import LociCore

/// Thin feature-local facade over `SchemaServing` template APIs (PR14).
///
/// Features must not import other features; composition injects `SchemaServing`.
public struct TemplateStore: Sendable {
    private let schema: any SchemaServing

    public init(schema: any SchemaServing) {
        self.schema = schema
    }

    public func list(typeID: ObjectTypeID) async throws -> [ObjectTemplate] {
        try await schema.listTemplates(typeID: typeID)
    }

    public func load(_ id: String) async throws -> ObjectTemplate {
        try await schema.loadTemplate(id)
    }

    public func save(_ template: ObjectTemplate) async throws -> ObjectTemplate {
        try await schema.saveTemplate(template)
    }

    public func create(
        typeID: ObjectTypeID,
        name: String,
        bodyMarkdown: String,
        defaultProperties: [String: PropertyValue],
        slug: String?,
        makeDefault: Bool
    ) async throws -> ObjectTemplate {
        try await schema.createTemplate(
            typeID: typeID,
            name: name,
            bodyMarkdown: bodyMarkdown,
            defaultProperties: defaultProperties,
            slug: slug,
            makeDefault: makeDefault
        )
    }

    public func delete(_ id: String) async throws {
        try await schema.deleteTemplate(id)
    }

    public func setDefault(typeID: ObjectTypeID, templateID: String?) async throws -> ObjectType {
        try await schema.setDefaultTemplate(typeID: typeID, templateID: templateID)
    }

    public func defaultTemplate(for typeID: ObjectTypeID) async throws -> ObjectTemplate? {
        try await schema.defaultTemplate(for: typeID)
    }
}
