import Foundation
import LociCore

/// Walk an import source tree and collect markdown + media candidates (PR27).
enum ImportSourceScanner {
    struct MarkdownFile: Sendable {
        var url: URL
        var relativePath: String
    }

    struct MediaFile: Sendable {
        var url: URL
        var relativePath: String
    }

    struct ScanResult: Sendable {
        var markdownFiles: [MarkdownFile]
        var mediaFiles: [MediaFile]
        var warnings: [String]
    }

    static func scan(root: URL, kind: ImportSourceKind) throws -> ScanResult {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return ScanResult(markdownFiles: [], mediaFiles: [], warnings: ["enumerator failed"])
        }

        var markdown: [MarkdownFile] = []
        var media: [MediaFile] = []
        var warnings: [String] = []

        let skipDirNames: Set<String> = [
            ".obsidian", ".git", ".trash", "node_modules", ".loci", ".smart-env",
            "__macosx",
        ]

        for case let url as URL in enumerator {
            let name = url.lastPathComponent
            // Skip known junk / config directories (still allow scanning past .obsidian for detect).
            if let values = try? url.resourceValues(forKeys: [.isDirectoryKey]),
                values.isDirectory == true
            {
                if skipDirNames.contains(name.lowercased()) {
                    enumerator.skipDescendants()
                }
                continue
            }

            let relative = relativePath(of: url, to: root)
            let lowerRel = relative.lowercased()

            // Skip Capacities / Obsidian config files.
            if lowerRel.hasPrefix(".obsidian/") { continue }
            if name.lowercased() == "capacities.json" { continue }

            if name.lowercased().hasSuffix(".md") {
                // Capacities exports sometimes include README at root — still import.
                markdown.append(MarkdownFile(url: url, relativePath: relative))
            } else if isMediaFileName(name) {
                media.append(MediaFile(url: url, relativePath: relative))
            }
        }

        markdown.sort { $0.relativePath < $1.relativePath }
        media.sort { $0.relativePath < $1.relativePath }

        if kind == .obsidianVault && markdown.isEmpty {
            warnings.append("Obsidian vault detected but no markdown files found")
        }
        if kind == .capacitiesExport && markdown.isEmpty {
            warnings.append("Capacities export detected but no markdown files found")
        }

        return ScanResult(markdownFiles: markdown, mediaFiles: media, warnings: warnings)
    }

    private static func relativePath(of url: URL, to root: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let filePath = url.standardizedFileURL.path
        if filePath.hasPrefix(rootPath) {
            var rel = String(filePath.dropFirst(rootPath.count))
            if rel.hasPrefix("/") { rel = String(rel.dropFirst()) }
            return rel
        }
        return url.lastPathComponent
    }

    private static func isMediaFileName(_ name: String) -> Bool {
        let ext = (name as NSString).pathExtension.lowercased()
        let allowed: Set<String> = [
            "png", "jpg", "jpeg", "gif", "webp", "heic", "svg", "pdf",
            "mp3", "wav", "m4a", "mp4", "mov", "txt", "csv", "zip",
        ]
        return allowed.contains(ext)
    }
}
