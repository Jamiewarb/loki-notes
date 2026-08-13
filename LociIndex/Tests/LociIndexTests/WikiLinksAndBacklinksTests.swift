import XCTest
import Foundation
import LociCore
import LociVault
import LociMarkdown
@testable import LociIndex

final class WikiLinksAndBacklinksTests: XCTestCase {
    private var vaultParent: URL!
    private var indexParent: URL!
    private var vault: VaultService!
    private var index: IndexService!

    override func setUpWithError() throws {
        let stamp = UUID().uuidString
        vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-links-vault-\(stamp)", isDirectory: true)
        indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-links-db-\(stamp)", isDirectory: true)
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
        try await vault.ensureSkeleton(spaceName: "Links Test")
        index = try await IndexService(vault: vault, indexDirectory: indexParent)
    }

    private func writePage(
        id: UUID,
        title: String,
        path: String,
        body: String
    ) async throws {
        let created = ISO8601DateFormatter().date(from: "2026-08-13T10:00:00Z")!
        let md = """
            ---
            id: \(id.uuidString.lowercased())
            type: page
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

    func testLinkAToBThenBacklinkOnB() async throws {
        try await boot()
        let idA = UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1")!
        let idB = UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2")!

        try await writePage(
            id: idB,
            title: "Page B",
            path: "objects/page/page-b.md",
            body: "Target page."
        )
        try await writePage(
            id: idA,
            title: "Page A",
            path: "objects/page/page-a.md",
            body: "See [[\(idB.uuidString.lowercased())|Page B]] for more."
        )
        try await index.rebuild()

        let backs = try await index.backlinks(to: ObjectID(idB))
        XCTAssertEqual(backs.count, 1)
        XCTAssertEqual(backs.first?.source.id, ObjectID(idA))
        XCTAssertEqual(backs.first?.source.title, "Page A")

        let outgoing = try await index.outgoingLinks(from: ObjectID(idA))
        XCTAssertEqual(outgoing.count, 1)
        XCTAssertEqual(outgoing.first?.resolved?.id, ObjectID(idB))
        XCTAssertFalse(outgoing.first?.isBroken == true)
    }

    func testResolvePrefersObjectIDThenPathThenTitle() async throws {
        try await boot()
        let id = UUID(uuidString: "cccccccc-cccc-4ccc-8ccc-ccccccccccc3")!
        try await writePage(
            id: id,
            title: "Deep Work",
            path: "objects/page/deep-work.md",
            body: "Focus."
        )
        try await index.rebuild()

        let byID = try await index.resolve(wikiTarget: id.uuidString.lowercased())
        XCTAssertEqual(byID?.id, ObjectID(id))

        let byPath = try await index.resolve(wikiTarget: "objects/page/deep-work.md")
        XCTAssertEqual(byPath?.id, ObjectID(id))

        let bySlug = try await index.resolve(wikiTarget: "deep-work")
        XCTAssertEqual(bySlug?.id, ObjectID(id))

        let byTitle = try await index.resolve(wikiTarget: "Deep Work")
        XCTAssertEqual(byTitle?.id, ObjectID(id))

        let broken = try await index.resolve(wikiTarget: "does-not-exist-xyz")
        XCTAssertNil(broken)
    }

    func testBrokenOutgoingLink() async throws {
        try await boot()
        let idA = UUID(uuidString: "dddddddd-dddd-4ddd-8ddd-ddddddddddd4")!
        try await writePage(
            id: idA,
            title: "Broken Ref",
            path: "objects/page/broken-ref.md",
            body: "Missing [[eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee5|Gone]]."
        )
        try await index.rebuild()

        let outgoing = try await index.outgoingLinks(from: ObjectID(idA))
        XCTAssertEqual(outgoing.count, 1)
        XCTAssertTrue(outgoing.first?.isBroken == true)
    }

    func testLinkCandidatesSearch() async throws {
        try await boot()
        let idA = UUID(uuidString: "ffffffff-ffff-4fff-8fff-fffffffffff6")!
        let idB = UUID(uuidString: "99999999-9999-4999-8999-999999999997")!
        try await writePage(id: idA, title: "Alpha Note", path: "objects/page/alpha.md", body: "a")
        try await writePage(id: idB, title: "Beta Note", path: "objects/page/beta.md", body: "b")
        try await index.rebuild()

        let hits = try await index.linkCandidates(
            matching: "Alpha",
            excluding: ObjectID(idB),
            limit: 10
        )
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits.first?.title, "Alpha Note")

        let recent = try await index.linkCandidates(
            matching: "",
            excluding: ObjectID(idA),
            limit: 10
        )
        XCTAssertTrue(recent.contains { $0.id == ObjectID(idB) })
        XCTAssertFalse(recent.contains { $0.id == ObjectID(idA) })
    }

    func testIndexStillOutsideVault() async throws {
        try await boot()
        let vaultRoot = try await vault.vaultRootURL
        XCTAssertFalse(index.databaseURL.path.hasPrefix(vaultRoot.path))
    }

    func testObjectSelectPropertyCreatesRealLinksWithoutBodyWikiLink() async throws {
        try await boot()
        let personID = UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1")!
        let bookID = UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2")!
        let created = ISO8601DateFormatter().date(from: "2026-08-13T10:00:00Z")!

        try await vault.writeFile(
            Data(
                """
                ---
                id: \(personID.uuidString.lowercased())
                type: page
                title: Cal Newport
                created: \(iso(created))
                updated: \(iso(created))
                tags: []
                ---

                Author.
                """.utf8
            ),
            atRelativePath: "objects/page/cal-newport.md"
        )
        try await vault.writeFile(
            Data(
                """
                ---
                id: \(bookID.uuidString.lowercased())
                type: page
                title: Deep Work
                created: \(iso(created))
                updated: \(iso(created))
                tags: []
                properties:
                  author:
                    - \(personID.uuidString.lowercased())
                ---

                Focus is a skill.
                """.utf8
            ),
            atRelativePath: "objects/page/deep-work.md"
        )
        try await index.rebuild()

        let backs = try await index.backlinks(to: ObjectID(personID))
        XCTAssertEqual(backs.count, 1)
        XCTAssertEqual(backs.first?.source.id, ObjectID(bookID))
        XCTAssertEqual(backs.first?.source.title, "Deep Work")

        let outgoing = try await index.outgoingLinks(from: ObjectID(bookID))
        XCTAssertEqual(outgoing.count, 1)
        XCTAssertEqual(outgoing.first?.resolved?.id, ObjectID(personID))
        XCTAssertFalse(outgoing.first?.isBroken == true)

        let bookData = try await vault.readFile(atRelativePath: "objects/page/deep-work.md")
        let bookText = String(data: bookData, encoding: .utf8) ?? ""
        let parts = bookText.split(separator: "---", maxSplits: 2, omittingEmptySubsequences: false)
        let body = parts.count >= 3 ? String(parts[2]) : bookText
        XCTAssertFalse(body.contains("[["), body)
        XCTAssertTrue(bookText.contains(personID.uuidString.lowercased()))
    }

    func testObjectSelectBrokenIDStillOutgoing() async throws {
        try await boot()
        let bookID = UUID(uuidString: "dddddddd-dddd-4ddd-8ddd-ddddddddddd4")!
        let created = ISO8601DateFormatter().date(from: "2026-08-13T10:00:00Z")!
        try await vault.writeFile(
            Data(
                """
                ---
                id: \(bookID.uuidString.lowercased())
                type: page
                title: Ghost Author
                created: \(iso(created))
                updated: \(iso(created))
                tags: []
                properties:
                  author:
                    - missing-object-zzzz
                ---

                No wiki in body.
                """.utf8
            ),
            atRelativePath: "objects/page/ghost-author.md"
        )
        try await index.rebuild()

        let outgoing = try await index.outgoingLinks(from: ObjectID(bookID))
        XCTAssertEqual(outgoing.count, 1)
        XCTAssertEqual(outgoing.first?.target, "missing-object-zzzz")
        XCTAssertTrue(outgoing.first?.isBroken == true)
    }
}
