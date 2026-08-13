import Foundation

/// High-level object CRUD. Single orchestration entry for features (PR08).
///
/// **Write path:** Feature → `ObjectServing` → Markdown serialize → `VaultServing`
/// → async `IndexUpdating.applyVaultEvent` (never block typing on index).
///
/// **Debounced save:** The editor owns dirty state and debounce timing (e.g. 500ms idle
/// + 5s max). `save` itself is immediate once invoked — see `EditorSession` /
/// Apple `EditorSessionBridge` (PR09).
public protocol ObjectServing: Sendable {
    /// Create a new object file under `objects/<type>/`, index it, return metadata.
    /// Applies the type's default template (body + property defaults) when schema is wired.
    func create(typeID: ObjectTypeID, title: String) async throws -> LociObjectMeta

    /// Resolve id via index → vault read → parse markdown → meta + body.
    func open(id: ObjectID) async throws -> OpenedObject

    /// Persist title/properties (from `meta`) + body markdown; update index asynchronously.
    func save(meta: LociObjectMeta, bodyMarkdown: String) async throws

    /// Soft-delete: trash + tombstone + index remove.
    func delete(id: ObjectID) async throws

    /// Re-apply a template to an object only when body is empty / whitespace (PR14).
    @discardableResult
    func applyTemplateIfEmpty(id: ObjectID, templateID: String) async throws -> OpenedObject

    // MARK: - Type conversion (PR28)

    /// Preview a type change with suggested property mapping (no vault writes).
    func planConversion(id: ObjectID, toTypeID: ObjectTypeID) async throws -> TypeConversionPlan

    /// Change object type: remap properties, move file under `objects/<type>/`,
    /// keep ObjectID stable, update index/links via IndexUpdating.
    @discardableResult
    func convert(
        id: ObjectID,
        toTypeID: ObjectTypeID,
        propertyMap: [TypeConversionPropertyMap]
    ) async throws -> TypeConversionResult
}
