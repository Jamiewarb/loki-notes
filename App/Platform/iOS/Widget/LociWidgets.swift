import Foundation
import LociCore

#if canImport(WidgetKit)
import WidgetKit
import SwiftUI
import LociVault

#if canImport(AppIntents)
import AppIntents
#endif

/// Home Screen widget (PR37) — Open today / Quick add.
///
/// Open today uses `loci://daily/today` (main app `onOpenURL`). Quick add
/// enqueues `.loci/inbox/` via `CaptureInboxWriter` when a vault resolves;
/// otherwise deep-links into capture. Does **not** touch SQLite.
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

    func getTimeline(in context: Context, completion: @escaping (Timeline<LociWidgetEntry>) -> Void)
    {
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
            Link("Open today", destination: LociDeepLink.dailyTodayURL)
                .font(.caption)
            #if canImport(AppIntents)
            Button(intent: LociQuickAddIntent()) {
                Text("Quick add")
            }
            .font(.caption2)
            #else
            Link("Quick add", destination: LociDeepLink.captureURL)
                .font(.caption2)
            #endif
        }
        .padding()
        .widgetURL(LociDeepLink.dailyTodayURL)
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

#if canImport(AppIntents)
/// Enqueue a line via `CaptureInboxWriter` when the vault resolves; else open capture.
struct LociQuickAddIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick add"
    static var description = IntentDescription("Add a line to today’s Loci inbox.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Note")
    var text: String

    init() {
        text = ""
    }

    init(text: String) {
        self.text = text
    }

    func perform() async throws -> some IntentResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            throw $text.needsValueError("What should Loci capture?")
        }
        if let path = try await Self.enqueueIfPossible(text: trimmed) {
            _ = path
            return .result()
        }
        throw $text.needsValueError(
            "Loci vault is unavailable. Open Loci and use Capture (\(LociDeepLink.captureAbsoluteString))."
        )
    }

    /// Widget-process enqueue — vault JSON only, no index.
    static func enqueueIfPossible(text: String) async throws -> String? {
        let item = ShareInboxFactory.inboxItem(text: text, url: nil, source: .widget)
        guard let vault = CaptureVaultResolver.resolve() else { return nil }
        return try await CaptureInboxWriter.enqueue(item, vault: vault)
    }
}

/// Opens the main app on today’s daily note (`loci://daily/today`).
struct LociOpenTodayIntent: AppIntent {
    static var title: LocalizedStringResource = "Open today"
    static var description = IntentDescription("Open today’s Loci daily note.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        .result()
    }
}
#endif

#else
/// Linux / non-WidgetKit stub — documents the widget surface for PR37.
public enum LociWidgetStub {
    public static let kind = "LociTodayWidget"
    public static let actions = ["openToday", "quickAdd"]
    public static let openTodayURL = LociDeepLink.dailyTodayAbsoluteString
    public static let quickAddFallbackURL = LociDeepLink.captureAbsoluteString
}
#endif
