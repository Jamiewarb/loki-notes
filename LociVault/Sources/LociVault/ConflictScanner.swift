import Foundation
import LociCore

/// Walks the vault and lists conflicted-copy paths (markdown + media). PR21 Sync UX.
public enum ConflictScanner: Sendable {
    /// Enumerate conflicted copies under `root` using `ConflictedCopyDetector`.
    public static func listConflictedCopies(under root: URL) -> [SyncConflictItem] {
        var items: [SyncConflictItem] = []
        let fm = FileManager.default
        guard
            let enumerator = fm.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsPackageDescendants, .skipsHiddenFiles]
            )
        else {
            return items
        }
        let rootPath = root.standardizedFileURL.path
        for case let fileURL as URL in enumerator {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: fileURL.path, isDirectory: &isDir), !isDir.boolValue else {
                continue
            }
            // Still scan `.loci` trash? Skip trash — conflicts there are soft-deleted.
            let path = fileURL.standardizedFileURL.path
            guard path.hasPrefix(rootPath) else { continue }
            var relative = String(path.dropFirst(rootPath.count))
            if relative.hasPrefix("/") {
                relative.removeFirst()
            }
            guard !relative.isEmpty else { continue }
            if relative.hasPrefix("\(VaultLayout.trashDirectory)/") {
                continue
            }
            guard ConflictedCopyDetector.isConflictedCopy(pathOrFilename: relative) else {
                continue
            }
            items.append(
                SyncConflictItem(
                    relativePath: relative,
                    kind: SyncConflictKind.infer(fromRelativePath: relative)
                )
            )
        }
        return items.sorted { $0.relativePath < $1.relativePath }
    }
}
