import Foundation
import LociCore

/// Picks EventKit stores on Apple, fakes on Linux (PR36).
public enum AppleStoreFactory: Sendable {
    public static func makeCalendarStore() -> any AppleCalendarServing {
        #if canImport(EventKit)
        return EventKitCalendarStore()
        #else
        return FakeAppleCalendarStore()
        #endif
    }

    public static func makeRemindersStore() -> any AppleRemindersServing {
        #if canImport(EventKit)
        return EventKitRemindersStore()
        #else
        return FakeAppleRemindersStore()
        #endif
    }

    public static var usesEventKit: Bool {
        #if canImport(EventKit)
        true
        #else
        false
        #endif
    }
}
