import Foundation

/// Daily note lifecycle: deterministic path/id, ensure-today, day navigation (PR10).
///
/// Does **not** write “created today” into the daily markdown — that is PR11 (inspector only).
public protocol DailyNoteServing: Sendable {
    /// Create today’s note if missing (empty/default body); open if present. Idempotent.
    func ensureToday(calendar: Calendar) async throws -> OpenedObject

    /// Ensure the daily note for an arbitrary calendar day exists, then open it.
    func ensure(for date: Date, calendar: Calendar) async throws -> OpenedObject

    /// Open an existing daily note by date (throws if missing).
    func open(date: Date, calendar: Calendar) async throws -> OpenedObject
}
