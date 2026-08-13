import Foundation
import LociCore

extension SchemaStore {
    /// Parse stored pin strings (UUID or `daily-YYYY-MM-DD`) into ids, dropping junk, preserving order.
    public static func parsePinIDs(_ raw: [String]) -> [ObjectID] {
        var seen = Set<ObjectID>()
        var result: [ObjectID] = []
        for string in raw {
            guard let id = ObjectID(parsing: string) else { continue }
            if seen.insert(id).inserted {
                result.append(id)
            }
        }
        return result
    }

    public func pinnedObjectIDs() async throws -> [ObjectID] {
        let settings = try await loadSpaceSettings()
        return Self.parsePinIDs(settings.pins)
    }

    @discardableResult
    public func pinObject(_ id: ObjectID) async throws -> [ObjectID] {
        var settings = try await loadSpaceSettings()
        var ids = Self.parsePinIDs(settings.pins)
        if ids.contains(id) {
            return ids
        }
        guard ids.count < PinLimits.maxCount else {
            throw LociError.pinLimitReached(PinLimits.maxCount)
        }
        ids.append(id)
        settings.pins = ids.map(\.frontMatterIDString)
        try await saveSpaceSettings(settings)
        return ids
    }

    @discardableResult
    public func unpinObject(_ id: ObjectID) async throws -> [ObjectID] {
        var settings = try await loadSpaceSettings()
        var ids = Self.parsePinIDs(settings.pins)
        let before = ids.count
        ids.removeAll { $0 == id }
        if ids.count == before {
            return ids
        }
        settings.pins = ids.map(\.frontMatterIDString)
        try await saveSpaceSettings(settings)
        return ids
    }
}
