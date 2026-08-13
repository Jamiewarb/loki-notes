import Foundation
import LociCore
import LociIndex
import LociVault
import XCTest

final class GraphPolishSystemTests: XCTestCase {
    private var vaultParent: URL!
    private var indexParent: URL!
    private var vault: VaultService!
    private var schema: SchemaStore!
    private var index: IndexService!
    private var objects: ObjectService!

    override func setUpWithError() throws {
        let stamp = UUID().uuidString
        vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-graph-polish-vault-\(stamp)", isDirectory: true)
        indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-graph-polish-db-\(stamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: indexParent, withIntermediateDirectories: true)
        vault = try VaultService(preferredLocalDirectory: vaultParent, forceLocal: true)
    }

    override func tearDownWithError() throws {
        objects = nil
        index = nil
        schema = nil
        vault = nil
        if let vaultParent { try? FileManager.default.removeItem(at: vaultParent) }
        if let indexParent { try? FileManager.default.removeItem(at: indexParent) }
    }

    private func boot() async throws {
        schema = SchemaStore(vault: vault)
        try await schema.bootstrapSchema(spaceName: "Graph Polish Test")
        index = try await IndexService(vault: vault, indexDirectory: indexParent)
        objects = ObjectService(vault: vault, index: index, schema: schema)
    }

    func testHideHubsAndFocusDoNotWriteLayoutIntoVault() async throws {
        try await boot()

        func linkBody(to targets: [(ObjectID, String)]) -> String {
            targets.map { "See [[\($0.0.frontMatterIDString)|\($0.1)]]." }.joined(separator: " ")
                + "\n"
        }

        var spokeA = try await objects.create(typeID: .page, title: "A")
        var spokeB = try await objects.create(typeID: .page, title: "B")
        var leafE = try await objects.create(typeID: .page, title: "E")
        var leafF = try await objects.create(typeID: .page, title: "F")
        var hub = try await objects.create(typeID: .page, title: "Hub")

        try await objects.save(meta: spokeA, bodyMarkdown: "Leaf A.\n")
        try await objects.save(meta: spokeB, bodyMarkdown: "Leaf B.\n")
        try await objects.save(meta: leafF, bodyMarkdown: "Leaf F.\n")
        leafE.updated = Date()
        try await objects.save(
            meta: leafE,
            bodyMarkdown: linkBody(to: [(leafF.id, leafF.title)])
        )
        hub.updated = Date()
        try await objects.save(
            meta: hub,
            bodyMarkdown: linkBody(to: [(spokeA.id, spokeA.title), (spokeB.id, spokeB.title)])
        )

        let beforeBodies = [
            try await objects.open(id: hub.id).bodyMarkdown,
            try await objects.open(id: spokeA.id).bodyMarkdown,
            try await objects.open(id: leafE.id).bodyMarkdown,
        ]

        try await index.rebuild()

        let full = try await index.graph(options: .default)
        let hidden = try await index.graph(
            options: GraphBuildOptions(hideDegreeAtOrAbove: 2)
        )
        let focused = try await index.graph(
            options: GraphBuildOptions(focusObjectID: spokeA.id)
        )

        XCTAssertTrue(full.nodes.contains(where: { $0.title == "Hub" }))
        XCTAssertTrue(hidden.hiddenHubs)
        XCTAssertFalse(hidden.nodes.contains(where: { $0.title == "Hub" }))
        XCTAssertTrue(focused.isolatedFocus)
        XCTAssertEqual(Set(focused.nodes.map(\.title)), ["A", "Hub"])

        let afterBodies = [
            try await objects.open(id: hub.id).bodyMarkdown,
            try await objects.open(id: spokeA.id).bodyMarkdown,
            try await objects.open(id: leafE.id).bodyMarkdown,
        ]
        XCTAssertEqual(beforeBodies, afterBodies)

        let vaultRoot = try await vault.vaultRootURL
        var sqliteInVault = false
        var vaultTexts: [String] = afterBodies
        if let enumerator = FileManager.default.enumerator(
            at: vaultRoot,
            includingPropertiesForKeys: nil
        ) {
            for case let url as URL in enumerator {
                if url.lastPathComponent == "index.sqlite" { sqliteInVault = true }
                if url.pathExtension == "md" || url.lastPathComponent == "space.json" {
                    if let text = try? String(contentsOf: url, encoding: .utf8) {
                        vaultTexts.append(text)
                    }
                }
            }
        }
        XCTAssertFalse(sqliteInVault)
        XCTAssertFalse(index.databaseURL.path.hasPrefix(vaultRoot.path))

        let layout = GraphLayoutEngine.layout(full)
        XCTAssertFalse(
            vaultTexts.contains { text in
                layout.positions.values.contains { point in
                    text.contains("\(point.x)") && text.contains("\(point.y)")
                        && GraphPolishProof.markdownLooksLikeGraphLayout(text)
                }
            }
        )

        let proof = GraphPolishProof.evaluate(
            fullTitles: full.nodes.map(\.title),
            hiddenTitles: hidden.nodes.map(\.title),
            hubTitle: "Hub",
            spokeTitles: ["A", "B"],
            focusedTitles: focused.nodes.map(\.title),
            expectedFocusTitles: ["A", "Hub"],
            vaultTexts: vaultTexts,
            indexInsideVault: sqliteInVault
        )
        XCTAssertTrue(proof.hidesHighDegree)
        XCTAssertTrue(proof.focusNeighbors)
        XCTAssertTrue(proof.layoutNotWrittenToVault)
        XCTAssertFalse(proof.indexInsideVault)
    }

    func testModuleVersionIsPR45() {
        XCTAssertTrue(
            LociVaultModule.version.contains("pr44") || LociVaultModule.version.contains("pr45"),
            LociVaultModule.version
        )
        XCTAssertTrue(
            LociVaultModule.version == "0.44.0-pr44" || LociVaultModule.version == "0.45.0-pr45",
            LociVaultModule.version
        )
    }
}
