import Foundation
import LociCore
import LociVault
import LociMarkdown
import LociIndex

/// CLI: unlinked title mentions (PR44).
@main
struct LociUnlinkedMentionsDemo {
    struct PageInfo: Encodable {
        var id: String
        var title: String
        var relativePath: String
        var bodyMarkdown: String
    }

    struct MentionInfo: Encodable {
        var sourceId: String
        var sourceTitle: String
        var snippet: String
    }

    struct Payload: Encodable {
        var moduleVersion: String
        var indexModuleVersion: String
        var vaultRoot: String
        var indexPath: String
        var indexInsideVault: Bool
        var dailyUnchanged: Bool
        var dailyPath: String
        var dailyBody: String
        var target: PageInfo
        var notes: PageInfo
        var journal: PageInfo
        var notesBodyContainsWikiLink: Bool
        var notesBodyAfterLink: String
        var notesBodyAfterLinkContainsWikiLink: Bool
        var mentions: [MentionInfo]
        var mentionTitles: [String]
        var mentionsAfterLink: [MentionInfo]
        var proof: UnlinkedMentionProof
        var note: String
    }

    static func main() async throws {
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(
            of: ":",
            with: "-"
        )
        let vaultParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-unlinked-demo-vault-\(stamp)", isDirectory: true)
        let indexParent = FileManager.default.temporaryDirectory
            .appendingPathComponent("loci-unlinked-demo-db-\(stamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: vaultParent, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: indexParent, withIntermediateDirectories: true)

        let vault = try VaultService(preferredLocalDirectory: vaultParent, forceLocal: true)
        let schema = SchemaStore(vault: vault)
        try await schema.bootstrapSchema(spaceName: "Demo Unlinked Mentions")

        let index = try await IndexService(vault: vault, indexDirectory: indexParent)
        let objects = ObjectService(vault: vault, index: index, schema: schema)
        let daily = DailyNoteService(vault: vault, index: index, schema: schema)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = calendar.date(from: DateComponents(year: 2026, month: 8, day: 13))!
        let openedDaily = try await daily.ensure(for: day, calendar: calendar)
        let dailyBefore = openedDaily.bodyMarkdown
        let dailyPath = openedDaily.meta.relativePath

        var deep = try await objects.create(typeID: .page, title: "Deep Work")
        try await objects.save(meta: deep, bodyMarkdown: "Focus is a skill.\n")
        deep = try await objects.open(id: deep.id).meta

        var notes = try await objects.create(typeID: .page, title: "Notes")
        let notesBody = "I read Deep Work yesterday\n"
        try await objects.save(meta: notes, bodyMarkdown: notesBody)
        let notesOpened = try await objects.open(id: notes.id)
        notes = notesOpened.meta

        var journal = try await objects.create(typeID: .page, title: "Journal")
        let journalBody =
            "See [[\(deep.id.frontMatterIDString)|Deep Work]] yesterday\n"
        try await objects.save(meta: journal, bodyMarkdown: journalBody)
        journal = try await objects.open(id: journal.id).meta

        let mentions = try await index.unlinkedMentions(to: deep.id)
        let notesAfterScan = try await objects.open(id: notes.id)

        let wiki = UnlinkedMentionScanner.wikiLinkMarkdown(
            targetID: deep.id.frontMatterIDString,
            title: deep.title
        )
        let notesAfterLinkBody = UnlinkedMentionScanner.replaceFirst(
            in: notesAfterScan.bodyMarkdown,
            title: deep.title,
            withWikiLink: wiki
        ) ?? notesAfterScan.bodyMarkdown
        try await objects.save(meta: notesAfterScan.meta, bodyMarkdown: notesAfterLinkBody)
        let mentionsAfterLink = try await index.unlinkedMentions(to: deep.id)
        let notesLinked = try await objects.open(id: notes.id)

        // Restore Notes to the unlinked body so the committed fixture matches scan-first UI.
        try await objects.save(meta: notesLinked.meta, bodyMarkdown: notesBody)
        let notesRestored = try await objects.open(id: notes.id)

        let dailyAfter = try await daily.open(date: day, calendar: calendar)
        let dailyUnchanged = dailyAfter.bodyMarkdown == dailyBefore

        let vaultRoot = try await vault.vaultRootURL
        var sqliteInVault = false
        if let enumerator = FileManager.default.enumerator(
            at: vaultRoot,
            includingPropertiesForKeys: nil
        ) {
            for case let found as URL in enumerator {
                if found.lastPathComponent == "index.sqlite" { sqliteInVault = true }
            }
        }

        let proof = UnlinkedMentionProof.evaluate(
            plainBody: notesBody,
            wikiLinkedBody: journalBody,
            wordBoundaryBody: "deep working",
            title: "Deep Work",
            bodyBefore: notesBody,
            bodyAfterScan: notesAfterScan.bodyMarkdown,
            indexInsideVault: sqliteInVault
        )

        func page(_ meta: LociObjectMeta, body: String) -> PageInfo {
            PageInfo(
                id: meta.id.frontMatterIDString,
                title: meta.title,
                relativePath: meta.relativePath,
                bodyMarkdown: body
            )
        }

        func mentionInfos(_ rows: [UnlinkedMention]) -> [MentionInfo] {
            rows.map {
                MentionInfo(
                    sourceId: $0.source.id.frontMatterIDString,
                    sourceTitle: $0.source.title,
                    snippet: $0.snippet
                )
            }
        }

        let payload = Payload(
            moduleVersion: LociVaultModule.version,
            indexModuleVersion: LociIndexModule.version,
            vaultRoot: vaultRoot.path,
            indexPath: index.databaseURL.path,
            indexInsideVault: sqliteInVault,
            dailyUnchanged: dailyUnchanged,
            dailyPath: dailyPath,
            dailyBody: dailyAfter.bodyMarkdown,
            target: page(deep, body: "Focus is a skill.\n"),
            notes: page(notesRestored.meta, body: notesRestored.bodyMarkdown),
            journal: page(journal, body: journalBody),
            notesBodyContainsWikiLink: notesRestored.bodyMarkdown.contains("[["),
            notesBodyAfterLink: notesAfterLinkBody,
            notesBodyAfterLinkContainsWikiLink: notesAfterLinkBody.contains("[["),
            mentions: mentionInfos(mentions),
            mentionTitles: mentions.map(\.source.title),
            mentionsAfterLink: mentionInfos(mentionsAfterLink),
            proof: proof,
            note:
                "PR44: Unlinked mentions scan titles in other notes. Notes.md contains plain “Deep Work” and is listed; Journal already wiki-links and is not. Scan does not rewrite markdown. Explicit Link replaces the first occurrence with [[id|title]]. Daily unchanged. Index outside vault."
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)
        if let text = String(data: data, encoding: .utf8) {
            print(text)
        }
    }
}
