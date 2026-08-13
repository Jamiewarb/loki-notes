import XCTest
import Foundation
import LociCore
import LociVault
import LociMarkdown
import LociIndex

final class PARAPackTests: XCTestCase {
    private var vaultParent: URL!
    private var indexParent: URL!
    private var vault: VaultService!
    private var schema: SchemaStore!
    private var index: IndexService!
    private var objects: ObjectService!

    override func setUpWithError() throws {
        let stamp = UUID().uuidString
        vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-para-vault-\(stamp)", isDirectory: true)
        indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-para-db-\(stamp)", isDirectory: true)
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
        try await schema.bootstrapSchema(spaceName: "PARA Test")
        index = try await IndexService(vault: vault, indexDirectory: indexParent)
        objects = ObjectService(vault: vault, index: index, schema: schema)
    }

    func testApplyCreatesProjectAreaTemplatesAndGuidance() async throws {
        try await boot()
        let result = try await PARAPack.apply(to: schema)

        XCTAssertEqual(result.projectTypeID, "project")
        XCTAssertEqual(result.areaTypeID, "area")
        XCTAssertEqual(result.projectTemplateID, "project.default")
        XCTAssertEqual(result.areaTemplateID, "area.default")
        XCTAssertTrue(result.createdTypeIDs.contains("project"))
        XCTAssertTrue(result.createdTypeIDs.contains("area"))
        XCTAssertEqual(result.resourceApproach, "tag:#resource")
        XCTAssertEqual(result.archiveApproach, "tag:#archive")
        XCTAssertTrue(result.hideArchived)

        let project = try await schema.loadType(.project)
        XCTAssertEqual(project.name, "Project")
        XCTAssertEqual(project.defaultTemplateID, "project.default")
        XCTAssertTrue(project.dashboard.hideArchived)
        XCTAssertTrue(project.properties.contains { $0.id == "status" })
        XCTAssertTrue(project.properties.contains { $0.id == "deadline" })

        let area = try await schema.loadType(.area)
        XCTAssertEqual(area.name, "Area")
        XCTAssertEqual(area.defaultTemplateID, "area.default")
        XCTAssertTrue(area.properties.contains { $0.id == "review" })

        let projectTpl = try await schema.loadTemplate("project.default")
        XCTAssertTrue(projectTpl.bodyMarkdown.contains("## Outcome"))
        XCTAssertEqual(projectTpl.defaultProperties["status"], .select("Active"))

        let areaTpl = try await schema.loadTemplate("area.default")
        XCTAssertTrue(areaTpl.bodyMarkdown.contains("## Standards"))

        let space = try await schema.loadSpaceSettings()
        XCTAssertTrue(space.paraPackApplied)
        XCTAssertTrue(space.hideArchived)
        XCTAssertEqual(space.resourceApproach, "tag:#resource")

        // No Resource type — tag approach.
        let ids = try await schema.knownTypeIDs()
        XCTAssertFalse(ids.contains(ObjectTypeID("resource")))
    }

    func testApplyIsIdempotent() async throws {
        try await boot()
        let first = try await PARAPack.apply(to: schema)
        XCTAssertTrue(first.createdTypeIDs.contains("project"))

        let second = try await PARAPack.apply(to: schema)
        XCTAssertTrue(second.createdTypeIDs.isEmpty)
        XCTAssertTrue(second.skippedTemplateIDs.contains("project.default"))
        XCTAssertTrue(second.skippedTemplateIDs.contains("area.default"))

        let types = try await schema.knownTypeIDs()
        XCTAssertEqual(types.filter { $0 == .project || $0 == .area }.count, 2)

        let project = try await schema.loadType(.project)
        XCTAssertEqual(project.defaultTemplateID, "project.default")
    }

    func testProjectCreatePrefillsTemplate() async throws {
        try await boot()
        _ = try await PARAPack.apply(to: schema)
        let meta = try await objects.create(typeID: .project, title: "Ship PARA")
        let opened = try await objects.open(id: meta.id)
        XCTAssertTrue(opened.bodyMarkdown.contains("## Outcome"))
        XCTAssertTrue(opened.bodyMarkdown.contains("## Next actions"))
        XCTAssertEqual(opened.meta.properties["status"], .select("Active"))
    }

    func testArchiveFilterByTagAndStatus() {
        let active = LociObjectMeta(
            id: ObjectID(),
            typeID: .project,
            title: "Active",
            relativePath: "objects/project/a.md",
            tags: ["resource"],
            properties: ["status": .select("Active")]
        )
        let byTag = LociObjectMeta(
            id: ObjectID(),
            typeID: .project,
            title: "Old",
            relativePath: "objects/project/b.md",
            tags: ["#archive"],
            properties: [:]
        )
        let byStatus = LociObjectMeta(
            id: ObjectID(),
            typeID: .area,
            title: "Paused area",
            relativePath: "objects/area/c.md",
            tags: [],
            properties: ["status": .select("Archived")]
        )

        XCTAssertFalse(ArchiveFilter.isArchived(active))
        XCTAssertTrue(ArchiveFilter.isArchived(byTag))
        XCTAssertTrue(ArchiveFilter.isArchived(byStatus))

        let visible = ArchiveFilter.visible([active, byTag, byStatus], hideArchived: true)
        XCTAssertEqual(visible.count, 1)
        XCTAssertEqual(visible.first?.title, "Active")
    }

    func testModuleVersionPR15() {
        XCTAssertTrue(LociVaultModule.version.contains("pr15") || LociVaultModule.version.contains("pr16") || LociVaultModule.version.contains("pr17") || LociVaultModule.version.contains("pr18"))
        XCTAssertTrue(LociIndexModule.version.contains("pr15") || LociIndexModule.version.contains("pr17") || LociIndexModule.version.contains("pr18"))
    }
}
