import Foundation
import LociCore
import LociMarkdown

/// Concrete `ImportServing` — scans foreign trees, dry-runs, writes vault files, indexes (PR27).
///
/// Importers never invent a parallel store: every apply lands under `objects/`, `daily/`, or
/// `media/` via `VaultServing`, then `IndexUpdating.applyVaultEvent`.
public final class ImportService: ImportServing, @unchecked Sendable {
    private let vault: any VaultServing
    private let query: any IndexQuerying
    private let update: any IndexUpdating
    private let schema: (any SchemaServing)?
    private let media: (any MediaServing)?
    private let parser = MarkdownParser()
    private let serializer = MarkdownSerializer()

    public init(
        vault: any VaultServing,
        query: any IndexQuerying,
        update: any IndexUpdating,
        schema: (any SchemaServing)? = nil,
        media: (any MediaServing)? = nil
    ) {
        self.vault = vault
        self.query = query
        self.update = update
        self.schema = schema
        self.media = media
    }

    public convenience init(
        vault: any VaultServing,
        index: some IndexQuerying & IndexUpdating,
        schema: (any SchemaServing)? = nil,
        media: (any MediaServing)? = nil
    ) {
        self.init(vault: vault, query: index, update: index, schema: schema, media: media)
    }

    // MARK: - ImportServing

    public func detectKind(atSourceRoot sourceRoot: URL) async throws -> ImportSourceKind {
        let root = try validatedDirectory(sourceRoot)
        let names = try FileManager.default.contentsOfDirectory(atPath: root.path)
        return ImportSourceDetector.detect(topLevelNames: names)
    }

    public func dryRun(
        sourceRoot: URL,
        kind: ImportSourceKind?,
        conflictPolicy: ImportConflictPolicy
    ) async throws -> ImportDryRunSummary {
        let root = try validatedDirectory(sourceRoot)
        let resolvedKind: ImportSourceKind
        if let kind {
            resolvedKind = kind
        } else {
            resolvedKind = try await detectKind(atSourceRoot: root)
        }
        let scan = try ImportSourceScanner.scan(root: root, kind: resolvedKind)
        guard !scan.markdownFiles.isEmpty else {
            throw LociError.importEmpty(root.path)
        }

        var warnings = scan.warnings
        var items: [ImportPlanItem] = []
        var titleIndex: [String: String] = [:]
        var usedPaths = Set<String>()
        var usedIDs = Set<String>()

        for file in scan.markdownFiles {
            let data = try Data(contentsOf: file.url)
            let text = String(data: data, encoding: .utf8) ?? ""
            let fallback = (file.relativePath as NSString).lastPathComponent
            let probe = ImportDocumentProbe.probe(markdown: text, fallbackTitle: fallback)
            var itemWarnings = probe.wikiLinkTargets.isEmpty
                ? []
                : [] as [String]

            let planned = try await planItem(
                file: file,
                probe: probe,
                kind: resolvedKind,
                conflictPolicy: conflictPolicy,
                usedPaths: &usedPaths,
                usedIDs: &usedIDs
            )
            itemWarnings.append(contentsOf: planned.warnings)
            var item = planned.item
            item.warnings = itemWarnings
            items.append(item)

            // Title / alias → preferred wiki target (slug or daily key / id).
            let preferredTarget: String = {
                if item.isDaily {
                    return item.objectID.frontMatterIDString
                }
                let slug = ImportPathRules.slugify(item.title)
                return slug.isEmpty ? item.objectID.frontMatterIDString : slug
            }()
            titleIndex[item.title.lowercased()] = preferredTarget
            for alias in probe.frontMatter?.aliases ?? [] {
                let key = alias.lowercased()
                if !key.isEmpty { titleIndex[key] = preferredTarget }
            }
            // Filename stem
            let stem = ((file.relativePath as NSString).lastPathComponent as NSString)
                .deletingPathExtension
            if !stem.isEmpty {
                titleIndex[stem.lowercased()] = preferredTarget
            }
        }

        // Flag unresolved wiki-links against the title index (best-effort).
        for i in items.indices {
            let data = try Data(contentsOf: URL(fileURLWithPath: items[i].sourcePath))
            let text = String(data: data, encoding: .utf8) ?? ""
            let probe = ImportDocumentProbe.probe(
                markdown: text,
                fallbackTitle: items[i].title
            )
            let unresolved = probe.wikiLinkTargets.filter { target in
                titleIndex[target.lowercased()] == nil
            }
            if !unresolved.isEmpty {
                items[i].warnings.append(
                    "unresolved wiki-links: \(unresolved.joined(separator: ", "))"
                )
                warnings.append(
                    "\(items[i].sourceRelativePath): unresolved [[…]] → \(unresolved.joined(separator: ", "))"
                )
            }
        }

        let mediaItems = scan.mediaFiles.map { media -> ImportMediaItem in
            ImportMediaItem(
                sourcePath: media.url.path,
                sourceRelativePath: media.relativePath,
                preferredFileName: media.url.lastPathComponent,
                kind: MediaPath.kind(forFileName: media.url.lastPathComponent)
            )
        }

        return ImportDryRunSummary(
            sourceKind: resolvedKind,
            sourceRoot: root.path,
            conflictPolicy: conflictPolicy,
            items: items,
            media: mediaItems,
            warnings: warnings,
            titleIndex: titleIndex
        )
    }

