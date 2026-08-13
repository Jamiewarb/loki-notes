import Foundation
import LociCore
import LociVault
import LociMarkdown
import LociIndex

/// CLI: Fresh vault → Apply PARA → Project/Area ready with templates (PR15).
@main
struct LociPARADemo {
    static func main() async throws {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-para-demo-vault-\(stamp)", isDirectory: true)
        let indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-para-demo-db-\(stamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: indexParent, withIntermediateDirectories: true)

        let vault = try VaultService(preferredLocalDirectory: vaultParent, forceLocal: true)
        let schema = SchemaStore(vault: vault)
        try await schema.bootstrapSchema(spaceName: "Demo PARA")

        let first = try await PARAPack.apply(to: schema)
        let second = try await PARAPack.apply(to: schema) // idempotent

        let index = try await IndexService(vault: vault, indexDirectory: indexParent)
        let objects = ObjectService(vault: vault, index: index, schema: schema)

        let projectMeta = try await objects.create(typeID: .project, title: "Launch Loci MVP")
        let projectOpened = try await objects.open(id: projectMeta.id)

        let areaMeta = try await objects.create(typeID: .area, title: "Health")
        let areaOpened = try await objects.open(id: areaMeta.id)

        // Second project archived via tag — files stay put; filter hides it.
        let oldMeta = try await objects.create(typeID: .project, title: "Old initiative")
        let oldOpened = try await objects.open(id: oldMeta.id)
        var archived = oldOpened.meta
        archived.tags = ["archive"]
        archived.properties["status"] = .select("Archived")
        try await objects.save(
            meta: archived,
            bodyMarkdown: oldOpened.bodyMarkdown + "\n\n#archive\n"
        )

        let allProjects = try await index.objects(typeID: .project)
        let visibleProjects = ArchiveFilter.visible(allProjects, hideArchived: true)

        let vaultRoot = try await vault.vaultRootURL
        var sqliteInVault = false
        if let enumerator = FileManager.default.enumerator(at: vaultRoot, includingPropertiesForKeys: nil)
        {
            for case let url as URL in enumerator {
                if url.lastPathComponent == "index.sqlite" {
                    sqliteInVault = true
                    break
                }
            }
        }

        let projectType = try await schema.loadType(.project)
        let areaType = try await schema.loadType(.area)
        let space = try await schema.loadSpaceSettings()
        let projectTpl = try await schema.loadTemplate("project.default")
        let areaTpl = try await schema.loadTemplate("area.default")

        let projectPrefill =
            projectOpened.bodyMarkdown.contains("## Outcome")
            && projectOpened.bodyMarkdown.contains("## Next actions")
            && projectOpened.meta.properties["status"] == .select("Active")

        let areaPrefill =
            areaOpened.bodyMarkdown.contains("## Standards")
            && areaOpened.bodyMarkdown.contains("## Current focus")

        let payload: [String: Any] = [
            "moduleVersion": LociVaultModule.version,
            "indexModuleVersion": LociIndexModule.version,
            "vaultRoot": vaultRoot.path,
            "indexPath": index.databaseURL.path,
            "indexInsideVault": sqliteInVault,
            "firstApply": packDict(first),
            "secondApply": packDict(second),
            "idempotent": second.createdTypeIDs.isEmpty && second.createdTemplateIDs.isEmpty,
            "space": [
                "name": space.name,
                "paraPackApplied": space.paraPackApplied,
                "hideArchived": space.hideArchived,
                "resourceApproach": space.resourceApproach as Any,
                "archiveApproach": space.archiveApproach as Any,
            ],
            "projectType": typeDict(projectType),
            "areaType": typeDict(areaType),
            "projectTemplate": [
                "id": projectTpl.id,
                "path": SchemaStore.templateRelativePath(for: projectTpl.id),
                "bodyPreview": projectTpl.bodyMarkdown,
                "exists": true,
            ],
            "areaTemplate": [
                "id": areaTpl.id,
                "path": SchemaStore.templateRelativePath(for: areaTpl.id),
                "bodyPreview": areaTpl.bodyMarkdown,
                "exists": true,
            ],
            "projectObject": [
                "id": projectOpened.meta.id.uuidString.lowercased(),
                "title": projectOpened.meta.title,
                "relativePath": projectOpened.meta.relativePath,
                "bodyMarkdown": projectOpened.bodyMarkdown,
                "prefilled": projectPrefill,
            ],
            "areaObject": [
                "id": areaOpened.meta.id.uuidString.lowercased(),
                "title": areaOpened.meta.title,
                "relativePath": areaOpened.meta.relativePath,
                "bodyMarkdown": areaOpened.bodyMarkdown,
                "prefilled": areaPrefill,
            ],
            "archiveFilter": [
                "allProjects": allProjects.count,
                "visibleWhenHideArchived": visibleProjects.count,
                "archivedHidden": allProjects.count - visibleProjects.count,
                "noFolderMove": true,
            ],
            "resourceTypeExists": false,
            "explainer": PARAPack.explainer,
            "resourceGuidance": PARAPack.resourceGuidance,
            "archiveGuidance": PARAPack.archiveGuidance,
            "note":
                "Fresh vault → Apply PARA → Project/Area ready with templates; Resource=#resource; Archive=#archive filter (PR15).",
        ]

        let data = try JSONSerialization.data(
            withJSONObject: payload,
            options: [.prettyPrinted, .sortedKeys]
        )
        if let text = String(data: data, encoding: .utf8) {
            print(text)
        }
    }

    private static func packDict(_ r: PARAPackResult) -> [String: Any] {
        [
            "createdTypeIDs": r.createdTypeIDs,
            "createdTemplateIDs": r.createdTemplateIDs,
            "skippedTemplateIDs": r.skippedTemplateIDs,
            "projectTemplateID": r.projectTemplateID,
            "areaTemplateID": r.areaTemplateID,
            "resourceApproach": r.resourceApproach,
            "archiveApproach": r.archiveApproach,
            "hideArchived": r.hideArchived,
        ]
    }

    private static func typeDict(_ type: ObjectType) -> [String: Any] {
        [
            "id": type.id.rawValue,
            "name": type.name,
            "icon": type.icon,
            "color": type.color,
            "defaultTemplateID": type.defaultTemplateID as Any,
            "templateIDs": type.templateIDs,
            "hideArchived": type.dashboard.hideArchived,
            "properties": type.properties.map { def -> [String: Any] in
                [
                    "id": def.id,
                    "name": def.name,
                    "kind": def.kind.rawValue,
                    "options": def.options,
                ]
            },
        ]
    }
}
