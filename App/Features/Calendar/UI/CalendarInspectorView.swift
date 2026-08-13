import SwiftUI
import LociCore
import LociDesignSystem

/// Calendar inspector — explains index-derived dots and jump behavior (PR25).
struct CalendarInspectorView: View {
    var services: AppServices

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LociSpacing.stack(.md)) {
                Text("Calendar")
                    .font(LociTypography.font(.overline))
                    .tracking(0.08)
                    .foregroundStyle(LociColors.inkSoft)
                Text("Index dots · daily jump")
                    .font(LociTypography.font(.headline))
                    .foregroundStyle(LociColors.ink)
                Text(
                    "Month/week cells read `IndexQuerying.calendarMarkers` (daily presence, FTS content, creations). Selecting a day calls `DailyNoteServing.ensure` then `Navigating.open` — calendar chrome never rewrites vault markdown."
                )
                .font(LociTypography.font(.callout))
                .foregroundStyle(LociColors.inkSoft)
                Text(
                    "Paths stay deterministic: `daily/YYYY-MM-DD.md` / `daily-YYYY-MM-DD`."
                )
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.inkSoft)
                Text(
                    "Inspected day: \(DailyNoteIdentity.title(for: services.inspectedDailyDay))"
                )
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.inkSoft)
                .accessibilityIdentifier("calendar-inspector-day")
            }
            .padding(LociSpacing.stack(.lg))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(LociColors.panel.opacity(0.55))
        .lociAppear(.panel)
        .accessibilityIdentifier("calendar-inspector")
    }
}
