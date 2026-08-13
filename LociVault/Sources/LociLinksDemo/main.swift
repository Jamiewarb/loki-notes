import Foundation
import LociCore
import LociVault
import LociMarkdown
import LociIndex

/// CLI: Link Page A → B; open B → see backlink to A (PR16).
@main
struct LociLinksDemo {
    static func main() async throws {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-links-demo-vault-\(stamp)", isDirectory: true)
        let indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-links-demo-db-\(stamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: indexParent, withIntermediateDirectories: true)

        let vault = try VaultService(preferredLocalDirectory: vaultParent, forceLocal: true)
        let schema = SchemaStore(vault: vault)
        try await schema.bootstrapSchema(spaceName: "Demo Links")

        let index = try await IndexService(vault: vault, indexDirectory: indexParent)
        let objects = ObjectService(vault: vault, index: index, schema: schema)

        let pageB = try await objects.create(typeID: .page, title: "Page B")
        let pageA = try await objects.create(typeID: .page, title: "Page A")

        // Simulate @ / [[ picker insert: prefer ObjectID as wiki target.
        let session = try EditorSession(bodyMarkdown: "Notes from today @")
        let trigger = WikiLinkTriggerDetector.detect(in: EditorSession.plainText(of: session.blocks[0]))
        _ = session.insertWikiLink(
            blockIndex: 0,
            target: pageB.id.frontMatterIDString,
            label: pageB.title,
            trigger: trigger
        )
        // Also add a broken link for styling demo.
        session.applyLocalEdit(
            .setPlainText(
                blockIndex: 0,
                text: EditorSession.plainText(of: session.blocks[0])
                    + " and [[missing-object-zzzz|Broken]]."
            )
        )
        let bodyA = session.serializeBody()
        var metaA = pageA
        metaA.updated = Date()
        try await objects.save(meta: metaA, bodyMarkdown: bodyA)

        try await index.rebuild()

        let backs = try await index.backlinks(to: pageB.id)
        let outgoing = try await index.outgoingLinks(from: pageA.id)
        let resolvedB = try await index.resolve(wikiTarget: pageB.id.frontMatterIDString)
        let resolvedPath = try await index.resolve(wikiTarget: pageB.relativePath)
        let broken = try await index.resolve(wikiTarget: "missing-object-zzzz")

        let openedA = try await objects.open(id: pageA.id)
        let doc = try MarkdownParser().parse(openedA.bodyMarkdown)
        let resolvedSet = Set(
            outgoing.compactMap { link -> String? in
                link.isBroken ? nil : link.target
            }
        )
        let html = BlockASTHTML.render(doc.blocks, resolvedTargets: resolvedSet)

        let vaultRoot = try await vault.vaultRootURL
        var sqliteInVault = false
        if let enumerator = FileManager.default.enumerator(at: vaultRoot, includingPropertiesForKeys: nil)
        {
            for case let url as URL in enumerator {
                if url.lastPathComponent == "index.sqlite" {
                    sqliteInVault = true
                    break
                }
            }
        }

        let candidates = try await index.linkCandidates(
            matching: "Page",
            excluding: pageA.id,
            limit: 10
        )

        let payload: [String: Any] = [
            "moduleVersion": LociIndexModule.version,
            "markdownModuleVersion": LociMarkdownModule.version,
            "vaultRoot": vaultRoot.path,
            "indexPath": index.databaseURL.path,
            "indexInsideVault": sqliteInVault,
            "pageA": [
                "id": pageA.id.uuidString.lowercased(),
                "title": pageA.title,
                "relativePath": pageA.relativePath,
                "bodyMarkdown": bodyA,
            ],
            "pageB": [
                "id": pageB.id.uuidString.lowercased(),
                "title": pageB.title,
                "relativePath": pageB.relativePath,
            ],
            "backlinksOnB": backs.map { hit in
                [
                    "sourceId": hit.source.id.uuidString.lowercased(),
                    "sourceTitle": hit.source.title,
                    "target": hit.target,
                    "label": hit.label as Any,
                ] as [String: Any]
            },
            "outgoingFromA": outgoing.map { link in
                [
                    "target": link.target,
                    "label": link.label as Any,
                    "resolvedTitle": link.resolved?.title as Any,
                    "isBroken": link.isBroken,
                    "styleClass": link.isBroken ? "wiki-link is-broken" : "wiki-link is-resolved",
                ] as [String: Any]
            },
            "resolve": [
                "byId": resolvedB?.title as Any,
                "byPath": resolvedPath?.title as Any,
                "brokenIsNil": broken == nil,
            ],
            "pickerCandidates": candidates.map { meta in
                [
                    "id": meta.id.uuidString.lowercased(),
                    "title": meta.title,
                    "type": meta.typeID.rawValue,
                ]
            },
            "html": html,
            "proof": [
                "aLinksToB": backs.contains { $0.source.id == pageA.id },
                "backlinkCount": backs.count,
                "brokenCount": outgoing.filter(\.isBroken).count,
                "resolvedCount": outgoing.filter { !$0.isBroken }.count,
                "preferredTargetIsObjectID": bodyA.contains(pageB.id.frontMatterIDString),
            ],
            "note":
                "PR16: Link A→B via [[ObjectID|title]]; open B → backlinks list A. Broken links styled is-broken.",
        ]

        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        if let text = String(data: data, encoding: .utf8) {
            print(text)
        }
    }
}
