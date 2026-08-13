import SwiftUI
import LociCore
import LociDesignSystem

/// Daily inspector chrome: Apple Calendar / EventKit / fake events for the inspected day (PR31 / PR36).
///
/// Listing events never rewrites daily markdown. “Create Meeting” writes via ObjectServing.
struct DailyEventsPanel: View {
    var services: AppServices
    var day: Date
    @State private var events: [AppleCalendarEvent] = []
    @State private var authStatus: AppleAuthStatus = .notDetermined
    @State private var status = "Events are UI chrome — daily .md stays untouched."
    @State private var lastMeetingPath: String?

    private var store: AppleIntegrationsStore {
        AppleIntegrationsStore(apple: services.apple)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.md)) {
            Text("Calendar events")
                .font(LociTypography.font(.overline))
                .tracking(0.08)
                .foregroundStyle(LociColors.inkSoft)

            Text("Apple Calendar · Create Meeting → objects/meeting/")
                .font(LociTypography.font(.callout))
                .foregroundStyle(LociColors.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            Text("Calendar access: \(authStatus.permissionLabel)")
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.inkSoft)

            if authStatus != .authorized {
                Text(EventKitNotes.permissionCopyCalendar)
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)

                if authStatus == .notDetermined {
                    LociButton("Grant Calendar access", style: .secondary) {
                        Task { await requestAccessAndReload() }
                    }
                }
            }

            if events.isEmpty {
                Text(authStatus == .denied ? "No events — Calendar access denied." : "No events for this day.")
                    .font(LociTypography.font(.callout))
                    .foregroundStyle(LociColors.inkSoft)
            } else {
                ForEach(events) { event in
                    VStack(alignment: .leading, spacing: LociSpacing.stack(.xs)) {
                        Text(event.title)
                            .font(LociTypography.font(.headline))
                            .foregroundStyle(LociColors.ink)
                        if let location = event.location, !location.isEmpty {
                            Text(location)
                                .font(LociTypography.font(.caption))
                                .foregroundStyle(LociColors.inkSoft)
                        }
                        LociButton("Create Meeting", style: .secondary) {
                            Task { await createMeeting(event) }
                        }
                    }
                    .padding(.vertical, LociSpacing.stack(.xs))
                }
            }

            if let lastMeetingPath {
                Text("Meeting: \(lastMeetingPath)")
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.accent)
            }

            Text(status)
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.inkSoft)
        }
        .task(id: day) { await reload() }
    }

    private func requestAccessAndReload() async {
        authStatus = await store.requestCalendarAccess()
        await reload()
    }

    private func reload() async {
        authStatus = store.calendarAuthorizationStatus()
        if authStatus == .notDetermined {
            authStatus = await store.requestCalendarAccess()
        }
        do {
            events = try await store.eventsForDaily(day: day)
            if authStatus == .denied {
                status = "Calendar access denied — empty list. Daily markdown unchanged."
            } else if events.isEmpty {
                status = "No events — daily markdown unchanged."
            } else {
                status = "\(events.count) event(s) · chrome only."
            }
        } catch {
            events = []
            status = "Events failed: \(error.localizedDescription)"
        }
    }

    private func createMeeting(_ event: AppleCalendarEvent) async {
        do {
            let objects = try await services.ensureObjectService()
            let index = try await services.ensureIndex()
            let meta = try await store.createMeeting(
                from: event,
                using: objects,
                schema: services.schema,
                index: index
            )
            lastMeetingPath = meta.relativePath
            status = "Created \(meta.relativePath)"
            await services.open(objectID: meta.id)
        } catch {
            status = "Create Meeting failed: \(error.localizedDescription)"
        }
    }
}
