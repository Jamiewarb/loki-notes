import Foundation
import LociCore

/// Download-on-demand for iCloud ubiquity items before parse (PR21).
///
/// - Apple ubiquity: start download when status is not current (stub-friendly).
/// - Local Documents / Linux: no-op success.
public enum DownloadOnDemand: Sendable {
    /// Ensure `url` has local bytes. No-op when not an ubiquity item or on Linux.
    public static func ensureDownloaded(at url: URL, fileManager: FileManager = .default) throws {
        #if canImport(Darwin) && (os(macOS) || os(iOS) || os(tvOS) || os(watchOS))
        let values = try? url.resourceValues(forKeys: [
            .isUbiquitousItemKey,
            .ubiquitousItemDownloadingStatusKey,
        ])
        guard values?.isUbiquitousItem == true else {
            return
        }
        if values?.ubiquitousItemDownloadingStatus == .current {
            return
        }

        do {
            try fileManager.startDownloadingUbiquitousItem(at: url)
        } catch {
            throw LociError.downloadFailed(error.localizedDescription)
        }

        // Brief poll — Sync UX may show syncing; full wait belongs to UI/retry.
        let deadline = Date().addingTimeInterval(2.0)
        while Date() < deadline {
            let status = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
                .ubiquitousItemDownloadingStatus
            if status == .current {
                return
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        // Stub success after kickoff — do not hard-fail open on slow networks.
        #else
        _ = url
        _ = fileManager
        #endif
    }
}
