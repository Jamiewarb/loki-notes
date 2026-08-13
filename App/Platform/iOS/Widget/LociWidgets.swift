import Foundation
import LociCore

#if canImport(WidgetKit)
import WidgetKit
import SwiftUI

/// Home Screen widget stub (PR26) — Open today / Quick add.
///
/// Quick add enqueues `.loci/inbox/` (or deep-links into the app). Open today
/// uses the deterministic `daily/YYYY-MM-DD.md` route. Full WidgetKit target
/// is Apple-only; Linux agents keep these sources as stubs.
struct LociWidgetEntry: TimelineEntry {
    let date: Date
    let dayKey: String
}

struct LociWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> LociWidgetEntry {
        LociWidgetEntry(date: Date(), dayKey: DailyNoteIdentity.title(for: Date()))
    }

    func getSnapshot(in context: Context, completion: @escaping (LociWidgetEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LociWidgetEntry>) -> Void) {
        let entry = placeholder(in: context)
        completion(Timeline(entries: [entry], policy: .atEnd))
    }
}

struct LociWidgetView: View {
    let entry: LociWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Loci")
                .font(.headline)
            Text("Today · \(entry.dayKey)")
                .font(.caption)
            Text("Open today · Quick add")
                .font(.caption2)
        }
        .padding()
    }
}

@main
struct LociWidgetsBundle: WidgetBundle {
    var body: some Widget {
        LociTodayWidget()
    }
}

struct LociTodayWidget: Widget {
    let kind = "LociTodayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LociWidgetProvider()) { entry in
            LociWidgetView(entry: entry)
        }
        .configurationDisplayName("Loci Today")
        .description("Open today’s daily note or quick-add an inbox line.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
#else
/// Linux / non-WidgetKit stub — documents the widget surface for PR26.
public enum LociWidgetStub {
    public static let kind = "LociTodayWidget"
    public static let actions = ["openToday", "quickAdd"]
}
#endif
