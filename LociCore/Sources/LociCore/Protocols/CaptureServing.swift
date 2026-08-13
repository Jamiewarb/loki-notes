import Foundation

/// Quick capture pipeline shared by Share extension, widget, menu bar, and main app (PR26).
///
/// **Extension path:** `enqueue` writes `.loci/inbox/<id>.json` (vault only — no index).
/// **Main app path:** `drainInbox` on foreground applies staging → today / typed object,
/// then deletes inbox files; index updates via `ObjectServing` / `DailyNoteServing`.
///
/// Direct `appendToToday` / `createTypedObject` skip staging when the full stack is available.
public protocol CaptureServing: Sendable {
    /// Write a staging inbox JSON under `.loci/inbox/`. Safe without index / ObjectServing.
    @discardableResult
    func enqueue(_ item: CaptureInboxItem) async throws -> String

    /// Apply all pending inbox items into today’s daily or typed objects; remove staging files.
    @discardableResult
    func drainInbox(calendar: Calendar) async throws -> [CaptureResult]

    /// Ensure today + append one formatted line (coordinated vault write + index apply).
    @discardableResult
    func appendToToday(
        _ text: String,
        sourceURL: String?,
        source: CaptureSource,
        calendar: Calendar
    ) async throws -> CaptureResult

    /// Create a typed object from capture text (title inferred when nil).
    @discardableResult
    func createTypedObject(
        typeID: ObjectTypeID,
        title: String?,
        text: String,
        sourceURL: String?,
        source: CaptureSource
    ) async throws -> CaptureResult

    /// List pending staging relative paths (`.loci/inbox/*.json`).
    func listPendingInbox() async throws -> [String]
}
