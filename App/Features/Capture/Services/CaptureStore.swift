import Foundation
import LociCore

/// Thin feature-local facade over `CaptureServing` (PR26).
@MainActor
final class CaptureStore {
    private let capture: (any CaptureServing)?

    init(capture: (any CaptureServing)?) {
        self.capture = capture
    }

    func pendingPaths() async throws -> [String] {
        guard let capture else { return [] }
        return try await capture.listPendingInbox()
    }

    @discardableResult
    func enqueueAppend(_ text: String, source: CaptureSource) async throws -> String? {
        guard let capture else { return nil }
        return try await capture.enqueue(
            CaptureInboxItem.appendLine(text, source: source)
        )
    }

    @discardableResult
    func drain(calendar: Calendar = .current) async throws -> [CaptureResult] {
        guard let capture else { return [] }
        return try await capture.drainInbox(calendar: calendar)
    }

    @discardableResult
    func quickAdd(_ text: String, calendar: Calendar = .current) async throws -> CaptureResult? {
        guard let capture else { return nil }
        return try await capture.appendToToday(
            text,
            sourceURL: nil,
            source: .harness,
            calendar: calendar
        )
    }
}
