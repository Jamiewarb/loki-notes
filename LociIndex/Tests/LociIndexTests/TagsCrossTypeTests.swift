import XCTest
import Foundation
import LociCore
import LociVault
import LociMarkdown
@testable import LociIndex

final class TagsCrossTypeTests: XCTestCase {
    private var vaultParent: URL!
    private var indexParent: URL!
    private var vault: VaultService!
    private var index: IndexService!
    private var schema: SchemaStore!

    override func setUpWithError() throws {
        let stamp = UUID().uuidString
        vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-tags-vault-\(stamp)", isDirectory: true)
        indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-tags-db-\(stamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: indexParent, withIntermediateDirectories: true)
        vault = try VaultService(preferredLocalDirectory: vaultParent, forceLocal: true)
        schema = SchemaStore(vault: vault)
    }

    override func tearDownWithError() throws {
        index = nil
        schema = nil
        vault = nil
        if let vaultParent { try? FileManager.default.removeItem(at: vaultParent) }
        if let indexParent { try? FileManager.default.removeItem(at: indexParent) }
    }

    private func boot() async throws {
        try await schema.bootstrapSchema(spaceName: "Tags Test")
        _ = try await schema.createType(name: "Book", icon: "book", color: "moss", slug: "book")
        index = try await IndexService(vault: vault, indexDirectory: indexParent)
    }

    private func writeObject(
        id: UUID,
        type: String,
        title: String,
        path: String,
        frontmatterTags: [String],
        body: String
    ) async throws {
        let created = ISO8601DateFormatter().date(from: "2026-08-13T10:00:00Z")!
        let tagsYAML: String
        if frontmatterTags.isEmpty {
            tagsYAML = "[]"
        } else {
            tagsYAML = "[" + frontmatterTags.joined(separator: ", ") + "]"
        }
        let md = """
            ---
            id: \(id.uuidString.lowercased())
            type: \(type)
            title: \(title)
            created: \(iso(created))
            updated: \(iso(created))
            tags: \(tagsYAML)
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

    func testTwoTypesTaggedHealthAppearOnTagPage() async throws {
        try await boot()
        let pageID = UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1")!
        let bookID = UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2")!

        // Page: object-level frontmatter tag
        try await writeObject(
            id: pageID,
            type: "page",
            title: "Morning walk",
            path: "objects/page/morning-walk.md",
            frontmatterTags: ["health"],
            body: "Steps outside."
        )
        // Book: body #health tag (different type)
        try await writeObject(
            id: bookID,
            type: "book",
            title: "Atomic Habits",
            path: "objects/book/atomic-habits.md",
            frontmatterTags: [],
            body: "Building systems #health"
        )

        try await index.rebuild()

        let aliases = TagAliasTable.empty
        let hits = try await index.objects(tagged: "health", typeID: nil, aliases: aliases)
        XCTAssertEqual(hits.count, 2)
        let types = Set(hits.map(\.typeID.rawValue))
        XCTAssertEqual(types, Set(["page", "book"]))

        let summaries = try await index.allTags(aliases: aliases, limit: 20)
        let health = summaries.first { $0.tag == "health" }
        XCTAssertEqual(health?.count, 2)

        let pageOnly = try await index.objects(
            tagged: "#health",
            typeID: .page,
            aliases: aliases
        )
        XCTAssertEqual(pageOnly.count, 1)
        XCTAssertEqual(pageOnly.first?.title, "Morning walk")
    }

    func testTagAliasesExpandQuery() async throws {
        try await boot()
        let id = UUID(uuidString: "cccccccc-cccc-4ccc-8ccc-ccccccccccc3")!
        try await writeObject(
            id: id,
            type: "page",
            title: "Gym",
            path: "objects/page/gym.md",
            frontmatterTags: ["health"],
            body: "Lift."
        )
        try await index.rebuild()

        let aliases = TagAliasTable(aliasesByCanonical: ["health": ["wellness"]])
        let hits = try await index.objects(tagged: "wellness", typeID: nil, aliases: aliases)
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits.first?.title, "Gym")

        let collapsed = try await index.allTags(aliases: aliases, limit: 10)
        XCTAssertEqual(collapsed.first { $0.canonical == "health" }?.count, 1)
    }

    func testTagCandidatesPrefixAndNovel() async throws {
        try await boot()
        let id = UUID(uuidString: "dddddddd-dddd-4ddd-8ddd-ddddddddddd4")!
        try await writeObject(
            id: id,
            type: "page",
            title: "Focus",
            path: "objects/page/focus.md",
            frontmatterTags: ["focus"],
            body: "#career notes"
        )
        try await index.rebuild()

        let cands = try await index.tagCandidates(
            matching: "fo",
            aliases: .empty,
            limit: 10
        )
        XCTAssertTrue(cands.contains { $0.tag == "focus" })

        let novel = try await index.tagCandidates(
            matching: "brandnew",
            aliases: .empty,
            limit: 5
        )
        XCTAssertEqual(novel.first?.tag, "brandnew")
        XCTAssertEqual(novel.first?.count, 0)
    }
}
