import SwiftUI
import LociCore
import LociDesignSystem

/// Public entry for SyncStatus feature (PR21) — chip, conflicts, rebuild, reveal path.
///
/// Writes vault? **no** (except optional conflict resolve later). Index rebuild is local Application Support.
/// Protocols: `SyncStatusProviding`, `VaultServing` (via composition).
enum SyncStatusFeature {
    @MainActor
    static func chip(services: AppServices) -> some View {
        SyncChip(services: services)
    }

    @MainActor
    static func conflictList(services: AppServices) -> some View {
        ConflictListView(services: services)
    }

    @MainActor
    static func settingsSection(services: AppServices) -> some View {
        SyncSettingsSection(services: services)
    }
}
