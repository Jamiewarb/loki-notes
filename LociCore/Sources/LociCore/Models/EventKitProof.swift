import Foundation

/// Linux-testable notes for EventKit Calendar / Reminders (PR36).
///
/// EventKit types stay in Vault behind `#if canImport(EventKit)` and must never
/// leak into LociCore. Tests and DevHarness exercise fakes + these proof flags.
public struct EventKitProof: Hashable, Sendable, Equatable, Codable {
    /// EventKit adapter is wired in Vault (`#if canImport(EventKit)`). Linux reports true as “code present”.
    public var eventKitWired: Bool
    /// This process injects `FakeAppleCalendarStore` / `FakeAppleRemindersStore` (Linux / tests).
    public var linuxUsesFakes: Bool
    /// Listing events did not rewrite daily markdown.
    public var dailyUnchanged: Bool
    public var indexInsideVault: Bool

    public init(
        eventKitWired: Bool,
        linuxUsesFakes: Bool,
        dailyUnchanged: Bool,
        indexInsideVault: Bool
    ) {
        self.eventKitWired = eventKitWired
        self.linuxUsesFakes = linuxUsesFakes
        self.dailyUnchanged = dailyUnchanged
        self.indexInsideVault = indexInsideVault
    }

    public static func evaluate(
        dailyUnchanged: Bool,
        indexInsideVault: Bool,
        eventKitAvailable: Bool = EventKitNotes.eventKitAvailable
    ) -> EventKitProof {
        EventKitProof(
            eventKitWired: EventKitNotes.eventKitWired,
            linuxUsesFakes: !eventKitAvailable,
            dailyUnchanged: dailyUnchanged,
            indexInsideVault: indexInsideVault
        )
    }
}

/// Contract notes so XCTest / DevHarness never import EventKit.
public enum EventKitNotes: Sendable {
    /// EventKit types stay in `LociVault` behind `canImport(EventKit)`.
    public static let eventKitStaysOutOfCore = true
    /// Wiring exists (code present). Linux reports true like `photosPickerWired`.
    public static let eventKitWired = true
    /// Compile-time EventKit availability (false on Linux SPM).
    public static var eventKitAvailable: Bool {
        #if canImport(EventKit)
        true
        #else
        false
        #endif
    }
    public static var linuxUsesFakes: Bool { !eventKitAvailable }

    public static let permissionCopyCalendar =
        "Loci shows Calendar events on the daily note as chrome. Daily markdown is never rewritten. Grant Calendar access in System Settings if the list is empty."

    public static let permissionCopyReminders =
        "Reminders sync is optional and only runs when you tap Sync. Grant Reminders access in System Settings if pull/push does nothing."
}
