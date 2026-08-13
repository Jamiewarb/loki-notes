import SwiftUI
import LociCore
import LociDesignSystem

/// Daily inspector chrome: Apple Calendar / fake events for the inspected day (PR31).
///
/// Listing events never rewrites daily markdown. “Create Meeting” writes via ObjectServing.
struct DailyEventsPanel: View {
    var services: AppServices
    var day: Date
    @State private var events: [AppleCalendarEvent] = []
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

            Text("Apple Calendar / fake store · Create Meeting → objects/meeting/")
                .font(LociTypography.font(.callout))
                .foregroundStyle(LociColors.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            if events.isEmpty {
                Text("No events for this day.")
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

    private func reload() async {
        do {
            events = try await store.eventsForDaily(day: day)
            status = events.isEmpty
                ? "No events — daily markdown unchanged."
                : "\(events.count) event(s) · chrome only."
        } catch {
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
