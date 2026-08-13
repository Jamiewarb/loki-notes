import Foundation
import LociCore
import LociMarkdown

/// Creates and opens deterministic daily notes under `daily/YYYY-MM-DD.md` (PR10).
///
/// Identity: logical key `daily-YYYY-MM-DD` → `ObjectID.daily(...)`. Two devices
/// ensuring the same day write the same path and id (no fork). Local vault fallback works.
///
/// When `schema` is provided, new dailies apply the Daily type's default template (PR14).
///
/// **Does not** rewrite the daily body when other objects are created (Created-today = PR11).
public final class DailyNoteService: DailyNoteServing, @unchecked Sendable {
    private let vault: any VaultServing
    private let query: any IndexQuerying
    private let update: any IndexUpdating
    private let schema: (any SchemaServing)?
    private let parser = MarkdownParser()
    private let serializer = MarkdownSerializer()

    public init(
        vault: any VaultServing,
        query: any IndexQuerying,
        update: any IndexUpdating,
        schema: (any SchemaServing)? = nil
    ) {
        self.vault = vault
        self.query = query
        self.update = update
        self.schema = schema
    }

    public convenience init(
        vault: any VaultServing,
        index: some IndexQuerying & IndexUpdating,
        schema: (any SchemaServing)? = nil
    ) {
        self.init(vault: vault, query: index, update: index, schema: schema)
    }

    // MARK: - DailyNoteServing

    public func ensureToday(calendar: Calendar = .current) async throws -> OpenedObject {
        try await ensure(for: Date(), calendar: calendar)
    }

    public func ensure(for date: Date, calendar: Calendar = .current) async throws -> OpenedObject {
        let day = DailyNoteIdentity.startOfDay(date, calendar: calendar)
        let path = DailyNoteIdentity.relativePath(for: day, calendar: calendar)
        if try await vault.fileExists(atRelativePath: path) {
            return try await openExisting(relativePath: path, expectedDate: day, calendar: calendar)
        }
        return try await createNew(for: day, calendar: calendar)
    }

    public func open(date: Date, calendar: Calendar = .current) async throws -> OpenedObject {
        let day = DailyNoteIdentity.startOfDay(date, calendar: calendar)
        let path = DailyNoteIdentity.relativePath(for: day, calendar: calendar)
        guard try await vault.fileExists(atRelativePath: path) else {
            throw LociError.fileNotFound(path)
        }
        return try await openExisting(relativePath: path, expectedDate: day, calendar: calendar)
    }

    // MARK: - Pure navigation (API for DaySwitcher)

    public func previousDay(of date: Date, calendar: Calendar = .current) -> Date {
        DailyNoteIdentity.previousDay(of: date, calendar: calendar)
    }

    public func nextDay(of date: Date, calendar: Calendar = .current) -> Date {
        DailyNoteIdentity.nextDay(of: date, calendar: calendar)
    }

    public func select(date: Date, calendar: Calendar = .current) -> Date {
        DailyNoteIdentity.startOfDay(date, calendar: calendar)
    }

    // MARK: - Internals

    private func createNew(for day: Date, calendar: Calendar) async throws -> OpenedObject {
        let id = DailyNoteIdentity.objectID(for: day, calendar: calendar)
        let path = DailyNoteIdentity.relativePath(for: day, calendar: calendar)
        let title = DailyNoteIdentity.title(for: day, calendar: calendar)
        let now = Date()
        // Prefer the day's start for `created` so created(on:) aligns with the note day.
        let created = day
        var meta = LociObjectMeta(
            id: id,
            typeID: .daily,
            title: title,
            created: created,
            updated: now,
            relativePath: path
        )
        var bodyMarkdown = ""
        var templateID: String?
        if let schema, let template = try await schema.defaultTemplate(for: .daily) {
            bodyMarkdown = template.bodyMarkdown
            meta.properties = template.defaultProperties
            templateID = template.id
        }
        try await writeDocument(meta: meta, bodyMarkdown: bodyMarkdown, templateID: templateID)
        try await update.applyVaultEvent(relativePath: path, kind: .created)
        return OpenedObject(meta: meta, bodyMarkdown: bodyMarkdown)
    }

    private func openExisting(
        relativePath: String,
        expectedDate: Date,
        calendar: Calendar
    ) async throws -> OpenedObject {
        let data = try await vault.readFile(atRelativePath: relativePath)
        guard let markdown = String(data: data, encoding: .utf8) else {
            throw LociError.fileNotFound(relativePath)
        }
        let document = try parser.parse(markdown)
        guard let frontMatter = document.frontMatter else {
            // Rare: plain markdown at daily path — treat as body, assign deterministic id.
            return try await adoptOrphan(
                relativePath: relativePath,
                bodyMarkdown: markdown,
                day: expectedDate,
                calendar: calendar
            )
        }
        let meta = frontMatter.toMeta(relativePath: relativePath)
        let bodyMarkdown = serializer.serializeBlocks(document.blocks)
        // Keep index in sync (file may predate index or arrive via iCloud).
        if try await query.object(id: meta.id) == nil {
            try await update.applyVaultEvent(relativePath: relativePath, kind: .created)
        }
        return OpenedObject(meta: meta, bodyMarkdown: bodyMarkdown)
    }

    private func adoptOrphan(
        relativePath: String,
        bodyMarkdown: String,
        day: Date,
        calendar: Calendar
    ) async throws -> OpenedObject {
        let id = DailyNoteIdentity.objectID(for: day, calendar: calendar)
        let title = DailyNoteIdentity.title(for: day, calendar: calendar)
        let now = Date()
        let meta = LociObjectMeta(
            id: id,
            typeID: .daily,
            title: title,
            created: day,
            updated: now,
            relativePath: relativePath
        )
        try await writeDocument(meta: meta, bodyMarkdown: bodyMarkdown)
        try await update.applyVaultEvent(relativePath: relativePath, kind: .modified)
        return OpenedObject(meta: meta, bodyMarkdown: bodyMarkdown)
    }

    private func writeDocument(
        meta: LociObjectMeta,
        bodyMarkdown: String,
        templateID: String? = nil
    ) async throws {
        let bodyDoc = try parser.parse(bodyMarkdown)
        let document = LociDocument(
            frontMatter: FrontMatter(meta: meta, template: templateID),
            blocks: bodyDoc.blocks
        )
        let text = serializer.serialize(document)
        guard let data = text.data(using: .utf8) else {
            throw LociError.coordinationFailed("utf8 encode failed for \(meta.relativePath)")
        }
        try await vault.writeFile(data, atRelativePath: meta.relativePath)
    }
}
