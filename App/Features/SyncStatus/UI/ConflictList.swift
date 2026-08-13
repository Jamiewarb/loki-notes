import SwiftUI
import LociCore
import LociDesignSystem

/// Lists conflicted-copy files (markdown + media) from the vault scanner (PR21).
struct ConflictListView: View {
    @Bindable var services: AppServices
    @State private var items: [SyncConflictItem] = []
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.sm)) {
            Text("Conflicts")
                .font(LociTypography.font(.headline))
                .foregroundStyle(LociColors.ink)

            Text("iCloud conflicted copies stay on disk; the index may keep both. Resolve by choosing a winner in Files.")
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            if let errorMessage {
                Text(errorMessage)
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.danger)
            } else if items.isEmpty {
                Text("No conflicted copies detected")
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.accent)
                    .accessibilityIdentifier("conflict-list-empty")
            } else {
                VStack(alignment: .leading, spacing: LociSpacing.stack(.xs)) {
                    ForEach(items, id: \.relativePath) { item in
                        HStack(alignment: .firstTextBaseline, spacing: LociSpacing.stack(.sm)) {
                            Text(kindLabel(item.kind))
                                .font(LociTypography.font(.overline))
                                .foregroundStyle(LociColors.inkSoft)
                                .frame(width: 56, alignment: .leading)
                            Text(item.relativePath)
                                .font(LociTypography.font(.caption))
                                .foregroundStyle(LociColors.ink)
                                .textSelection(.enabled)
                        }
                        .accessibilityIdentifier("conflict-row")
                    }
                }
                .accessibilityIdentifier("conflict-list")
            }
        }
        .task { await reload() }
        .onChange(of: services.syncRefreshNonce) { _, _ in
            Task { await reload() }
        }
    }

    private func kindLabel(_ kind: SyncConflictKind) -> String {
        switch kind {
        case .markdown: return "MD"
        case .media: return "MEDIA"
        case .other: return "FILE"
        }
    }

    private func reload() async {
        do {
            items = try await services.listConflictedCopies()
            errorMessage = nil
        } catch {
            items = []
            errorMessage = error.localizedDescription
        }
    }
}
