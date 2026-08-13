import XCTest
import Foundation
import LociCore
import LociVault
@testable import LociIndex

final class SearchQueryTests: XCTestCase {
    func testFTSMatchQueryEscapesAndPrefixes() {
        XCTAssertEqual(SearchQuery.ftsMatchQuery("focus"), "\"focus\"*")
        XCTAssertEqual(SearchQuery.ftsMatchQuery("deep work"), "\"deep\"* \"work\"*")
        XCTAssertEqual(SearchQuery.ftsMatchQuery("  "), "\"\"")
        // Quotes escaped for MATCH safety
        XCTAssertEqual(SearchQuery.ftsMatchQuery("say \"hi\""), "\"say\"* \"hi\"*")
    }

    func testTitleAndBodyHitsViaIndex() async throws {
        let stamp = UUID().uuidString
        let vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-search-vault-\(stamp)", isDirectory: true)
        let indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-search-db-\(stamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: indexParent, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: vaultParent)
            try? FileManager.default.removeItem(at: indexParent)
        }

        let vault = try VaultService(preferredLocalDirectory: vaultParent, forceLocal: true)
        try await vault.ensureSkeleton(spaceName: "Search Test")
        let index = try await IndexService(vault: vault, indexDirectory: indexParent)

        let titleID = UUID(uuidString: "11111111-aaaa-4aaa-8aaa-111111111111")!
        let bodyID = UUID(uuidString: "22222222-bbbb-4bbb-8bbb-222222222222")!
        let created = ISO8601DateFormatter().date(from: "2026-08-13T10:00:00Z")!
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]

        let titleMD = """
            ---
            id: \(titleID.uuidString.lowercased())
            type: page
            title: Focus Rituals
            created: \(iso.string(from: created))
            updated: \(iso.string(from: created))
            tags: []
            ---

            Morning pages without the keyword in body alone.
            """
        let bodyMD = """
            ---
            id: \(bodyID.uuidString.lowercased())
            type: page
            title: Unrelated Title
            created: \(iso.string(from: created))
            updated: \(iso.string(from: created))
            tags: []
            ---

            Deep notes about focus practice in the body.
            """
        try await vault.writeFile(Data(titleMD.utf8), atRelativePath: "objects/page/focus-rituals.md")
        try await vault.writeFile(Data(bodyMD.utf8), atRelativePath: "objects/page/unrelated.md")
        try await index.rebuild()

        let hits = try await index.search(query: "focus")
        XCTAssertEqual(Set(hits.map { $0.id.uuidString.lowercased() }), Set([
            titleID.uuidString.lowercased(),
            bodyID.uuidString.lowercased(),
        ]))

        let polished = SearchRanking.preferTitleMatches(hits, query: "focus")
        XCTAssertEqual(polished.first?.title, "Focus Rituals")
        let groups = SearchGrouping.byType(polished)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.first?.typeID, .page)
    }
}
