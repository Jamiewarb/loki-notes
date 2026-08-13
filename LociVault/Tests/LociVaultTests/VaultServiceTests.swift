import XCTest
import LociCore
@testable import LociVault

final class VaultServiceTests: XCTestCase {
    private var tempParent: URL!

    override func setUpWithError() throws {
        tempParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-vault-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempParent, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempParent {
            try? FileManager.default.removeItem(at: tempParent)
        }
    }

    func testResolveLocalRootCreatesLociVaultDirectory() throws {
        let root = try VaultRoot.resolve(preferredLocalDirectory: tempParent, forceLocal: true)
        XCTAssertEqual(root.kind, .localDocuments)
        XCTAssertTrue(root.url.lastPathComponent == "LociVault")
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.url.path))
    }

    func testEnsureSkeletonCreatesExpectedLayoutAndSpaceJSON() async throws {
        let service = try VaultService(preferredLocalDirectory: tempParent, forceLocal: true)
        try await service.ensureSkeleton(spaceName: "Test Space")

        for dir in VaultLayout.requiredDirectories {
            let exists = try await service.fileExists(atRelativePath: dir)
            // fileExists on directories: FileManager.fileExists returns true for dirs too
            let url = try await service.absoluteURL(forRelativePath: dir)
            var isDir: ObjCBool = false
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir),
                "missing \(dir)"
            )
            XCTAssertTrue(isDir.boolValue, "\(dir) should be a directory")
            _ = exists
        }

        let data = try await service.readFile(atRelativePath: VaultLayout.spaceJSON)
        let settings = try JSONDecoder().decode(SpaceSettings.self, from: data)
        XCTAssertEqual(settings.name, "Test Space")
        XCTAssertEqual(settings.schemaVersion, 1)

        let pageExists = try await service.fileExists(
            atRelativePath: SchemaStore.typeRelativePath(for: .page)
        )
        XCTAssertTrue(pageExists, "ensureSkeleton should seed .loci/types/page.json")
        let dailyExists = try await service.fileExists(
            atRelativePath: SchemaStore.typeRelativePath(for: .daily)
        )
        XCTAssertTrue(dailyExists, "ensureSkeleton should seed .loci/types/daily.json")
        let imageExists = try await service.fileExists(
            atRelativePath: SchemaStore.typeRelativePath(for: .image)
        )
        XCTAssertTrue(imageExists, "ensureSkeleton should seed .loci/types/image.json")
        let meetingExists = try await service.fileExists(
            atRelativePath: SchemaStore.typeRelativePath(for: .meeting)
        )
        XCTAssertTrue(meetingExists, "ensureSkeleton should seed .loci/types/meeting.json")

        // Idempotent — second call does not wipe space.json
        try await service.ensureSkeleton(spaceName: "Other")
        let again = try await service.readFile(atRelativePath: VaultLayout.spaceJSON)
        let settings2 = try JSONDecoder().decode(SpaceSettings.self, from: again)
        XCTAssertEqual(settings2.name, "Test Space")
    }

    func testCoordinatedWriteAndReadRoundTrip() async throws {
        let service = try VaultService(preferredLocalDirectory: tempParent, forceLocal: true)
        try await service.ensureSkeleton()

        let relative = "daily/2026-08-13.md"
        let payload = Data("# Hello vault\n".utf8)
        try await service.writeFile(payload, atRelativePath: relative)

        let exists = try await service.fileExists(atRelativePath: relative)
        XCTAssertTrue(exists)
        let read = try await service.readFile(atRelativePath: relative)
        XCTAssertEqual(read, payload)
    }

    func testTrashMovesFileAndWritesTombstone() async throws {
        let service = try VaultService(preferredLocalDirectory: tempParent, forceLocal: true)
        try await service.ensureSkeleton()

        let relative = "objects/page/note.md"
        try await service.writeFile(Data("body".utf8), atRelativePath: relative)

        let record = try await service.trashFile(atRelativePath: relative, objectID: nil)
        XCTAssertEqual(record.originalRelativePath, relative)
        let gone = try await service.fileExists(atRelativePath: relative)
        XCTAssertFalse(gone)
        let trashed = try await service.fileExists(atRelativePath: record.trashedRelativePath)
        XCTAssertTrue(trashed)

        let store = TombstoneStore(root: try await service.vaultRootURL)
        let manifests = try store.listManifests()
        XCTAssertEqual(manifests.count, 1)
        XCTAssertEqual(manifests[0].originalRelativePath, relative)
    }

    func testRejectsPathTraversal() async throws {
        let service = try VaultService(preferredLocalDirectory: tempParent, forceLocal: true)
        try await service.ensureSkeleton()

        do {
            _ = try await service.readFile(atRelativePath: "../outside.txt")
            XCTFail("expected invalidRelativePath")
        } catch let error as LociError {
            guard case .invalidRelativePath = error else {
                return XCTFail("wrong error \(error)")
            }
        }
    }

    func testIndexMustNotLiveInVaultConvention() async throws {
        // Guardrail: VaultService never writes index.sqlite under the vault.
        let service = try VaultService(preferredLocalDirectory: tempParent, forceLocal: true)
        try await service.ensureSkeleton()
        let root = try await service.vaultRootURL
        let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        var foundIndex = false
        while let url = enumerator?.nextObject() as? URL {
            if url.lastPathComponent == "index.sqlite" {
                foundIndex = true
            }
        }
        XCTAssertFalse(foundIndex)
    }

    func testRootKindIsLocalOnForcedLocal() async throws {
        let service = try VaultService(preferredLocalDirectory: tempParent, forceLocal: true)
        let kind = await service.rootKind
        XCTAssertEqual(kind, .localDocuments)
    }
}

