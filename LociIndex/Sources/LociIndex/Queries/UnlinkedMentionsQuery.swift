import Foundation
import GRDB
import LociCore

/// Unlinked title mentions over FTS body + the `links` table (PR44).
///
/// Candidates come from FTS; sources that already have a resolved outgoing link
/// to the target are excluded; the pure scanner verifies the vault markdown body.
/// Never invoked from the editor typing path.
enum UnlinkedMentionsQuery {
    static let candidateCap = 80

    struct Candidate: Sendable {
        var meta: LociObjectMeta
        var wikiTargets: [String]
        var alreadyLinksToTarget: Bool
    }

    static func candidates(
        db: Database,
        target: LociObjectMeta,
        title: String
    ) throws -> [Candidate] {
        let excludeID = target.id.uuidString.lowercased()
        let aliases = Set(LinkResolver.targetAliases(for: target).map { $0.lowercased() })
        let hits = try SearchQuery.search(db: db, query: title, limit: candidateCap)
        var results: [Candidate] = []
        var seen = Set<String>()
        for meta in hits {
            let key = meta.id.uuidString.lowercased()
            if key == excludeID { continue }
            if seen.contains(key) { continue }
            seen.insert(key)
            let outgoing = try LinksQuery.outgoing(db: db, from: meta.id)
            let wikiTargets = outgoing.map(\.target)
            let already = outgoing.contains { link in
                if let resolved = link.resolved, resolved.id == target.id {
                    return true
                }
                return aliases.contains(link.target.lowercased())
            }
            results.append(
                Candidate(meta: meta, wikiTargets: wikiTargets, alreadyLinksToTarget: already)
            )
        }
        return results
    }
}
