import SwiftUI
import LociCore
import LociDesignSystem

/// BYOK + privacy settings for AI assist (PR30). Credentials never land in the vault.
struct AISettingsView: View {
    var services: AppServices
    @State private var preferred: AIProviderKind = .onDeviceHeuristics
    @State private var uploadOptIn = false
    @State private var byokName = ""
    @State private var targetLanguage = "es"
    @State private var apiKeyDraft = ""
    @State private var status = "On-device heuristics by default. Vault stays local unless you opt in."

    private var store: AIStore {
        AIStore(ai: services.ai)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.md)) {
            Text("AI assist")
                .font(LociTypography.font(.headline))
                .foregroundStyle(LociColors.ink)

            Text(
                "Prefer on-device. BYOK keys live in Application Support / Keychain — never in the vault. Upload requires an explicit opt-in."
            )
            .font(LociTypography.font(.callout))
            .foregroundStyle(LociColors.inkSoft)
            .fixedSize(horizontal: false, vertical: true)

            Picker("Provider", selection: $preferred) {
                Text("On-device heuristics").tag(AIProviderKind.onDeviceHeuristics)
                Text("Apple Intelligence").tag(AIProviderKind.appleIntelligence)
                Text("BYOK").tag(AIProviderKind.byok)
            }
            .pickerStyle(.menu)

            Toggle("Allow uploading this object when I opt in per action", isOn: $uploadOptIn)

            LociTextField("BYOK provider", text: $byokName, placeholder: "openai")
            LociTextField("Target language", text: $targetLanguage, placeholder: "es")
            LociTextField("API key (not vault)", text: $apiKeyDraft, placeholder: "sk-…")

            HStack(spacing: LociSpacing.stack(.md)) {
                LociButton("Save settings", style: .primary) {
                    Task { await save() }
                }
                LociButton("Clear key", style: .secondary) {
                    Task { await clearKey() }
                }
            }

            Text(status)
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.inkSoft)
        }
        .padding(.vertical, LociSpacing.stack(.sm))
        .task { await reload() }
    }

    private func reload() async {
        do {
            let s = try await store.loadSettings()
            preferred = s.preferredProvider
            uploadOptIn = s.uploadVaultOptIn
            byokName = s.byokProviderName ?? ""
            targetLanguage = s.targetLanguage
        } catch {
            status = "Could not load AI settings: \(error.localizedDescription)"
        }
    }

    private func save() async {
        do {
            let s = AISettings(
                preferredProvider: preferred,
                uploadVaultOptIn: uploadOptIn,
                byokProviderName: byokName.isEmpty ? nil : byokName,
                targetLanguage: targetLanguage.isEmpty ? "es" : targetLanguage
            )
            try await store.saveSettings(s)
            if !apiKeyDraft.isEmpty {
                let provider = s.byokProviderName ?? "default"
                try services.aiCredentials.setAPIKey(apiKeyDraft, for: provider)
                apiKeyDraft = ""
            }
            status = "Saved. uploadVaultOptIn=\(uploadOptIn)."
        } catch {
            status = "Save failed: \(error.localizedDescription)"
        }
    }

    private func clearKey() async {
        do {
            let provider = byokName.isEmpty ? "default" : byokName
            try services.aiCredentials.clear(provider: provider)
            status = "Cleared key for \(provider)."
        } catch {
            status = "Clear failed: \(error.localizedDescription)"
        }
    }
}
