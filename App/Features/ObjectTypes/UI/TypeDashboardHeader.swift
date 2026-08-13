import SwiftUI
import LociCore
import LociDesignSystem

/// Title, tag filter, archive caption, and rename chrome for a type dashboard.
struct TypeDashboardHeader: View {
    let type: ObjectType?
    let typeID: ObjectTypeID
    let isBusy: Bool
    let hideArchived: Bool
    let archivedHiddenCount: Int
    let activeTagFilter: String?
    let tagFilterHiddenCount: Int
    @Binding var tagFilterDraft: String
    @Binding var renameDraft: String
    @Binding var showRename: Bool
    var onBack: () -> Void
    var onRename: () async -> Void
    var onDelete: () async -> Void
    var onCreate: () async -> Void
    var onApplyTagFilter: () -> Void
    var onClearTagFilter: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.lg)) {
            HStack(spacing: LociSpacing.stack(.md)) {
                LociButton("← Types", style: .secondary) { onBack() }
                Spacer(minLength: 0)
                if let type, !type.isBuiltIn {
                    LociButton("Rename", style: .secondary) {
                        renameDraft = type.name
                        showRename = true
                    }
                    .disabled(isBusy)
                    LociButton("Delete", style: .secondary) { Task { await onDelete() } }
                        .disabled(isBusy)
                }
                LociButton("New \(type?.name ?? "object")", style: .primary) {
                    Task { await onCreate() }
                }
                .disabled(isBusy)
            }

            HStack(spacing: LociSpacing.stack(.md)) {
                LociIcon(type?.icon ?? "square.grid.2x2", size: 22)
                    .foregroundStyle(LociColors.accent)
                Text(type?.name ?? typeID.rawValue)
                    .font(LociTypography.font(.display))
                    .foregroundStyle(LociColors.ink)
            }
            .lociAppear(.soft)

            Text(".\(typeID.rawValue) · objects live under objects/\(typeID.rawValue)/ — filesystem sharding only.")
                .font(LociTypography.font(.body))
                .foregroundStyle(LociColors.inkSoft)
                .frame(maxWidth: 520, alignment: .leading)

            HStack(spacing: LociSpacing.stack(.sm)) {
                TextField("Filter by #tag", text: $tagFilterDraft)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 220)
                    .onSubmit { onApplyTagFilter() }
                LociButton("Filter", style: .secondary) { onApplyTagFilter() }
                if activeTagFilter != nil {
                    LociButton("Clear", style: .secondary) { onClearTagFilter() }
                }
            }

            if let activeTagFilter {
                Text(
                    tagFilterHiddenCount > 0
                        ? "Showing \(TagNormalization.display(activeTagFilter)) · \(tagFilterHiddenCount) hidden."
                        : "Showing \(TagNormalization.display(activeTagFilter))."
                )
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.inkSoft)
            }
            if hideArchived {
                Text(
                    archivedHiddenCount > 0
                        ? "Hiding \(archivedHiddenCount) archived (#archive / status=Archived)."
                        : "Archived objects hidden by default (PARA)."
                )
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.inkSoft)
            }

            if showRename {
                HStack(spacing: LociSpacing.stack(.md)) {
                    TextField("Type name", text: $renameDraft)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 280)
                    LociButton("Save name", style: .primary) { Task { await onRename() } }
                        .disabled(isBusy)
                    LociButton("Cancel", style: .secondary) { showRename = false }
                }
            }
        }
    }
}
