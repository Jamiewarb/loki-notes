import Foundation
import LociCore
import LociVault
import LociIndex
import LociMarkdown

/// CLI: AI assist fixtures for DevHarness (PR30).
@main
struct LociAIDemo {
    static func main() async throws {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-ai-demo-vault-\(stamp)", isDirectory: true)
        let indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-ai-demo-db-\(stamp)", isDirectory: true)
        let aiParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-ai-demo-settings-\(stamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: indexParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: aiParent, withIntermediateDirectories: true)

        let vault = try VaultService(preferredLocalDirectory: vaultParent, forceLocal: true)
        let schema = SchemaStore(vault: vault)
        try await schema.bootstrapSchema(spaceName: "Demo AI")

        let index = try await IndexService(vault: vault, indexDirectory: indexParent)
        let objects = ObjectService(vault: vault, index: index, schema: schema)
        let credentials = AICredentialStore(directory: aiParent)
        let ai = AIService(settingsDirectory: aiParent, credentials: credentials, remote: nil)

        // Fake key for vault-scan proof (must never appear in vault).
        let fakeKey = "sk-demo-fake-key-pr30-never-upload"
        try credentials.setAPIKey(fakeKey, for: "openai")

        let book = try await schema.createType(
            name: "Books",
            icon: "book",
            color: "#0F6B5C",
            slug: "book"
        )
        try await schema.setProperties(
            book.id,
            properties: [
                PropertyDef(id: "url", name: "URL", kind: .url),
                PropertyDef(id: "status", name: "Status", kind: .select, options: ["Draft", "Read"]),
            ]
        )

        var page = try await objects.create(typeID: .page, title: "hello world meeting")
        let pageBody = """
        Hello world and the book today.

        See https://example.com/ai-demo on 2024-08-13. Status is Draft #inbox.

        This is very really just a long note with filler.
        """
        try await objects.save(meta: page, bodyMarkdown: pageBody)
        page = try await objects.open(id: page.id).meta

        var bookObj = try await objects.create(typeID: book.id, title: "Design Patterns")
        let bookBody = """
        A book about software. Visit https://example.com/patterns — Read complete on 2024-07-01. #books
        """
        try await objects.save(meta: bookObj, bodyMarkdown: bookBody)
        bookObj = try await objects.open(id: bookObj.id).meta
        let bookType = try await schema.loadType(book.id)

        let summarize = try await ai.run(
            AIRequest(
                action: .summarize,
                objectID: page.id,
                title: page.title,
                bodyMarkdown: pageBody
            )
        )
        let rewrite = try await ai.run(
            AIRequest(
                action: .rewrite,
                objectID: page.id,
                title: page.title,
                bodyMarkdown: pageBody
            )
        )
        let translate = try await ai.run(
            AIRequest(
                action: .translate,
                objectID: page.id,
                title: page.title,
                bodyMarkdown: "hello world and the book today",
                targetLanguage: "es"
            )
        )
        let autofill = try await ai.run(
            AIRequest(
                action: .autofillProperties,
                objectID: bookObj.id,
                title: bookObj.title,
                bodyMarkdown: bookBody,
                propertyDefs: bookType.properties,
                existingProperties: bookObj.properties
            )
        )

        // BYOK without opt-in → refuse
        try await ai.saveSettings(
            AISettings(
                preferredProvider: .byok,
                uploadVaultOptIn: false,
                byokProviderName: "openai"
            )
        )
        var uploadRefused = false
        do {
            _ = try await ai.run(
                AIRequest(
                    action: .summarize,
                    objectID: page.id,
                    title: page.title,
                    bodyMarkdown: pageBody,
                    allowRemoteUpload: true
                )
            )
        } catch LociError.aiUploadNotAllowed {
            uploadRefused = true
        }

        // Restore on-device for apply
        try await ai.saveSettings(AISettings())

        let applied = try await ai.apply(autofill, using: objects)

        try await index.rebuild()

        let vaultRoot = try await vault.vaultRootURL
        var sqliteInVault = false
        var credentialsInVault = false
        var keyInVault = false
        if let enumerator = FileManager.default.enumerator(
            at: vaultRoot,
            includingPropertiesForKeys: nil
        ) {
            for case let url as URL in enumerator {
                if url.lastPathComponent == "index.sqlite" { sqliteInVault = true }
                if url.lastPathComponent == "credentials.json" { credentialsInVault = true }
                if let data = try? Data(contentsOf: url),
                    let text = String(data: data, encoding: .utf8),
                    text.contains(fakeKey)
                {
                    keyInVault = true
                }
            }
        }

        let settingsOutside =
            !ai.settingsFileURL.path.hasPrefix(vaultRoot.path + "/")
            && !ai.settingsFileURL.path.hasPrefix(vaultRoot.path)
        let credentialsOutside =
            !credentials.credentialsFileURL.path.hasPrefix(vaultRoot.path + "/")

        func proposalJSON(_ p: AIProposal) -> [String: Any] {
            var d: [String: Any] = [
                "action": p.action.rawValue,
                "objectId": p.objectID.frontMatterIDString,
                "provider": p.provider.rawValue,
                "uploaded": p.uploaded,
                "notes": p.notes,
            ]
            if let s = p.summary { d["summary"] = s }
            if let b = p.proposedBody { d["proposedBody"] = b }
            if let props = p.proposedProperties {
                var map: [String: String] = [:]
                for (k, v) in props {
                    map[k] = String(describing: v)
                }
                d["proposedProperties"] = map
            }
            return d
        }

        let payload: [String: Any] = [
            "moduleVersion": LociVaultModule.version,
            "indexModuleVersion": LociIndexModule.version,
            "markdownModuleVersion": LociMarkdownModule.version,
            "indexInsideVault": sqliteInVault,
            "credentialsInsideVault": credentialsInVault || keyInVault,
            "settingsOutsideVault": settingsOutside,
            "credentialsOutsideVault": credentialsOutside,
            "page": [
                "id": page.id.frontMatterIDString,
                "path": page.relativePath,
                "title": page.title,
            ],
            "book": [
                "id": bookObj.id.frontMatterIDString,
                "path": bookObj.relativePath,
                "title": bookObj.title,
                "appliedUrl": String(describing: applied.meta.properties["url"] ?? .null),
                "appliedStatus": String(describing: applied.meta.properties["status"] ?? .null),
            ],
            "summarize": proposalJSON(summarize),
            "rewrite": proposalJSON(rewrite),
            "translate": proposalJSON(translate),
            "autofill": proposalJSON(autofill),
            "uploadRefusedWithoutOptIn": uploadRefused,
            "proof": [
                "uploadRefusedWithoutOptIn": uploadRefused,
                "summarize": summarize.summary?.hasPrefix("Summary: ") == true
                    && summarize.uploaded == false,
                "rewrite": (rewrite.proposedBody?.contains("very ") != true)
                    && rewrite.uploaded == false,
                "translate": translate.proposedBody?.contains("hola") == true
                    && translate.proposedBody?.contains("<!-- loci-ai:translated:es -->") == true,
                "autofill": autofill.proposedProperties != nil,
                "applyViaObjectServing": applied.meta.properties["url"] != nil
                    && applied.meta.relativePath.hasPrefix("objects/book/"),
                "indexOutsideVault": !sqliteInVault,
                "credentialsOutsideVault": credentialsOutside && !keyInVault,
            ],
            "note":
                "PR30: On-device heuristics + BYOK opt-in. Credentials/settings in Application Support. Apply via ObjectServing only.",
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
