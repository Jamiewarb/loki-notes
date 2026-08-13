import SwiftUI
import LociCore
import LociDesignSystem

/// Reminders sync toggle + explicit Sync action (PR31).
///
/// Settings live outside the vault. Sync never runs on the typing path.
struct RemindersSyncView: View {
    var services: AppServices
    var compact: Bool = false
    @State private var syncEnabled = false
    @State private var status = "Reminders sync is off by default. Explicit Sync only."

    private var store: AppleIntegrationsStore {
        AppleIntegrationsStore(apple: services.apple)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(compact ? .md : .lg)) {
            if !compact {
                HStack(spacing: LociSpacing.stack(.md)) {
                    LociIcon(Route.apple.systemImage, size: 22)
                        .foregroundStyle(LociColors.accent)
                    Text(Route.apple.title)
                        .font(LociTypography.font(.display))
                        .foregroundStyle(LociColors.ink)
                }
                .lociAppear(.soft)
            } else {
                Text("Reminders sync")
                    .font(LociTypography.font(.headline))
                    .foregroundStyle(LociColors.ink)
            }

            Text(
                "Pull due reminders into today’s daily as task lines. Push open daily tasks out. Settings in Application Support — never the vault."
            )
            .font(LociTypography.font(.callout))
            .foregroundStyle(LociColors.inkSoft)
            .fixedSize(horizontal: false, vertical: true)

            Toggle("Enable Reminders sync", isOn: $syncEnabled)
                .onChange(of: syncEnabled) { _, value in
                    Task { await saveToggle(value) }
                }

            HStack(spacing: LociSpacing.stack(.md)) {
                LociButton("Sync Reminders", style: .primary) {
                    Task { await sync() }
                }
                .disabled(!syncEnabled)
            }

            Text(status)
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.inkSoft)

            Spacer(minLength: 0)
        }
        .padding(compact ? LociSpacing.stack(.sm) : LociSpacing.stack(.lg))
        .frame(maxWidth: .infinity, maxHeight: compact ? nil : .infinity, alignment: .topLeading)
        .task { await reload() }
    }

    private func reload() async {
        do {
            let s = try await store.loadSettings()
            syncEnabled = s.remindersSyncEnabled
        } catch {
            status = "Could not load settings: \(error.localizedDescription)"
        }
    }

    private func saveToggle(_ enabled: Bool) async {
        do {
            try await store.saveSettings(AppleIntegrationSettings(remindersSyncEnabled: enabled))
            status = enabled ? "Sync enabled." : "Sync disabled."
        } catch {
            status = "Save failed: \(error.localizedDescription)"
        }
    }

    private func sync() async {
        do {
            let objects = try await services.ensureObjectService()
            let daily = try await services.ensureDailyNoteService()
            let index = try await services.ensureIndex()
            let day = services.inspectedDailyDay
            let pulled = try await store.pullRemindersIntoToday(
                day: day,
                daily: daily,
                objects: objects
            )
            let pushed = try await store.pushOpenTasksToReminders(day: day, index: index)
            status = "Pulled \(pulled) · pushed \(pushed)."
        } catch {
            status = "Sync failed: \(error.localizedDescription)"
        }
    }
}
