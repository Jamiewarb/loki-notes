import Foundation
import GRDB
import LociCore

/// Builds a capped `GraphSnapshot` from the disposable `links` table (PR24).
///
/// Resolves wiki targets via `LinkResolver`; broken links are counted but not drawn.
enum GraphBuilder {
    /// Scan limit before assembly (guards against huge vaults even before degree-cap).
    static let rawLinkScanLimit = 5_000

    static func build(db: Database, options: GraphBuildOptions) throws -> GraphSnapshot {
        let rows = try Row.fetchAll(
            db,
            sql: """
                SELECT source_id, target, label FROM links
                ORDER BY id ASC
                LIMIT ?
                """,
            arguments: [rawLinkScanLimit]
        )

        var nodesByID: [ObjectID: GraphNode] = [:]
        var edges: [GraphEdge] = []
        var seenEdgeKeys = Set<String>()
        var unresolved = 0

        for row in rows {
            let sourceKey: String = row["source_id"]
            let target: String = row["target"]
            let label: String? = row["label"]

            guard
                let sourceRow = try Row.fetchOne(
                    db,
                    sql: "SELECT * FROM objects WHERE id = ?",
                    arguments: [sourceKey.lowercased()]
                )
            else {
                unresolved += 1
                continue
            }

            let sourceMeta = try ObjectRowDecoder.decode(sourceRow)
            guard let resolved = try LinkResolver.resolve(db: db, target: target) else {
                unresolved += 1
                continue
            }

            // Skip self-loops.
            if sourceMeta.id == resolved.id { continue }

            nodesByID[sourceMeta.id] = GraphNode(meta: sourceMeta)
            nodesByID[resolved.id] = GraphNode(meta: resolved)

            let key =
                "\(sourceMeta.id.uuidString.lowercased())->\(resolved.id.uuidString.lowercased())"
            if seenEdgeKeys.contains(key) { continue }
            seenEdgeKeys.insert(key)
            edges.append(GraphEdge(from: sourceMeta.id, to: resolved.id, label: label))
        }

        return GraphAssembly.assemble(
            nodesByID: nodesByID,
            edges: edges,
            unresolvedLinkCount: unresolved,
            options: options
        )
    }
}
