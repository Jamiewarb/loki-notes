import Foundation
import LociCore
import LociVault
import LociMarkdown
import LociIndex

/// CLI: Person + Book author object-select → YAML ObjectIDs + real index links (PR40).
@main
struct LociObjectSelectDemo {
    struct ObjectInfo: Encodable {
        var id: String
        var type: String
        var title: String
        var relativePath: String
        var bodyMarkdown: String
    }

    struct CandidateInfo: Encodable {
        var id: String
        var title: String
        var type: String
        var relativePath: String
    }

    struct LinkInfo: Encodable {
        var sourceId: String?
        var sourceTitle: String?
        var target: String
        var label: String?
        var resolvedTitle: String?
        var isBroken: Bool?
    }

    struct Payload: Encodable {
        var moduleVersion: String
        var indexModuleVersion: String
        var vaultRoot: String
        var indexPath: String
        var indexInsideVault: Bool
        var dailyUnchanged: Bool
        var dailyPath: String
        var proof: ObjectSelectProof
        var person: ObjectInfo
        var book: ObjectInfo
        var authorIDs: [String]
        var frontmatterSnippet: String
        var bookBodyContainsWikiLink: Bool
        var yamlContainsAbsolutePath: Bool
        var candidates: [CandidateInfo]
        var backlinksOnPerson: [LinkInfo]
        var outgoingFromBook: [LinkInfo]
        var note: String
    }

    static func main() async throws {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-object-select-demo-vault-\(stamp)", isDirectory: true)
        let indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-object-select-demo-db-\(stamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: indexParent, withIntermediateDirectories: true)

        let vault = try VaultService(preferredLocalDirectory: vaultParent, forceLocal: true)
        let schema = SchemaStore(vault: vault)
        try await schema.bootstrapSchema(spaceName: "Demo Object Select")

        let personType = try await schema.createType(
            name: "Person",
            icon: "person",
            color: "#5C6B3D",
            slug: "person"
        )
        let books = try await schema.createType(
            name: "Books",
            icon: "book",
            color: "#8B5A2B",
            slug: "book"
        )
        _ = try await schema.setProperties(
            books.id,
            properties: [
                PropertyDef(id: "author", name: "Author", kind: .objectSelect),
            ]
        )

        let index = try await IndexService(vault: vault, indexDirectory: indexParent)
        let objects = ObjectService(vault: vault, index: index, schema: schema)
        let daily = DailyNoteService(vault: vault, index: index, schema: schema)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = calendar.date(from: DateComponents(year: 2026, month: 8, day: 13))!
        let openedDaily = try await daily.ensure(for: day, calendar: calendar)
        let dailyBefore = openedDaily.bodyMarkdown
        let dailyPath = openedDaily.meta.relativePath

        let person = try await objects.create(typeID: personType.id, title: "Cal Newport")
        try await objects.save(meta: person, bodyMarkdown: "Author of Deep Work.\n")

        var book = try await objects.create(typeID: books.id, title: "Deep Work")
        let authorID = person.id.frontMatterIDString
        book.properties = ["author": .objectSelect([authorID])]
        let bookBody = "Cal Newport — focus is a skill.\n"
        try await objects.save(meta: book, bodyMarkdown: bookBody)

        let reopened = try await objects.open(id: book.id)
        let stored: [String]
        if case .objectSelect(let ids) = reopened.meta.properties["author"] {
            stored = ids
        } else {
            stored = []
        }

        let mdData = try await vault.readFile(atRelativePath: reopened.meta.relativePath)
        let mdText = String(data: mdData, encoding: .utf8) ?? ""
        let snippet = frontmatterSnippet(mdText)

        let candidates = try await index.linkCandidates(
            matching: "Cal",
            excluding: book.id,
            limit: 12
        )
        let excludedAppears = candidates.contains { $0.id == book.id }

        let backs = try await index.backlinks(to: person.id)
        let outgoing = try await index.outgoingLinks(from: book.id)

        let dailyAfter = try await daily.open(date: day, calendar: calendar)
        let dailyUnchanged = dailyAfter.bodyMarkdown == dailyBefore

        let vaultRoot = try await vault.vaultRootURL
        var sqliteInVault = false
        if let enumerator = FileManager.default.enumerator(
            at: vaultRoot,
            includingPropertiesForKeys: nil
        ) {
            for case let url as URL in enumerator {
                if url.lastPathComponent == "index.sqlite" {
                    sqliteInVault = true
                    break
                }
            }
        }

        let proof = ObjectSelectProof.evaluate(
            storedIDs: stored,
            yamlSnippet: snippet,
            bodyMarkdown: reopened.bodyMarkdown,
            candidateCount: candidates.count,
            excludedObjectAppearsInCandidates: excludedAppears,
            backlinkCount: backs.count,
            outgoingCount: outgoing.count,
            indexInsideVault: sqliteInVault
        )

        let payload = Payload(
            moduleVersion: LociVaultModule.version,
            indexModuleVersion: LociIndexModule.version,
            vaultRoot: vaultRoot.path,
            indexPath: index.databaseURL.path,
            indexInsideVault: sqliteInVault,
            dailyUnchanged: dailyUnchanged,
            dailyPath: dailyPath,
            proof: proof,
            person: ObjectInfo(
                id: person.id.frontMatterIDString,
                type: person.typeID.rawValue,
                title: person.title,
                relativePath: person.relativePath,
                bodyMarkdown: "Author of Deep Work.\n"
            ),
            book: ObjectInfo(
                id: reopened.meta.id.frontMatterIDString,
                type: reopened.meta.typeID.rawValue,
                title: reopened.meta.title,
                relativePath: reopened.meta.relativePath,
                bodyMarkdown: reopened.bodyMarkdown
            ),
            authorIDs: stored,
            frontmatterSnippet: snippet,
            bookBodyContainsWikiLink: reopened.bodyMarkdown.contains("[["),
            yamlContainsAbsolutePath: ObjectSelectID.yamlLooksLikeAbsolutePath(snippet),
            candidates: candidates.map {
                CandidateInfo(
                    id: $0.id.frontMatterIDString,
                    title: $0.title,
                    type: $0.typeID.rawValue,
                    relativePath: $0.relativePath
                )
            },
            backlinksOnPerson: backs.map {
                LinkInfo(
                    sourceId: $0.source.id.frontMatterIDString,
                    sourceTitle: $0.source.title,
                    target: $0.target,
                    label: $0.label,
                    resolvedTitle: nil,
                    isBroken: nil
                )
            },
            outgoingFromBook: outgoing.map {
                LinkInfo(
                    sourceId: nil,
                    sourceTitle: nil,
                    target: $0.target,
                    label: $0.label,
                    resolvedTitle: $0.resolved?.title,
                    isBroken: $0.isBroken
                )
            },
            note:
                "PR40: object-select picker stores ObjectIDs in YAML and creates real index links. Body is not rewritten with [[wiki-links]]. Index never in vault."
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)
        if let text = String(data: data, encoding: .utf8) {
            print(text)
        }
    }

    private static func frontmatterSnippet(_ markdown: String) -> String {
        guard markdown.hasPrefix("---") else { return "" }
        let parts = markdown.split(separator: "---", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count >= 3 else { return String(markdown.prefix(400)) }
        return String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
