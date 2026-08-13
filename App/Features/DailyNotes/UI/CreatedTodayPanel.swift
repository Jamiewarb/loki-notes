import SwiftUI
import LociCore
import LociDesignSystem

/// Inspector panel: live links to objects created on a calendar day.
///
/// **Source:** `IndexQuerying.created(on:)` only — never writes vault files.
/// **UX:** Excludes Daily-type objects (you are already on that day’s note). Pages and
/// future custom types created that day appear as tappable links via `Navigating`.
struct CreatedTodayPanel: View {
    var services: AppServices
    var day: Date
    var calendar: Calendar = .current

    @State private var items: [LociObjectMeta] = []
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.md)) {
            Text("Created today")
                .font(LociTypography.font(.headline))
                .foregroundStyle(LociColors.ink)

            Text(
                "Index-only list for \(dayLabel). Creating objects never rewrites this daily .md."
            )
            .font(LociTypography.font(.callout))
            .foregroundStyle(LociColors.inkSoft)
            .fixedSize(horizontal: false, vertical: true)

            if isLoading && items.isEmpty {
                ProgressView()
                    .controlSize(.small)
            } else if items.isEmpty {
                Text("Nothing else created this day yet.")
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.inkSoft)
                    .accessibilityIdentifier("created-today-empty")
            } else {
                VStack(alignment: .leading, spacing: LociSpacing.stack(.sm)) {
                    ForEach(items, id: \.id.uuidString) { item in
                        Button {
                            Task { await services.open(objectID: item.id) }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title.isEmpty ? "Untitled" : item.title)
                                    .font(LociTypography.font(.callout))
                                    .foregroundStyle(LociColors.ink)
                                Text("\(item.typeID.rawValue) · \(item.relativePath)")
                                    .font(LociTypography.font(.caption))
                                    .foregroundStyle(LociColors.inkSoft)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(
                            "created-today-row-\(item.id.uuidString.lowercased())"
                        )
                    }
                }
                .accessibilityIdentifier("created-today-list")
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.danger)
            }

            Text("Daily notes are omitted here (already open). Snapshot embeds are optional later.")
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .task(id: dayTaskID) { await reload() }
        .accessibilityIdentifier("created-today-panel")
    }

    private var dayTaskID: String {
        DailyNoteIdentity.dateKey(for: day, calendar: calendar)
    }

    private var dayLabel: String {
        DailyNoteIdentity.title(for: day, calendar: calendar)
    }

    private func reload() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let index = try await services.ensureIndex()
            let raw = try await index.created(on: day)
            items = Self.filterForPanel(raw)
            errorMessage = nil
        } catch {
            items = []
            errorMessage = error.localizedDescription
        }
    }

    /// Drop Daily-type rows so the inspector lists other objects created that day.
    static func filterForPanel(_ metas: [LociObjectMeta]) -> [LociObjectMeta] {
        metas.filter { $0.typeID != .daily }
    }
}
