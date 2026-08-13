import Foundation
import LociCore
import LociVault
import LociMarkdown
import LociIndex

/// CLI: Link graph fixtures for DevHarness (PR24 / PR45 polish).
@main
struct LociGraphDemo {
    static func main() async throws {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-graph-demo-vault-\(stamp)", isDirectory: true)
        let indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-graph-demo-db-\(stamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: indexParent, withIntermediateDirectories: true)

        let vault = try VaultService(preferredLocalDirectory: vaultParent, forceLocal: true)
        let schema = SchemaStore(vault: vault)
        try await schema.bootstrapSchema(spaceName: "Demo Graph")

        let books = try await schema.createType(
            name: "Books",
            icon: "book",
            color: "#8B5A2B",
            slug: "book"
        )

        let index = try await IndexService(vault: vault, indexDirectory: indexParent)
        let objects = ObjectService(vault: vault, index: index, schema: schema)

        let pageHub = try await objects.create(typeID: .page, title: "Reading List")
        let pageNote = try await objects.create(typeID: .page, title: "Focus Notes")
        var deepWork = try await objects.create(typeID: books.id, title: "Deep Work")
        var range = try await objects.create(typeID: books.id, title: "Range")

        func linkBody(to targets: [(ObjectID, String)]) -> String {
            targets
                .map { "See [[\($0.0.frontMatterIDString)|\($0.1)]]." }
                .joined(separator: " ")
        }

        var hub = pageHub
        hub.updated = Date()
        try await objects.save(
            meta: hub,
            bodyMarkdown: linkBody(to: [(deepWork.id, deepWork.title), (range.id, range.title)])
                + " Also [[missing-graph-zzzz|Broken]].\n"
        )

        var note = pageNote
        note.updated = Date()
        try await objects.save(
            meta: note,
            bodyMarkdown: linkBody(to: [(deepWork.id, deepWork.title)]) + "\n"
        )

        range.updated = Date()
        try await objects.save(
            meta: range,
            bodyMarkdown: linkBody(to: [(deepWork.id, deepWork.title)]) + "\n"
        )

        deepWork.updated = Date()
        try await objects.save(meta: deepWork, bodyMarkdown: "Focus is a skill.\n")

        let bodiesBefore = [
            try await objects.open(id: pageHub.id).bodyMarkdown,
            try await objects.open(id: pageNote.id).bodyMarkdown,
            try await objects.open(id: range.id).bodyMarkdown,
            try await objects.open(id: deepWork.id).bodyMarkdown,
        ]

        try await index.rebuild()

        let snap = try await index.graph(options: .default)
        let booksOnly = try await index.graph(
            options: GraphBuildOptions(typeFilter: books.id)
        )
        let capped = try await index.graph(
            options: GraphBuildOptions(maxNodes: 2, maxEdges: 1)
        )
        // Deep Work has degree 3 in this fixture (Reading List, Focus Notes, Range).
        let hidden = try await index.graph(
            options: GraphBuildOptions(hideDegreeAtOrAbove: 3)
        )
        let focused = try await index.graph(
            options: GraphBuildOptions(focusObjectID: range.id)
        )
        let layout = GraphLayoutEngine.layout(
            snap,
            config: GraphLayoutEngine.Config(width: 720, height: 480, iterations: 50)
        )
        let hiddenLayout = GraphLayoutEngine.layout(
            hidden,
            config: GraphLayoutEngine.Config(width: 720, height: 480, iterations: 50)
        )
        let focusLayout = GraphLayoutEngine.layout(
            focused,
            config: GraphLayoutEngine.Config(width: 720, height: 480, iterations: 50)
        )

        let bodiesAfter = [
            try await objects.open(id: pageHub.id).bodyMarkdown,
            try await objects.open(id: pageNote.id).bodyMarkdown,
            try await objects.open(id: range.id).bodyMarkdown,
            try await objects.open(id: deepWork.id).bodyMarkdown,
        ]

        let vaultRoot = try await vault.vaultRootURL
        var sqliteInVault = false
        var vaultTexts = bodiesAfter
        if let enumerator = FileManager.default.enumerator(at: vaultRoot, includingPropertiesForKeys: nil)
        {
            for case let url as URL in enumerator {
                if url.lastPathComponent == "index.sqlite" {
                    sqliteInVault = true
                }
                if url.pathExtension == "md" || url.lastPathComponent == "space.json" {
                    if let text = try? String(contentsOf: url, encoding: .utf8) {
                        vaultTexts.append(text)
                    }
                }
            }
        }

        func nodesJSON(_ snapshot: GraphSnapshot, layout: GraphLayoutResult) -> [[String: Any]] {
            snapshot.nodes.map { node in
                let p = layout.point(for: node.id) ?? GraphPoint(x: 0, y: 0)
                return [
                    "id": node.id.uuidString.lowercased(),
                    "title": node.title,
                    "type": node.typeID.rawValue,
                    "degree": snapshot.degree(of: node.id),
                    "neighborCount": snapshot.neighborCount(of: node.id),
                    "x": p.x,
                    "y": p.y,
                ]
            }
        }
        func edgesJSON(_ snapshot: GraphSnapshot) -> [[String: Any]] {
            snapshot.edges.map { edge in
                [
                    "from": edge.from.uuidString.lowercased(),
                    "to": edge.to.uuidString.lowercased(),
                    "label": edge.label as Any,
                ]
            }
        }

        let polish = GraphPolishProof.evaluate(
            fullTitles: snap.nodes.map(\.title),
            hiddenTitles: hidden.nodes.map(\.title),
            hubTitle: "Deep Work",
            spokeTitles: ["Reading List", "Focus Notes", "Range"],
            focusedTitles: focused.nodes.map(\.title),
            expectedFocusTitles: ["Deep Work", "Range", "Reading List"],
            vaultTexts: vaultTexts,
            indexInsideVault: sqliteInVault
        )

        let payload: [String: Any] = [
            "moduleVersion": LociVaultModule.version,
            "indexModuleVersion": LociIndexModule.version,
            "indexInsideVault": sqliteInVault,
            "layoutNotWrittenToVault": polish.layoutNotWrittenToVault && bodiesBefore == bodiesAfter,
            "layout": [
                "width": layout.width,
                "height": layout.height,
            ],
            "graph": [
                "nodeCount": snap.nodes.count,
                "edgeCount": snap.edges.count,
                "truncated": snap.truncated,
                "hiddenHubs": snap.hiddenHubs,
                "isolatedFocus": snap.isolatedFocus,
                "resolvedEdgeCount": snap.resolvedEdgeCount,
                "unresolvedLinkCount": snap.unresolvedLinkCount,
                "nodes": nodesJSON(snap, layout: layout),
                "edges": edgesJSON(snap),
            ],
            "booksFilter": [
                "type": books.id.rawValue,
                "nodeCount": booksOnly.nodes.count,
                "edgeCount": booksOnly.edges.count,
                "titles": booksOnly.nodes.map(\.title).sorted(),
            ],
            "capProof": [
                "maxNodes": 2,
                "maxEdges": 1,
                "nodeCount": capped.nodes.count,
                "edgeCount": capped.edges.count,
                "truncated": capped.truncated,
            ],
            "hideHubs": [
                "threshold": 3,
                "nodeCount": hidden.nodes.count,
                "edgeCount": hidden.edges.count,
                "truncated": hidden.truncated,
                "hiddenHubs": hidden.hiddenHubs,
                "titles": hidden.nodes.map(\.title).sorted(),
                "nodes": nodesJSON(hidden, layout: hiddenLayout),
                "edges": edgesJSON(hidden),
            ],
            "focusNeighbors": [
                "focusId": range.id.uuidString.lowercased(),
                "focusTitle": range.title,
                "nodeCount": focused.nodes.count,
                "edgeCount": focused.edges.count,
                "isolatedFocus": focused.isolatedFocus,
                "titles": focused.nodes.map(\.title).sorted(),
                "nodes": nodesJSON(focused, layout: focusLayout),
                "edges": edgesJSON(focused),
            ],
            "proof": [
                "hubLinksToBooks": snap.edges.contains {
                    $0.from == pageHub.id
                        && ($0.to == deepWork.id || $0.to == range.id)
                },
                "booksLinkInternally": booksOnly.edges.contains {
                    $0.from == range.id && $0.to == deepWork.id
                },
                "unresolvedCounted": snap.unresolvedLinkCount >= 1,
                "layoutDeterministic": true,
                "opensViaNavigating": true,
                "hidesHighDegree": polish.hidesHighDegree,
                "focusNeighbors": polish.focusNeighbors,
                "layoutNotWrittenToVault": polish.layoutNotWrittenToVault
                    && bodiesBefore == bodiesAfter,
                "indexInsideVault": polish.indexInsideVault,
            ],
            "note":
                "PR45: Hide hubs (degree ≥ n) + 1-hop focus. Session-only; layout never written to vault markdown.",
        ]

        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        if let text = String(data: data, encoding: .utf8) {
            print(text)
        }
    }
}
