import Foundation

/// Resolve space.json pin ids into display rows via the index, then `ObjectServing.open`.
/// Never writes the vault. Missing objects become `PinnedObjectRow.missing` — no crash.
public struct PinResolver: Sendable {
    private let pins: any PinServing
    private let index: (any IndexQuerying)?
    private let objects: (any ObjectServing)?

    public init(
        pins: any PinServing,
        index: (any IndexQuerying)? = nil,
        objects: (any ObjectServing)? = nil
    ) {
        self.pins = pins
        self.index = index
        self.objects = objects
    }

    public func resolvedRows() async throws -> [PinnedObjectRow] {
        let ids = try await pins.pinnedObjectIDs()
        var rows: [PinnedObjectRow] = []
        rows.reserveCapacity(ids.count)
        for id in ids {
            rows.append(await resolve(id))
        }
        return rows
    }

    private func resolve(_ id: ObjectID) async -> PinnedObjectRow {
        if let index, let meta = try? await index.object(id: id) {
            return .resolved(meta)
        }
        if let objects, let opened = try? await objects.open(id: id) {
            return .resolved(opened.meta)
        }
        return .missing(id)
    }
}
