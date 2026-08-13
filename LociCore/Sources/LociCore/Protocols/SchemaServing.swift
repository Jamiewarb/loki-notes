import Foundation

/// Per-type schema files + space.json. Implementations live beside Vault (PR05).
/// Prefer `.loci/types/<slug>.json` — never a monolithic schema.json rewrite.
public protocol SchemaServing: Sendable {
    func loadSpaceSettings() async throws -> SpaceSettings
    func saveSpaceSettings(_ settings: SpaceSettings) async throws

    func knownTypeIDs() async throws -> [ObjectTypeID]
    func loadType(_ id: ObjectTypeID) async throws -> ObjectType
    func saveType(_ type: ObjectType) async throws
    func allTypes() async throws -> [ObjectType]

    /// Ensure vault skeleton + seed built-in Page (and space.json if missing).
    func bootstrapSchema(spaceName: String) async throws

    /// Create a custom type on the fly (PR12). Writes `.loci/types/<slug>.json`
    /// and ensures `objects/<slug>/`. Properties may be empty until PR13.
    func createType(
        name: String,
        icon: String,
        color: String,
        slug: String?
    ) async throws -> ObjectType

    /// Rename display name (and optionally icon/color via `saveType`). Id/slug stays stable.
    func renameType(_ id: ObjectTypeID, name: String) async throws -> ObjectType

    /// Delete a custom type. Refuses built-in Page/Daily. Refuses non-empty
    /// `objects/<slug>/` unless `force` (then schema JSON only is removed).
    func deleteType(_ id: ObjectTypeID, force: Bool) async throws

    // MARK: - Properties (PR13)

    /// Replace the full property-def list for a type (merge-friendly single-file write).
    @discardableResult
    func setProperties(_ typeID: ObjectTypeID, properties: [PropertyDef]) async throws -> ObjectType

    /// Insert or replace one property definition by id.
    @discardableResult
    func upsertProperty(_ typeID: ObjectTypeID, def: PropertyDef) async throws -> ObjectType

    /// Remove a property definition by id. No-op id → `propertyNotFound`.
    @discardableResult
    func removeProperty(_ typeID: ObjectTypeID, propertyID: String) async throws -> ObjectType

    // MARK: - Templates (PR14)

    /// All templates for a type (from disk + type.templateIDs reconciliation).
    func listTemplates(typeID: ObjectTypeID) async throws -> [ObjectTemplate]

    /// Load one template by id (`book.default`).
    func loadTemplate(_ id: String) async throws -> ObjectTemplate

    /// Create or replace a template file and register it on the type.
    @discardableResult
    func saveTemplate(_ template: ObjectTemplate) async throws -> ObjectTemplate

    /// Create a new template (generates `<type>.<slug>` id). Optionally star as default.
    @discardableResult
    func createTemplate(
        typeID: ObjectTypeID,
        name: String,
        bodyMarkdown: String,
        defaultProperties: [String: PropertyValue],
        slug: String?,
        makeDefault: Bool
    ) async throws -> ObjectTemplate

    /// Delete template file and unregister from type (clears default if matched).
    func deleteTemplate(_ id: String) async throws

    /// Star (or clear) the default template for a type. Applied on object/daily create.
    @discardableResult
    func setDefaultTemplate(typeID: ObjectTypeID, templateID: String?) async throws -> ObjectType

    /// Resolve the starred default template for a type, if any.
    func defaultTemplate(for typeID: ObjectTypeID) async throws -> ObjectTemplate?
}
