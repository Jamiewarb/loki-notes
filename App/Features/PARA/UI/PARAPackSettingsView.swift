import SwiftUI
import LociCore
import LociDesignSystem

/// Settings / onboarding: Apply PARA pack (idempotent) + short explainer (PR15).
struct PARAPackSettingsView: View {
    @Bindable var services: AppServices
    @State private var isBusy = false
    @State private var statusMessage: String?
    @State private var lastResult: PARAPackResult?
    @State private var alreadyApplied = false
    @State private var hideArchived = false

    var body: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.md)) {
            Text("PARA starter pack")
                .font(LociTypography.font(.headline))
                .foregroundStyle(LociColors.ink)

            PARAFeature.explainerText()

            VStack(alignment: .leading, spacing: LociSpacing.stack(.xs)) {
                Text("Resource: \(PARAPack.resourceGuidance)")
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.inkSoft)
                Text("Archive: \(PARAPack.archiveGuidance)")
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.inkSoft)
            }

            LociButton(
                alreadyApplied ? "Re-apply PARA pack" : "Apply PARA pack",
                style: .primary
            ) {
                Task { await applyPack() }
            }
            .disabled(isBusy)
            .accessibilityIdentifier("apply-para-pack")

            if alreadyApplied {
                Text(
                    hideArchived
                        ? "Pack applied · dashboards hide archived by default"
                        : "Pack applied · archived objects are visible"
                )
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.accent)
            }

            if let lastResult {
                Text(
                    "Project/Area ready · templates \(lastResult.projectTemplateID), \(lastResult.areaTemplateID)"
                )
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.inkSoft)
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.inkSoft)
            }
        }
        .task { await refresh() }
    }

    private func refresh() async {
        do {
            let space = try await services.schema.loadSpaceSettings()
            alreadyApplied = space.paraPackApplied
            hideArchived = space.hideArchived
        } catch {
            alreadyApplied = false
            hideArchived = false
        }
    }

    private func applyPack() async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await services.schema.bootstrapSchema(spaceName: services.spaceName)
            let result = try await PARAPack.apply(to: services.schema)
            lastResult = result
            alreadyApplied = true
            hideArchived = result.hideArchived
            let created = result.createdTypeIDs.isEmpty
                ? "already present"
                : "created \(result.createdTypeIDs.joined(separator: ", "))"
            statusMessage =
                "PARA ready (\(created)). Resource=\(result.resourceApproach); Archive=\(result.archiveApproach)."
        } catch {
            statusMessage = "PARA apply failed: \(error.localizedDescription)"
        }
    }
}
