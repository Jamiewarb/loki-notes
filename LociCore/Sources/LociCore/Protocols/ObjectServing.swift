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
    func create(typeID: ObjectTypeID, title: String) async throws -> LociObjectMeta

    /// Resolve id via index → vault read → parse markdown → meta + body.
    func open(id: ObjectID) async throws -> OpenedObject

    /// Persist title/properties (from `meta`) + body markdown; update index asynchronously.
    func save(meta: LociObjectMeta, bodyMarkdown: String) async throws

    /// Soft-delete: trash + tombstone + index remove.
    func delete(id: ObjectID) async throws
}
