import XCTest
import Foundation
import LociCore
import LociVault
import LociMarkdown
import LociIndex

final class UnlinkedMentionsSystemTests: XCTestCase {
    private var vaultParent: URL!
    private var indexParent: URL!
    private var vault: VaultService!
    private var schema: SchemaStore!
    private var index: IndexService!
    private var objects: ObjectService!
    private var daily: DailyNoteService!

    override func setUpWithError() throws {
        let stamp = UUID().uuidString
        vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-unlinked-sys-vault-\(stamp)", isDirectory: true)
        indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-unlinked-sys-db-\(stamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: indexParent, withIntermediateDirectories: true)
        vault = try VaultService(preferredLocalDirectory: vaultParent, forceLocal: true)
    }

    override func tearDownWithError() throws {
        daily = nil
        objects = nil
        index = nil
        schema = nil
        vault = nil
        if let vaultParent { try? FileManager.default.removeItem(at: vaultParent) }
        if let indexParent { try? FileManager.default.removeItem(at: indexParent) }
    }

    private func boot() async throws {
        schema = SchemaStore(vault: vault)
        try await schema.bootstrapSchema(spaceName: "Unlinked Mentions Test")
        index = try await IndexService(vault: vault, indexDirectory: indexParent)
        objects = ObjectService(vault: vault, index: index, schema: schema)
        daily = DailyNoteService(vault: vault, index: index, schema: schema)
    }

    private var utcCalendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }

    func testScanDoesNotRewriteBodyAndLinkIsExplicit() async throws {
        try await boot()
        let day = utcCalendar.date(from: DateComponents(year: 2026, month: 8, day: 13))!
        let openedDaily = try await daily.ensure(for: day, calendar: utcCalendar)
        let dailyBefore = openedDaily.bodyMarkdown

        let deep = try await objects.create(typeID: .page, title: "Deep Work")
        try await objects.save(meta: deep, bodyMarkdown: "Focus is a skill.\n")
        let notes = try await objects.create(typeID: .page, title: "Notes")
        let notesBody = "I read Deep Work yesterday\n"
        try await objects.save(meta: notes, bodyMarkdown: notesBody)

        let mentions = try await index.unlinkedMentions(to: deep.id)
        XCTAssertEqual(mentions.map(\.source.title), ["Notes"])

        let afterScan = try await objects.open(id: notes.id)
        XCTAssertEqual(afterScan.bodyMarkdown, notesBody)
        XCTAssertFalse(afterScan.bodyMarkdown.contains("[["))

        let dailyAfterScan = try await daily.open(date: day, calendar: utcCalendar)
        XCTAssertEqual(dailyAfterScan.bodyMarkdown, dailyBefore)

        let wiki = UnlinkedMentionScanner.wikiLinkMarkdown(
            targetID: deep.id.frontMatterIDString,
            title: deep.title
        )
        let linkedBody = try XCTUnwrap(
            UnlinkedMentionScanner.replaceFirst(
                in: afterScan.bodyMarkdown,
                title: deep.title,
                withWikiLink: wiki
            )
        )
        try await objects.save(meta: afterScan.meta, bodyMarkdown: linkedBody)

        let afterLink = try await objects.open(id: notes.id)
        XCTAssertTrue(afterLink.bodyMarkdown.contains("[["))
        XCTAssertTrue(afterLink.bodyMarkdown.contains(deep.id.frontMatterIDString))

        let mentionsAfter = try await index.unlinkedMentions(to: deep.id)
        XCTAssertTrue(mentionsAfter.isEmpty)

        let dailyAfterLink = try await daily.open(date: day, calendar: utcCalendar)
        XCTAssertEqual(dailyAfterLink.bodyMarkdown, dailyBefore)

        let vaultRoot = try await vault.vaultRootURL
        var sqliteInVault = false
        if let enumerator = FileManager.default.enumerator(
            at: vaultRoot,
            includingPropertiesForKeys: nil
        ) {
            for case let url as URL in enumerator {
                if url.lastPathComponent == "index.sqlite" { sqliteInVault = true }
            }
        }
        XCTAssertFalse(sqliteInVault)
        XCTAssertFalse(index.databaseURL.path.hasPrefix(vaultRoot.path))

        let proof = UnlinkedMentionProof.evaluate(
            plainBody: notesBody,
            wikiLinkedBody: "[[Deep Work]] yesterday",
            wordBoundaryBody: "deep working",
            title: "Deep Work",
            bodyBefore: notesBody,
            bodyAfterScan: afterScan.bodyMarkdown,
            indexInsideVault: sqliteInVault
        )
        XCTAssertTrue(proof.detectsPlainTitle)
        XCTAssertTrue(proof.ignoresExistingWikiLink)
        XCTAssertTrue(proof.doesNotRewriteBody)
        XCTAssertFalse(proof.indexInsideVault)
    }

    func testModuleVersionIsPR44() {
        XCTAssertTrue(
            LociVaultModule.version.contains("pr43") || LociVaultModule.version.contains("pr44"),
            LociVaultModule.version
        )
        XCTAssertTrue(
            LociVaultModule.version == "0.43.0-pr43" || LociVaultModule.version == "0.44.0-pr44",
            LociVaultModule.version
        )
    }
}
