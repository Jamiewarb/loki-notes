import SwiftUI
import LociCore
import LociDesignSystem

/// Import UI — pick source kind, dry-run summary, then apply (PR27).
///
/// On Linux / DevHarness the demo script drives fixtures; this view is the
/// in-app surface wired through `ImportServing`.
struct ImportPanelView: View {
    var services: AppServices
    @State private var status = "Ready — dry-run a markdown folder, Obsidian vault, or Capacities export."
    @State private var summaryText = ""
    @State private var lastKind: String = "—"
    @State private var lastWritten = 0
    @State private var lastSkipped = 0
    @State private var conflictPolicy: ImportConflictPolicy = .skip

    private var store: ImportStore {
        ImportStore(importer: services.importer)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.lg)) {
            HStack(spacing: LociSpacing.stack(.md)) {
                LociIcon(Route.importExport.systemImage, size: 22)
                    .foregroundStyle(LociColors.accent)
                Text(Route.importExport.title)
                    .font(LociTypography.font(.headline))
                    .foregroundStyle(LociColors.ink)
            }

            Text(
                "Importers write real vault files under `objects/`, `daily/`, and `media/`, then update the local index. Dry-run first; ObjectID / daily paths are preserved when detectable."
            )
            .font(LociTypography.font(.callout))
            .foregroundStyle(LociColors.inkSoft)
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: LociSpacing.stack(.md)) {
                policyButton(.skip, label: "Skip conflicts")
                policyButton(.rename, label: "Rename")
                policyButton(.overwrite, label: "Overwrite")
            }

            Text(status)
                .font(LociTypography.font(.callout))
                .foregroundStyle(LociColors.ink)

            VStack(alignment: .leading, spacing: LociSpacing.stack(.sm)) {
                Text("Last kind: \(lastKind)")
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.inkSoft)
                Text("Written \(lastWritten) · skipped \(lastSkipped)")
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.inkSoft)
            }

            if !summaryText.isEmpty {
                ScrollView {
                    Text(summaryText)
                        .font(LociTypography.font(.caption))
                        .foregroundStyle(LociColors.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 280)
            }

            Spacer(minLength: 0)
        }
        .padding(LociSpacing.stack(.lg))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func policyButton(_ policy: ImportConflictPolicy, label: String) -> some View {
        let selected = conflictPolicy == policy
        return LociButton(label, style: selected ? .primary : .secondary) {
            conflictPolicy = policy
            status = "Conflict policy: \(policy.rawValue)"
        }
    }
}

struct ImportInspectorView: View {
    var services: AppServices

    var body: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.md)) {
            Text("Import")
                .font(LociTypography.font(.overline))
                .foregroundStyle(LociColors.inkSoft)
            Text("Dry-run → apply")
                .font(LociTypography.font(.headline))
                .foregroundStyle(LociColors.ink)
            Text(
                "No feature→feature imports — ImportServing + VaultServing + SchemaServing. Index stays outside the vault."
            )
            .font(LociTypography.font(.callout))
            .foregroundStyle(LociColors.inkSoft)
            Spacer(minLength: 0)
        }
        .padding(LociSpacing.stack(.lg))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
