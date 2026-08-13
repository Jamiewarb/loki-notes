import SwiftUI
import LociCore
import LociDesignSystem

/// Explicit AI assist actions — summarize / rewrite / translate / autofill (PR30).
///
/// Never runs on the typing path. Proposals apply via EditorSession / ObjectServing.
struct AIAssistPanelView: View {
    var services: AppServices
    var objectID: ObjectID?
    @State private var status = "Choose an action. Nothing runs until you tap."
    @State private var lastSummary: String?
    @State private var lastBody: String?
    @State private var lastNotes: [String] = []
    @State private var busy = false

    private var store: AIStore {
        AIStore(ai: services.ai)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.lg)) {
            HStack(spacing: LociSpacing.stack(.md)) {
                LociIcon(Route.ai.systemImage, size: 22)
                    .foregroundStyle(LociColors.accent)
                Text(Route.ai.title)
                    .font(LociTypography.font(.headline))
                    .foregroundStyle(LociColors.ink)
            }

            Text(
                "On-device heuristics by default. BYOK never uploads unless you opt in. Apply writes through ObjectServing only."
            )
            .font(LociTypography.font(.callout))
            .foregroundStyle(LociColors.inkSoft)
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: LociSpacing.stack(.sm)) {
                LociButton("Summarize", style: .primary) {
                    Task { await run(.summarize) }
                }
                .disabled(busy || objectID == nil)
                LociButton("Rewrite", style: .secondary) {
                    Task { await run(.rewrite) }
                }
                .disabled(busy || objectID == nil)
                LociButton("Translate", style: .secondary) {
                    Task { await run(.translate) }
                }
                .disabled(busy || objectID == nil)
                LociButton("Autofill props", style: .secondary) {
                    Task { await run(.autofillProperties) }
                }
                .disabled(busy || objectID == nil)
            }

            if objectID == nil {
                Text("Open an object to run assist on its title/body.")
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.inkSoft)
            }

            if let lastSummary {
                Text(lastSummary)
                    .font(LociTypography.font(.body))
                    .foregroundStyle(LociColors.ink)
                    .textSelection(.enabled)
            }
            if let lastBody {
                Text(lastBody)
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.inkSoft)
                    .textSelection(.enabled)
                    .lineLimit(12)
            }
            if !lastNotes.isEmpty {
                Text(lastNotes.joined(separator: " · "))
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.inkSoft)
            }

            Text(status)
                .font(LociTypography.font(.callout))
                .foregroundStyle(LociColors.ink)

            Spacer(minLength: 0)
        }
        .padding(LociSpacing.stack(.lg))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func run(_ action: AIAction) async {
        guard let objectID else {
            status = "Open an object first."
            return
        }
        busy = true
        defer { busy = false }
        do {
            let objects = try await services.ensureObjectService()
            let opened = try await objects.open(id: objectID)
            let type = try await services.schema.loadType(opened.meta.typeID)
            let settings = try await store.loadSettings()
            let request = AIRequest(
                action: action,
                objectID: objectID,
                title: opened.meta.title,
                bodyMarkdown: opened.bodyMarkdown,
                propertyDefs: type.properties,
                existingProperties: opened.meta.properties,
                targetLanguage: settings.targetLanguage,
                allowRemoteUpload: false
            )
            let proposal = try await store.run(request)
            lastSummary = proposal.summary
            lastBody = proposal.proposedBody
            lastNotes = proposal.notes
            status =
                "Proposal from \(proposal.provider.rawValue) · uploaded=\(proposal.uploaded). Applying…"

            if action == .summarize {
                status = "Summary ready (not written to vault)."
                return
            }

            if let body = proposal.proposedBody,
                let bridge = services.activeEditorSession,
                bridge.objectID == objectID
            {
                try bridge.applyProposedBody(body)
            }
            if let props = proposal.proposedProperties,
                let bridge = services.activeEditorSession,
                bridge.objectID == objectID
            {
                var merged = bridge.currentProperties
                for (k, v) in props { merged[k] = v }
                bridge.applyProperties(merged)
            } else {
                _ = try await store.apply(proposal, using: objects)
            }
            status = "Applied via ObjectServing / EditorSession."
        } catch {
            status = "AI failed: \(error.localizedDescription)"
        }
    }
}
