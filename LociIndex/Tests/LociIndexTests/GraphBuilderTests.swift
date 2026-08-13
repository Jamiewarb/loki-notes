import XCTest
import Foundation
import LociCore
import LociVault
import LociMarkdown
@testable import LociIndex

final class GraphBuilderTests: XCTestCase {
    private var vaultParent: URL!
    private var indexParent: URL!
    private var vault: VaultService!
    private var index: IndexService!

    override func setUpWithError() throws {
        let stamp = UUID().uuidString
        vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-graph-vault-\(stamp)", isDirectory: true)
        indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-graph-db-\(stamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: indexParent, withIntermediateDirectories: true)
        vault = try VaultService(preferredLocalDirectory: vaultParent, forceLocal: true)
    }

    override func tearDownWithError() throws {
        index = nil
        vault = nil
        if let vaultParent { try? FileManager.default.removeItem(at: vaultParent) }
        if let indexParent { try? FileManager.default.removeItem(at: indexParent) }
    }

    private func boot() async throws {
        try await vault.ensureSkeleton(spaceName: "Graph Test")
        index = try await IndexService(vault: vault, indexDirectory: indexParent)
    }

    private func writePage(
        id: UUID,
        title: String,
        path: String,
        type: String = "page",
        body: String
    ) async throws {
        let created = ISO8601DateFormatter().date(from: "2026-08-13T10:00:00Z")!
        let md = """
            ---
            id: \(id.uuidString.lowercased())
            type: \(type)
            title: \(title)
            created: \(iso(created))
            updated: \(iso(created))
            tags: []
            ---

            \(body)
            """
        try await vault.writeFile(Data(md.utf8), atRelativePath: path)
    }

    private func iso(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: date)
    }

    func testGraphFromLinksTable() async throws {
        try await boot()
        let idA = UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1")!
        let idB = UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2")!
        let idC = UUID(uuidString: "cccccccc-cccc-4ccc-8ccc-ccccccccccc3")!

        try await writePage(id: idB, title: "Page B", path: "objects/page/page-b.md", body: "Target.")
        try await writePage(id: idC, title: "Page C", path: "objects/page/page-c.md", body: "Leaf.")
        try await writePage(
            id: idA,
            title: "Page A",
            path: "objects/page/page-a.md",
            body: """
                See [[\(idB.uuidString.lowercased())|Page B]] and [[missing-zzzz|Broken]].
                Also [[\(idC.uuidString.lowercased())]].
                """
        )
        try await index.rebuild()

        let snap = try await index.graph(options: .default)
        XCTAssertEqual(snap.nodes.count, 3)
        XCTAssertEqual(snap.edges.count, 2)
        XCTAssertEqual(snap.unresolvedLinkCount, 1)
        XCTAssertFalse(snap.truncated)

        let titles = Set(snap.nodes.map(\.title))
        XCTAssertEqual(titles, ["Page A", "Page B", "Page C"])

        let fromA = snap.edges.filter { $0.from == ObjectID(idA) }
        XCTAssertEqual(Set(fromA.map(\.to)), [ObjectID(idB), ObjectID(idC)])
    }

    func testGraphTypeFilterAndCaps() async throws {
        try await boot()
        let idPage = UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1")!
        let idBook1 = UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2")!
        let idBook2 = UUID(uuidString: "cccccccc-cccc-4ccc-8ccc-ccccccccccc3")!

        try await writePage(
            id: idBook1,
            title: "Deep Work",
            path: "objects/book/deep-work.md",
            type: "book",
            body: "Focus."
        )
        try await writePage(
            id: idBook2,
            title: "Range",
            path: "objects/book/range.md",
            type: "book",
            body: "See [[\(idBook1.uuidString.lowercased())]]."
        )
        try await writePage(
            id: idPage,
            title: "Notes",
            path: "objects/page/notes.md",
            body: "See [[\(idBook1.uuidString.lowercased())]] and [[\(idBook2.uuidString.lowercased())]]."
        )
        try await index.rebuild()

        let all = try await index.graph(options: .default)
        XCTAssertEqual(all.nodes.count, 3)
        XCTAssertEqual(all.edges.count, 3)

        let booksOnly = try await index.graph(
            options: GraphBuildOptions(typeFilter: ObjectTypeID("book"))
        )
        XCTAssertEqual(Set(booksOnly.nodes.map(\.title)), ["Deep Work", "Range"])
        XCTAssertEqual(booksOnly.edges.count, 1)

        let capped = try await index.graph(
            options: GraphBuildOptions(maxNodes: 2, maxEdges: 1)
        )
        XCTAssertTrue(capped.truncated)
        XCTAssertLessThanOrEqual(capped.nodes.count, 2)
        XCTAssertLessThanOrEqual(capped.edges.count, 1)
    }

    func testGraphLayoutFromIndexSnapshot() async throws {
        try await boot()
        let idA = UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1")!
        let idB = UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2")!
        try await writePage(id: idB, title: "B", path: "objects/page/b.md", body: "x")
        try await writePage(
            id: idA,
            title: "A",
            path: "objects/page/a.md",
            body: "[[\(idB.uuidString.lowercased())]]"
        )
        try await index.rebuild()
        let snap = try await index.graph(options: .default)
        let layout = GraphLayoutEngine.layout(snap)
        XCTAssertEqual(layout.positions.count, 2)
        XCTAssertTrue(LociIndexModule.version.contains("pr24"))
    }
}
