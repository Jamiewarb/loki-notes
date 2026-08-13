import Foundation

/// Safari web clipper pipeline (PR32).
///
/// **Extension path:** `enqueue` writes `.loci/inbox/<id>.json` via Capture inbox
/// conventions (vault only — no index).
/// **Main app path:** `drain` applies staging → today / Weblink; index via ObjectServing.
/// **Direct path:** `clip` when CaptureServing + ObjectServing are available.
public protocol SafariClipServing: Sendable {
    /// Extension path: enqueue inbox JSON only (no index).
    @discardableResult
    func enqueue(_ clip: SafariClip) async throws -> String

    /// Main app: drain inbox (delegates `CaptureServing.drainInbox`).
    @discardableResult
    func drain(calendar: Calendar) async throws -> [CaptureResult]

    /// Direct clip when full stack available.
    @discardableResult
    func clip(_ clip: SafariClip, calendar: Calendar) async throws -> CaptureResult
}