    public func apply(
        summary: ImportDryRunSummary,
        conflictPolicy: ImportConflictPolicy
    ) async throws -> ImportApplyResult {
        // Ensure schema knows about custom types referenced by the plan.
        try await ensureTypes(for: summary.items)

        // Copy media first so body rewrites can point at vault paths.
        var mediaMap: [String: String] = [:] // source relative → vault media path
        var mediaCopied: [ImportMediaItem] = []
        for var mediaItem in summary.media {
            if let media {
                let url = URL(fileURLWithPath: mediaItem.sourcePath)
                guard FileManager.default.fileExists(atPath: url.path) else {
                    continue
                }
                let attachment = try await media.attach(
                    fileURL: url,
                    kind: mediaItem.kind,
                    preferredFileName: mediaItem.preferredFileName
                )
                mediaItem.destinationRelativePath = attachment.relativePath
                mediaMap[mediaItem.sourceRelativePath] = attachment.relativePath
                // Also key by filename for Obsidian-style refs.
                mediaMap[mediaItem.preferredFileName] = attachment.relativePath
                mediaCopied.append(mediaItem)
            }
        }

        var written: [ImportPlanItem] = []
        var skipped: [ImportPlanItem] = []
        var warnings = summary.warnings

        for item in summary.items {
            if item.action == .skipConflict {
                skipped.append(item)
                continue
            }
            do {
                try await writeItem(
                    item,
                    titleIndex: summary.titleIndex,
                    mediaMap: mediaMap,
                    sourceKind: summary.sourceKind
                )
                written.append(item)
            } catch {
                var failed = item
                failed.warnings.append("apply failed: \(error)")
                skipped.append(failed)
                warnings.append("\(item.sourceRelativePath): \(error)")
            }
        }

        return ImportApplyResult(
            sourceKind: summary.sourceKind,
            written: written,
            skipped: skipped,
            mediaCopied: mediaCopied,
            warnings: warnings
        )
    }

    public func importFrom(
        sourceRoot: URL,
        kind: ImportSourceKind?,
        conflictPolicy: ImportConflictPolicy
    ) async throws -> ImportApplyResult {
        let summary = try await dryRun(
            sourceRoot: sourceRoot,
            kind: kind,
            conflictPolicy: conflictPolicy
        )
        return try await apply(summary: summary, conflictPolicy: conflictPolicy)
    }

    // MARK: - Planning

    private struct Planned {
        var item: ImportPlanItem
        var warnings: [String]
    }

