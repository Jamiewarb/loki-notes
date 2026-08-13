import Foundation
import LociCore

/// Concrete `CaptureServing` — inbox staging + drain into daily / typed objects (PR26).
///
/// Extensions call `enqueue` with only `VaultServing` (no index). The main app calls
/// `drainInbox` on foreground so `ObjectServing` / `DailyNoteServing` apply writes and
/// the local index updates asynchronously.
public final class CaptureService: CaptureServing, @unchecked Sendable {
    private let vault: any VaultServing
    private let objects: any ObjectServing
    private let dailyNotes: any DailyNoteServing

    public init(
        vault: any VaultServing,
        objects: any ObjectServing,
        dailyNotes: any DailyNoteServing
    ) {
        self.vault = vault
        self.objects = objects
        self.dailyNotes = dailyNotes
    }

    // MARK: - CaptureServing

    @discardableResult
    public func enqueue(_ item: CaptureInboxItem) async throws -> String {
        try await ensureInboxDirectory()
        var item = item
        if item.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            item.id = UUID().uuidString.lowercased()
        }
        let path = CaptureInbox.relativePath(forID: item.id)
        let data = try CaptureInboxCodec.encode(item)
        try await vault.writeFile(data, atRelativePath: path)
        return path
    }

    @discardableResult
    public func drainInbox(calendar: Calendar = .current) async throws -> [CaptureResult] {
        let pending = try await listPendingInbox()
        var results: [CaptureResult] = []
        for path in pending.sorted() {
            let data = try await vault.readFile(atRelativePath: path)
            let item = try CaptureInboxCodec.decode(data)
            let result = try await apply(item, calendar: calendar, inboxRelativePath: path)
            try await vault.deleteFile(atRelativePath: path)
            results.append(result)
        }
        return results
    }

    @discardableResult
    public func appendToToday(
        _ text: String,
        sourceURL: String? = nil,
        source: CaptureSource = .unknown,
        calendar: Calendar = .current
    ) async throws -> CaptureResult {
        let item = CaptureInboxItem.appendLine(text, source: source, sourceURL: sourceURL)
        return try await apply(item, calendar: calendar, inboxRelativePath: nil)
    }

    @discardableResult
    public func createTypedObject(
        typeID: ObjectTypeID = .page,
        title: String?,
        text: String,
        sourceURL: String? = nil,
        source: CaptureSource = .unknown
    ) async throws -> CaptureResult {
        let item = CaptureInboxItem.createTyped(
            typeID: typeID,
            title: title,
            text: text,
            source: source,
            sourceURL: sourceURL
        )
        return try await apply(item, calendar: .current, inboxRelativePath: nil)
    }

    public func listPendingInbox() async throws -> [String] {
        try await ensureInboxDirectory()
        let root = try await vault.vaultRootURL
        let dir = root.appendingPathComponent(CaptureInbox.directory, isDirectory: true)
        guard FileManager.default.fileExists(atPath: dir.path) else { return [] }
        let urls = try FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        return urls
            .filter { $0.pathExtension.lowercased() == "json" }
            .map { CaptureInbox.directory + "/" + $0.lastPathComponent }
            .filter { CaptureInbox.isInboxPath($0) }
            .sorted()
    }

    // MARK: - Internals

    private func apply(
        _ item: CaptureInboxItem,
        calendar: Calendar,
        inboxRelativePath: String?
    ) async throws -> CaptureResult {
        switch item.kind {
        case .appendToToday:
            return try await applyAppend(item, calendar: calendar, inboxRelativePath: inboxRelativePath)
        case .createObject:
            return try await applyCreate(item, inboxRelativePath: inboxRelativePath)
        }
    }

    private func applyAppend(
        _ item: CaptureInboxItem,
        calendar: Calendar,
        inboxRelativePath: String?
    ) async throws -> CaptureResult {
        var opened = try await dailyNotes.ensureToday(calendar: calendar)
        let line = CaptureLineFormatter.line(
            text: item.text,
            sourceURL: item.sourceURL,
            source: item.source
        )
        let newBody = CaptureLineFormatter.append(line: line, toBody: opened.bodyMarkdown)
        opened.meta.updated = Date()
        try await objects.save(meta: opened.meta, bodyMarkdown: newBody)
        return CaptureResult(
            kind: .appendToToday,
            objectID: opened.meta.id,
            relativePath: opened.meta.relativePath,
            inboxRelativePath: inboxRelativePath,
            appendedLine: line
        )
    }

    private func applyCreate(
        _ item: CaptureInboxItem,
        inboxRelativePath: String?
    ) async throws -> CaptureResult {
        let typeID = item.typeID ?? .page
        let title = {
            if let t = item.title?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
                return t
            }
            return CaptureLineFormatter.inferredTitle(from: item.text)
        }()
        var meta = try await objects.create(typeID: typeID, title: title)
        var body = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = item.sourceURL?.trimmingCharacters(in: .whitespacesAndNewlines), !url.isEmpty {
            // Weblink: copy sourceURL into frontmatter `url` (inbox drain path).
            if typeID == .weblink {
                meta.properties["url"] = .url(url)
                if let pageTitle = item.title?.trimmingCharacters(in: .whitespacesAndNewlines),
                    !pageTitle.isEmpty
                {
                    meta.properties["clipped-from"] = .text(pageTitle)
                }
            }
            if body.isEmpty {
                body = url
            } else if typeID != .weblink, !body.contains(url) {
                // Weblink body already includes Source: via SafariClipFactory.
                body += "\n\nSource: \(url)\n"
            }
        }
        meta.updated = Date()
        let finalBody =
            body.isEmpty
            ? ""
            : (body.hasSuffix("\n") ? body : body + "\n")
        try await objects.save(meta: meta, bodyMarkdown: finalBody)
        return CaptureResult(
            kind: .createObject,
            objectID: meta.id,
            relativePath: meta.relativePath,
            inboxRelativePath: inboxRelativePath,
            appendedLine: nil
        )
    }

    private func ensureInboxDirectory() async throws {
        let root = try await vault.vaultRootURL
        let dir = root.appendingPathComponent(CaptureInbox.directory, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }
}

/// Extension-only helper: enqueue into vault without ObjectServing / index (PR26).
///
/// Share extension / widget / menu bar use this when the main app stack is unavailable.
public enum CaptureInboxWriter: Sendable {
    /// Write a staging JSON file. Returns vault-relative path.
    @discardableResult
    public static func enqueue(
        _ item: CaptureInboxItem,
        vault: any VaultServing
    ) async throws -> String {
        var item = item
        if item.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            item.id = UUID().uuidString.lowercased()
        }
        let root = try await vault.vaultRootURL
        let dir = root.appendingPathComponent(CaptureInbox.directory, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let path = CaptureInbox.relativePath(forID: item.id)
        let data = try CaptureInboxCodec.encode(item)
        try await vault.writeFile(data, atRelativePath: path)
        return path
    }
}
