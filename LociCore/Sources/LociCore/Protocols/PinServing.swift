import Foundation

/// Pinned objects live in `.loci/space.json` (`SpaceSettings.pins`) so they sync
/// with the vault. The local index is display-only (title / type / path).
///
/// Implemented by `SchemaStore`. Cap is `PinLimits.maxCount`. Pin is idempotent;
/// unpin of a missing id is a no-op. Daily notes may be pinned.
public protocol PinServing: Sendable {
    /// Append `id` to the pin list. No-op if already pinned. Throws when the cap is hit.
    @discardableResult
    func pinObject(_ id: ObjectID) async throws -> [ObjectID]

    /// Remove `id` from the pin list. No-op if it is not pinned.
    @discardableResult
    func unpinObject(_ id: ObjectID) async throws -> [ObjectID]

    /// Pinned object ids in list order (invalid stored strings are skipped).
    func pinnedObjectIDs() async throws -> [ObjectID]
}

extension PinServing {
    public func isPinned(_ id: ObjectID) async throws -> Bool {
        try await pinnedObjectIDs().contains(id)
    }
}