    private func planItem(
        file: ImportSourceScanner.MarkdownFile,
        probe: ImportDocumentProbe.Result,
        kind: ImportSourceKind,
        conflictPolicy: ImportConflictPolicy,
        usedPaths: inout Set<String>,
        usedIDs: inout Set<String>
    ) async throws -> Planned {
        var warnings: [String] = []
        let isDaily = ImportPathRules.looksLikeDaily(relativePath: file.relativePath)
            || ImportPathRules.parseDailyDateKey(
                (file.relativePath as NSString).lastPathComponent
            ) != nil

        var typeID = ImportPathRules.mapTypeName(probe.frontMatter?.type)
        if isDaily { typeID = .daily }
        if kind == .capacitiesExport, typeID == .page,
            let folderType = capacitiesFolderType(file.relativePath)
        {
            typeID = folderType
        }

        var objectID: ObjectID
        var preserved = false
        if let raw = probe.frontMatter?.id, let parsed = ObjectID(parsing: raw) {
            objectID = parsed
            preserved = true
        } else if isDaily,
            let ymd = ImportPathRules.parseDailyDateKey(
                (file.relativePath as NSString).lastPathComponent
            )
        {
            objectID = ObjectID.daily(year: ymd.year, month: ymd.month, day: ymd.day)
            preserved = true
        } else {
            objectID = ObjectID()
        }

        var title = probe.title
        var destination: String
        if isDaily,
            let ymd = ImportPathRules.parseDailyDateKey(
                (file.relativePath as NSString).lastPathComponent
            )
        {
            let daily = ImportPathRules.dailyDestination(
                year: ymd.year,
                month: ymd.month,
                day: ymd.day
            )
            destination = daily.path
            objectID = daily.id
            title = daily.title
            typeID = .daily
            preserved = true
        } else {
            destination = ImportPathRules.objectDestination(
                typeID: typeID,
                title: title,
                id: objectID
            )
        }

        // Collision within this import batch.
        if usedPaths.contains(destination) {
            let short = String(
                objectID.uuidString.lowercased().replacingOccurrences(of: "-", with: "").prefix(8)
            )
            let dir = (destination as NSString).deletingLastPathComponent
            let stem = ImportPathRules.slugify(title)
            destination = "\(dir)/\(stem.isEmpty ? "note" : stem)-\(short).md"
            warnings.append("renamed for in-batch path collision")
        }

        let pathExists = try await vault.fileExists(atRelativePath: destination)
            || usedPaths.contains(destination)
        let idKey = objectID.frontMatterIDString
        var idExists = usedIDs.contains(idKey)
        if !idExists {
            idExists = (try? await query.object(id: objectID)) != nil
        }

        var action: ImportPlanAction = .create
        switch conflictPolicy {
        case .skip:
            if pathExists || idExists {
                action = .skipConflict
                warnings.append(
                    pathExists
                        ? "destination exists — skip"
                        : "object id exists — skip"
                )
            }
        case .overwrite:
            if pathExists || idExists {
                action = .overwrite
            }
        case .rename:
            if pathExists {
                let short = String(
                    objectID.uuidString.lowercased().replacingOccurrences(of: "-", with: "")
                        .prefix(8)
                )
                let dir = (destination as NSString).deletingLastPathComponent
                let stem = ImportPathRules.slugify(title)
                destination = "\(dir)/\(stem.isEmpty ? "imported" : stem)-\(short).md"
                action = .rename
                warnings.append("renamed destination for path conflict")
            }
            if idExists {
                objectID = ObjectID()
                preserved = false
                action = .rename
                warnings.append("allocated new object id for id conflict")
            }
            if !pathExists && !idExists {
                action = .create
            }
        }

        usedPaths.insert(destination)
        usedIDs.insert(objectID.frontMatterIDString)

        let tags = probe.frontMatter?.tags ?? []
        let item = ImportPlanItem(
            sourcePath: file.url.path,
            sourceRelativePath: file.relativePath,
            title: title,
            typeID: typeID,
            objectID: objectID,
            destinationRelativePath: destination,
            action: action,
            tags: tags,
            isDaily: typeID == .daily || isDaily,
            preservedObjectID: preserved,
            warnings: warnings
        )
        return Planned(item: item, warnings: warnings)
    }

    private func capacitiesFolderType(_ relativePath: String) -> ObjectTypeID? {
        let parts = relativePath.replacingOccurrences(of: "\\", with: "/").split(separator: "/")
            .map(String.init)
        // Objects/<Type>/file.md
        guard parts.count >= 3, parts[0].lowercased() == "objects" else { return nil }
        return ImportPathRules.mapTypeName(parts[1])
    }

    // MARK: - Apply helpers

