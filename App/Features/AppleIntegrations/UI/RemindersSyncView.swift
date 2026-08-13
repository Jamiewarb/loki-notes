import SwiftUI
import LociCore
import LociDesignSystem

/// Reminders sync toggle + explicit Sync action (PR31 / PR36).
///
/// Settings live outside the vault. Sync never runs on the typing path.
struct RemindersSyncView: View {
    var services: AppServices
    var compact: Bool = false
    @State private var syncEnabled = false
    @State private var authStatus: AppleAuthStatus = .notDetermined
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

            Text("Reminders access: \(authStatus.permissionLabel)")
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.inkSoft)

            if authStatus != .authorized {
                Text(EventKitNotes.permissionCopyReminders)
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)

                if authStatus == .notDetermined {
                    LociButton("Grant Reminders access", style: .secondary) {
                        Task { await requestAccess() }
                    }
                }
            }

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

    private func requestAccess() async {
        authStatus = await store.requestRemindersAccess()
        if authStatus == .denied {
            status = "Reminders access denied — sync will no-op until granted in System Settings."
        }
    }

    private func reload() async {
        authStatus = store.remindersAuthorizationStatus()
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
            if enabled {
                authStatus = await store.requestRemindersAccess()
            }
            if enabled, authStatus == .denied {
                status = "Sync enabled, but Reminders access is denied."
            } else {
                status = enabled ? "Sync enabled." : "Sync disabled."
            }
        } catch {
            status = "Save failed: \(error.localizedDescription)"
        }
    }

    private func sync() async {
        do {
            if authStatus != .authorized {
                authStatus = await store.requestRemindersAccess()
            }
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
