import Foundation
import LociCore
import LociVault
import LociIndex

/// CLI: Type conversion proof for DevHarness (PR28).
@main
struct LociTypeConvertDemo {
    static func main() async throws {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-convert-demo-vault-\(stamp)", isDirectory: true)
        let indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-convert-demo-db-\(stamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: indexParent, withIntermediateDirectories: true)

        let vault = try VaultService(preferredLocalDirectory: vaultParent, forceLocal: true)
        let schema = SchemaStore(vault: vault)
        try await schema.bootstrapSchema(spaceName: "Demo Convert")

        let index = try await IndexService(vault: vault, indexDirectory: indexParent)
        let objects = ObjectService(vault: vault, index: index, schema: schema)

        let book = try await schema.createType(
            name: "Books",
            icon: "book",
            color: "#8B5A2B",
            slug: "book"
        )
        let person = try await schema.createType(
            name: "People",
            icon: "person",
            color: "#2B5A8B",
            slug: "person"
        )
        _ = try await schema.setProperties(
            book.id,
            properties: [
                PropertyDef(
                    id: "status",
                    name: "Status",
                    kind: .select,
                    options: ["To Read", "Reading", "Done"]
                ),
                PropertyDef(id: "rating", name: "Rating", kind: .number),
                PropertyDef(id: "isbn", name: "ISBN", kind: .text),
            ]
        )
        _ = try await schema.setProperties(
            person.id,
            properties: [
                PropertyDef(
                    id: "status",
                    name: "Status",
                    kind: .select,
                    options: ["Active", "Archived"]
                ),
                PropertyDef(id: "score", name: "Rating", kind: .number),
                PropertyDef(id: "role", name: "Role", kind: .text),
            ]
        )

        var meta = try await objects.create(typeID: book.id, title: "Deep Work")
        let stableID = meta.id
        meta.properties = [
            "status": .select("Reading"),
            "rating": .number(5),
            "isbn": .text("978-1"),
        ]
        try await objects.save(
            meta: meta,
            bodyMarkdown: "Focus is a skill.\n\nSee also [[focus]].\n"
        )
        let oldPath = meta.relativePath

        let plan = try await objects.planConversion(id: stableID, toTypeID: person.id)
        let result = try await objects.convert(
            id: stableID,
            toTypeID: person.id,
            propertyMap: plan.mappings
        )
        let opened = try await objects.open(id: stableID)
        let indexed = try await index.object(id: stableID)

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

        var proof: [String: Bool] = [:]
        proof["idStable"] = result.objectID == stableID && opened.meta.id == stableID
        proof["movedFolder"] =
            oldPath.hasPrefix("objects/book/")
            && result.newRelativePath.hasPrefix("objects/person/")
        proof["oldPathGone"] = !(try await vault.fileExists(atRelativePath: oldPath))
        proof["newPathExists"] = try await vault.fileExists(atRelativePath: result.newRelativePath)
        proof["statusMapped"] = opened.meta.properties["status"] == .select("Reading")
        proof["ratingToScore"] = opened.meta.properties["score"] == .number(5)
        proof["isbnDropped"] = opened.meta.properties["isbn"] == nil
        proof["indexTypeUpdated"] = indexed?.typeID == person.id
        proof["indexPathUpdated"] = indexed?.relativePath == result.newRelativePath
        proof["indexOutsideVault"] = !sqliteInVault
        proof["planDroppedISBN"] = plan.droppedPropertyIDs.contains("isbn")

        // Refuse daily
        var refusedDaily = false
        do {
            _ = try await objects.convert(id: stableID, toTypeID: .daily, propertyMap: [])
        } catch let error as LociError {
            if case .typeConversionNotAllowed = error { refusedDaily = true }
        }
        proof["refusedDaily"] = refusedDaily

        let payload: [String: Any] = [
            "moduleVersion": LociVaultModule.version,
            "indexModuleVersion": LociIndexModule.version,
            "indexInsideVault": sqliteInVault,
            "object": [
                "id": stableID.uuidString.lowercased(),
                "title": opened.meta.title,
                "sourceType": result.sourceTypeID.rawValue,
                "targetType": result.targetTypeID.rawValue,
                "oldPath": result.oldRelativePath,
                "newPath": result.newRelativePath,
                "mappedCount": result.mappedPropertyCount,
                "droppedCount": result.droppedPropertyCount,
                "properties": opened.meta.properties.mapValues { PropertyValueFormatting.displayString($0) },
            ],
            "plan": [
                "proposedPath": plan.proposedRelativePath,
                "dropped": plan.droppedPropertyIDs,
                "mappings": plan.mappings.map { map -> [String: String] in
                    [
                        "source": map.sourcePropertyID,
                        "target": map.targetPropertyID ?? "(drop)",
                    ]
                },
            ],
            "proof": proof,
            "note":
                "PR28: Type conversion remaps PropertyDefs, moves objects/<type>/, keeps ObjectID, reindexes. Daily notes refused.",
        ]

        let data = try JSONSerialization.data(
            withJSONObject: payload,
            options: [.prettyPrinted, .sortedKeys]
        )
        if let text = String(data: data, encoding: .utf8) {
            print(text)
        }
    }
}