    private func ensureTypes(for items: [ImportPlanItem]) async throws {
        guard let schema else { return }
        let known = Set(try await schema.knownTypeIDs())
        var created = Set<ObjectTypeID>()
        for item in items {
            let id = item.typeID
            if id == .page || id == .daily || id == .image { continue }
            if known.contains(id) || created.contains(id) { continue }
            _ = try await schema.createType(
                name: id.rawValue.capitalized,
                icon: "doc",
                color: "#4A7C6F",
                slug: id.rawValue
            )
            created.insert(id)
        }
    }

    private func writeItem(
        _ item: ImportPlanItem,
        titleIndex: [String: String],
        mediaMap: [String: String],
        sourceKind: ImportSourceKind
    ) async throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: item.sourcePath))
        let text = String(data: data, encoding: .utf8) ?? ""
        let probe = ImportDocumentProbe.probe(markdown: text, fallbackTitle: item.title)

        var body = probe.body
        if sourceKind == .obsidianVault {
            body = ObsidianEmbedRewriter.rewriteEmbedsToMarkdownImages(body)
        }

        // Rewrite image refs that we copied into media/.
        body = rewriteImageRefs(body, mediaMap: mediaMap, objectPath: item.destinationRelativePath)

        let (rewritten, unresolved) = ImportWikiLinkRewriter.rewrite(body, titleIndex: titleIndex)
        body = rewritten
        _ = unresolved

        let created = probe.frontMatter?.created ?? Date()
        let updated = probe.frontMatter?.updated ?? created
        var properties: [String: PropertyValue] = [:]
        for (k, v) in probe.frontMatter?.properties ?? [:] {
            properties[k] = .text(v)
        }

        let meta = LociObjectMeta(
            id: item.objectID,
            typeID: item.typeID,
            title: item.title,
            created: created,
            updated: updated,
            relativePath: item.destinationRelativePath,
            tags: item.tags,
            properties: properties
        )

        let bodyDoc = try parser.parse(body)
        let document = LociDocument(
            frontMatter: FrontMatter(meta: meta),
            blocks: bodyDoc.blocks
        )
        let serialized = serializer.serialize(document)
        guard let out = serialized.data(using: .utf8) else {
            throw LociError.coordinationFailed("utf8 encode failed for \(item.destinationRelativePath)")
        }
        try await vault.writeFile(out, atRelativePath: item.destinationRelativePath)
        let kind: VaultEventKind =
            (item.action == .overwrite) ? .modified : .created
        try await update.applyVaultEvent(
            relativePath: item.destinationRelativePath,
            kind: kind
        )
    }

    private func rewriteImageRefs(
        _ body: String,
        mediaMap: [String: String],
        objectPath: String
    ) -> String {
        guard !mediaMap.isEmpty else { return body }
        guard
            let regex = try? NSRegularExpression(
                pattern: #"!\[([^\]]*)\]\(([^)\s]+)(?:\s+\"([^\"]*)\")?\)"#
            )
        else { return body }
        let ns = body as NSString
        let matches = regex.matches(in: body, range: NSRange(location: 0, length: ns.length))
        var result = body
        for match in matches.reversed() {
            guard match.numberOfRanges >= 3,
                let urlRange = Range(match.range(at: 2), in: result)
            else { continue }
            let url = String(result[urlRange])
            let fileName = (url as NSString).lastPathComponent
            guard let mediaPath = mediaMap[url] ?? mediaMap[fileName] else { continue }
            let relative = MediaPath.relativeURL(
                fromObjectRelativePath: objectPath,
                toMediaRelativePath: mediaPath
            )
            var alt = ""
            if let altRange = Range(match.range(at: 1), in: result) {
                alt = String(result[altRange])
            }
            var title: String?
            if match.numberOfRanges >= 4, match.range(at: 3).location != NSNotFound,
                let titleRange = Range(match.range(at: 3), in: result)
            {
                title = String(result[titleRange])
            }
            let replacement: String
            if let title, !title.isEmpty {
                replacement = "![\(alt)](\(relative) \"\(title)\")"
            } else {
                replacement = "![\(alt)](\(relative))"
            }
            if let full = Range(match.range(at: 0), in: result) {
                result.replaceSubrange(full, with: replacement)
            }
        }
        return result
    }

    private func validatedDirectory(_ url: URL) throws -> URL {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue
        else {
            throw LociError.importSourceNotFound(url.path)
        }
        return url
    }
}