final class ConflictedCopyDetectorTests: XCTestCase {
    func testDetectsConflictedCopyPhrase() {
        XCTAssertTrue(
            ConflictedCopyDetector.isConflictedCopy(
                pathOrFilename: "Note (Conflicted copy from MacBook Pro).md"
            )
        )
    }

    func testDetectsNumberedConflict() {
        XCTAssertTrue(ConflictedCopyDetector.isConflictedCopy(pathOrFilename: "Daily 2.md"))
        XCTAssertFalse(ConflictedCopyDetector.isConflictedCopy(pathOrFilename: "Daily.md"))
        XCTAssertFalse(ConflictedCopyDetector.isConflictedCopy(pathOrFilename: "chapter 2 notes.md"))
    }
}

final class MetadataMonitorTests: XCTestCase {
    final class Box: @unchecked Sendable {
        var event: VaultFileEvent?
        var events: [VaultFileEvent] = []
    }

    func testNoteLocalWriteEmitsEvent() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-mon-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let monitor = MetadataQueryMonitor(root: temp)
        let exp = expectation(description: "event")
        let box = Box()
        monitor.start { event in
            box.event = event
            exp.fulfill()
        }
        monitor.noteLocalWrite(relativePath: "daily/x.md", kind: .created)
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(box.event?.relativePath, "daily/x.md")
        XCTAssertEqual(box.event?.kind, .created)
        monitor.stop()
    }

    func testPollNowDetectsNewFile() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-poll-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let monitor = MetadataQueryMonitor(root: temp)
        let box = Box()
        monitor.start { box.events.append($0) }

        let file = temp.appendingPathComponent("hello.md")
        try Data("hi".utf8).write(to: file)
        monitor.pollNow()

        XCTAssertTrue(box.events.contains { $0.relativePath == "hello.md" && $0.kind == .created })
        monitor.stop()
    }
}

final class ModuleVersionTests: XCTestCase {
    func testVersionPresent() {
        XCTAssertTrue(
            LociVaultModule.version.contains("pr13")
                || LociVaultModule.version.contains("pr14")
                || LociVaultModule.version.contains("pr15")
                || LociVaultModule.version.contains("pr17")
                || LociVaultModule.version.contains("pr18") || LociVaultModule.version.contains("pr19") || LociVaultModule.version.contains("pr20") || LociVaultModule.version.contains("pr21") || LociVaultModule.version.contains("pr22") || LociVaultModule.version.contains("pr23") || LociVaultModule.version.contains("pr24") || LociVaultModule.version.contains("pr25") || LociVaultModule.version.contains("pr26") || LociVaultModule.version.contains("pr27") || LociVaultModule.version.contains("pr28") || LociVaultModule.version.contains("pr29") || LociVaultModule.version.contains("pr30") || LociVaultModule.version.contains("pr31") || LociVaultModule.version.contains("pr32") || LociVaultModule.version.contains("pr34") || LociVaultModule.version.contains("pr35") || LociVaultModule.version.contains("pr36") || LociVaultModule.version.contains("pr37") || LociVaultModule.version.contains("pr38") || LociVaultModule.version.contains("pr39") || LociVaultModule.version.contains("pr40") || LociVaultModule.version.contains("pr41") || LociVaultModule.version.contains("pr42") || LociVaultModule.version.contains("pr43") || LociVaultModule.version.contains("pr44")
        )
    }
}
