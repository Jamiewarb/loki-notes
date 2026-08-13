import Foundation
import LociCore

/// Thin Properties-local facade over `IndexQuerying.linkCandidates` (PR40).
/// Must not import `App/Features/Links` — the picker view is duplicated here.
@MainActor
final class ObjectSelectStore {
    private let services: AppServices

    init(services: AppServices) {
        self.services = services
    }

    func candidates(
        matching query: String,
        excluding: ObjectID?,
        limit: Int = 12
    ) async throws -> [LociObjectMeta] {
        let index = try await services.ensureIndex()
        return try await index.linkCandidates(
            matching: query,
            excluding: excluding,
            limit: limit
        )
    }

    func metas(for ids: [String]) async throws -> [String: LociObjectMeta] {
        let index = try await services.ensureIndex()
        var map: [String: LociObjectMeta] = [:]
        for raw in ids {
            let key = ObjectSelectID.persistableString(from: raw)
            guard let oid = ObjectID(parsing: key) else { continue }
            if let meta = try await index.object(id: oid) {
                map[key] = meta
            }
        }
        return map
    }
}
