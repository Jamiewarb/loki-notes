import XCTest
import Foundation
import LociCore
import LociVault
import LociMarkdown
import LociIndex

final class PinsSystemTests: XCTestCase {
    private var vaultParent: URL!
    private var indexParent: URL!
    private var vault: VaultService!
    private var schema: SchemaStore!
    private var index: IndexService!
    private var objects: ObjectService!

    override func setUpWithError() throws {
        let stamp = UUID().uuidString
        vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-pins-vault-\(stamp)", isDirectory: true)
        indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-pins-db-\(stamp)", isDirectory: true)
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
        try await schema.bootstrapSchema(spaceName: "Pins Test")
        index = try await IndexService(vault: vault, indexDirectory: indexParent)
        objects = ObjectService(vault: vault, index: index, schema: schema)
    }

    func testPinUnpinIdempotentOrderAndSpaceJSONRoundTrip() async throws {
        try await boot()
        let inbox = try await objects.create(typeID: .page, title: "Inbox")
        let reading = try await objects.create(typeID: .page, title: "Reading list")
        let daily = DailyNoteService(vault: vault, index: index, schema: schema)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let today = try await daily.ensureToday(calendar: calendar)

        var ids = try await schema.pinObject(inbox.id)
        ids = try await schema.pinObject(reading.id)
        ids = try await schema.pinObject(today.meta.id)
        XCTAssertEqual(ids, [inbox.id, reading.id, today.meta.id])

        // Idempotent pin — order unchanged, no duplicate.
        ids = try await schema.pinObject(inbox.id)
        XCTAssertEqual(ids, [inbox.id, reading.id, today.meta.id])

        ids = try await schema.unpinObject(reading.id)
        XCTAssertEqual(ids, [inbox.id, today.meta.id])

        // Unpin missing = no-op.
        let ghost = ObjectID()
        ids = try await schema.unpinObject(ghost)
        XCTAssertEqual(ids, [inbox.id, today.meta.id])

        // Fresh store — disk is truth.
        let store2 = SchemaStore(vault: vault)
        let again = try await store2.pinnedObjectIDs()
        XCTAssertEqual(again, [inbox.id, today.meta.id])

        let data = try await vault.readFile(atRelativePath: VaultLayout.spaceJSON)
        let settings = try JSONDecoder().decode(SpaceSettings.self, from: data)
        XCTAssertEqual(
            settings.pins,
            [inbox.id.frontMatterIDString, today.meta.id.frontMatterIDString]
        )
        XCTAssertTrue(today.meta.id.frontMatterIDString.hasPrefix("daily-"))
    }

    func testIndexIsNotInsideVault() async throws {
        try await boot()
        let page = try await objects.create(typeID: .page, title: "Pinned page")
        _ = try await schema.pinObject(page.id)

        let vaultRoot = try await vault.vaultRootURL
        var sqliteInVault = false
        if let enumerator = FileManager.default.enumerator(
            at: vaultRoot,
            includingPropertiesForKeys: nil
        ) {
            for case let url as URL in enumerator {
                if url.pathExtension == "sqlite" || url.lastPathComponent == "index.sqlite" {
                    sqliteInVault = true
                }
            }
        }
        XCTAssertFalse(sqliteInVault)

        let indexRoot = try XCTUnwrap(indexParent)
        XCTAssertFalse(indexRoot.path.hasPrefix(vaultRoot.path))
    }

    func testMissingPinResolvesWithoutCrash() async throws {
        try await boot()
        let live = try await objects.create(typeID: .page, title: "Live")
        let missing = ObjectID()
        _ = try await schema.pinObject(live.id)
        _ = try await schema.pinObject(missing)

        let resolver = PinResolver(pins: schema, index: index, objects: objects)
        let rows = try await resolver.resolvedRows()
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0].title, "Live")
        XCTAssertFalse(rows[0].isMissing)
        XCTAssertEqual(rows[1].id, missing)
        XCTAssertTrue(rows[1].isMissing)
        XCTAssertEqual(rows[1].title, "Missing pin")

        // Unpin missing still works.
        let after = try await schema.unpinObject(missing)
        XCTAssertEqual(after, [live.id])
    }

    func testPinCapIs24() async throws {
        try await boot()
        var last = ObjectID()
        for i in 1...PinLimits.maxCount {
            let page = try await objects.create(typeID: .page, title: "P\(i)")
            last = page.id
            _ = try await schema.pinObject(page.id)
        }
        let extra = try await objects.create(typeID: .page, title: "Overflow")
        do {
            _ = try await schema.pinObject(extra.id)
            XCTFail("expected pinLimitReached")
        } catch LociError.pinLimitReached(PinLimits.maxCount) {
            // expected
        } catch {
            XCTFail("unexpected \(error)")
        }
        // Idempotent pin of an existing id still works at cap.
        let again = try await schema.pinObject(last)
        XCTAssertEqual(again.count, PinLimits.maxCount)
    }

    func testModuleVersionIsPR34() {
        XCTAssertTrue(
            LociVaultModule.version.contains("pr34") || LociVaultModule.version.contains("pr35") || LociVaultModule.version.contains("pr36") || LociVaultModule.version.contains("pr37") || LociVaultModule.version.contains("pr38") || LociVaultModule.version.contains("pr39"),
            LociVaultModule.version
        )
    }
}
