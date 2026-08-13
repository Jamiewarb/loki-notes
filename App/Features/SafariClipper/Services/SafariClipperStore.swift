import Foundation
import LociCore

/// Thin feature-local facade over `SafariClipServing` / `CaptureServing` (PR32).
@MainActor
final class SafariClipperStore {
    private let safari: (any SafariClipServing)?
    private let capture: (any CaptureServing)?

    init(safari: (any SafariClipServing)?, capture: (any CaptureServing)?) {
        self.safari = safari
        self.capture = capture
    }

    func pendingPaths() async throws -> [String] {
        guard let capture else { return [] }
        return try await capture.listPendingInbox()
    }

    @discardableResult
    func enqueue(_ clip: SafariClip) async throws -> String? {
        guard let safari else { return nil }
        return try await safari.enqueue(clip)
    }

    @discardableResult
    func drain(calendar: Calendar = .current) async throws -> [CaptureResult] {
        guard let safari else { return [] }
        return try await safari.drain(calendar: calendar)
    }

    @discardableResult
    func clip(_ clip: SafariClip, calendar: Calendar = .current) async throws -> CaptureResult? {
        guard let safari else { return nil }
        return try await safari.clip(clip, calendar: calendar)
    }
}
