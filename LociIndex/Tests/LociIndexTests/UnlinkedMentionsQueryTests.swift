import XCTest
import Foundation
import LociCore
import LociVault
import LociMarkdown
@testable import LociIndex

final class UnlinkedMentionsQueryTests: XCTestCase {
    private var vaultParent: URL!
    private var indexParent: URL!
    private var vault: VaultService!
    private var index: IndexService!

    override func setUpWithError() throws {
        let stamp = UUID().uuidString
        vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-unlinked-vault-\(stamp)", isDirectory: true)
        indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-unlinked-db-\(stamp)", isDirectory: true)
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
        try await vault.ensureSkeleton(spaceName: "Unlinked Mentions")
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

    func testPlainTitleMentionIsUnlinkedAndWikiLinkIsNot() async throws {
        try await boot()
        let deepID = UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1")!
        let notesID = UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2")!
        let linkedID = UUID(uuidString: "cccccccc-cccc-4ccc-8ccc-ccccccccccc3")!
        let workingID = UUID(uuidString: "dddddddd-dddd-4ddd-8ddd-ddddddddddd4")!

        try await writePage(
            id: deepID,
            title: "Deep Work",
            path: "objects/page/deep-work.md",
            body: "Focus is a skill."
        )
        try await writePage(
            id: notesID,
            title: "Notes",
            path: "objects/page/notes.md",
            body: "I read Deep Work yesterday"
        )
        try await writePage(
            id: linkedID,
            title: "Journal",
            path: "objects/page/journal.md",
            body: "See [[\(deepID.uuidString.lowercased())|Deep Work]] yesterday"
        )
        try await writePage(
            id: workingID,
            title: "Stem",
            path: "objects/page/stem.md",
            body: "I was deep working all afternoon."
        )
        try await index.rebuild()

        let mentions = try await index.unlinkedMentions(to: ObjectID(deepID))
        XCTAssertEqual(mentions.map(\.source.title), ["Notes"])
        XCTAssertEqual(mentions.first?.source.id, ObjectID(notesID))
        XCTAssertTrue(mentions.first?.snippet.contains("Deep Work") == true)

        let notesData = try await vault.readFile(atRelativePath: "objects/page/notes.md")
        let notesText = String(data: notesData, encoding: .utf8) ?? ""
        let body = try MarkdownParser.bodyMarkdown(from: notesText)
        XCTAssertFalse(body.contains("[["), body)
        XCTAssertTrue(body.contains("Deep Work"))
    }

    func testExcludesSelfAndKeepsIndexOutsideVault() async throws {
        try await boot()
        let deepID = UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1")!
        try await writePage(
            id: deepID,
            title: "Deep Work",
            path: "objects/page/deep-work.md",
            body: "Deep Work is the title repeated in the body."
        )
        try await index.rebuild()

        let mentions = try await index.unlinkedMentions(to: ObjectID(deepID))
        XCTAssertTrue(mentions.isEmpty)

        let vaultRoot = try await vault.vaultRootURL
        XCTAssertFalse(index.databaseURL.path.hasPrefix(vaultRoot.path))
    }

    func testShortTitleYieldsNoMentions() async throws {
        try await boot()
        let id = UUID(uuidString: "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeee5")!
        try await writePage(id: id, title: "AI", path: "objects/page/ai.md", body: "AI is everywhere.")
        try await writePage(
            id: UUID(uuidString: "ffffffff-ffff-4fff-8fff-fffffffffff6")!,
            title: "Notes",
            path: "objects/page/notes.md",
            body: "Talked about AI today."
        )
        try await index.rebuild()
        let mentions = try await index.unlinkedMentions(to: ObjectID(id))
        XCTAssertTrue(mentions.isEmpty)
    }
}
