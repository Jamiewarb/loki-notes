import SwiftUI
import LociCore
import LociDesignSystem
import LociVault

/// Create a custom object type (name, icon, color/slug). Properties stay empty until PR13.
struct TypeEditorView: View {
    var services: AppServices
    var onSaved: () -> Void
    var onCancel: () -> Void

    @State private var name: String = ""
    @State private var icon: String = "book"
    @State private var color: String = "#8B5A2B"
    @State private var slugOverride: String = ""
    @State private var errorMessage: String?
    @State private var isBusy = false

    var body: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.lg)) {
            HStack(spacing: LociSpacing.stack(.md)) {
                LociButton("← Types", style: .secondary) { onCancel() }
                Spacer(minLength: 0)
            }

            HStack(spacing: LociSpacing.stack(.md)) {
                LociIcon("plus.square", size: 22)
                    .foregroundStyle(LociColors.accent)
                Text("New type")
                    .font(LociTypography.font(.display))
                    .foregroundStyle(LociColors.ink)
            }
            .lociAppear(.soft)

            Text("Writes `.loci/types/<slug>.json` and creates `objects/<slug>/`. Property defs arrive in PR13.")
                .font(LociTypography.font(.body))
                .foregroundStyle(LociColors.inkSoft)
                .frame(maxWidth: 520, alignment: .leading)

            formField(title: "Name", text: $name, placeholder: "Books")
            formField(title: "Icon (SF Symbol)", text: $icon, placeholder: "book")
            formField(title: "Color", text: $color, placeholder: "#8B5A2B")
            formField(title: "Slug (optional)", text: $slugOverride, placeholder: "auto from name")

            if !previewSlug.isEmpty {
                Text("Will create .\(previewSlug)")
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.inkSoft)
            }

            HStack(spacing: LociSpacing.stack(.md)) {
                LociButton("Create type", style: .primary) {
                    Task { await save() }
                }
                .disabled(isBusy || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                LociButton("Cancel", style: .secondary) { onCancel() }
                    .disabled(isBusy)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.danger)
            }

            Spacer(minLength: 0)
        }
        .padding(LociSpacing.stack(.xl))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var previewSlug: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if let resolved = try? TypeSlug.resolve(
            explicit: slugOverride.isEmpty ? nil : slugOverride,
            fromName: trimmed
        ) {
            return resolved
        }
        return TypeSlug.fromName(trimmed)
    }

    @ViewBuilder
    private func formField(title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.xs)) {
            Text(title.uppercased())
                .font(LociTypography.font(.overline))
                .foregroundStyle(LociColors.inkSoft)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .font(LociTypography.font(.body))
        }
        .frame(maxWidth: 420, alignment: .leading)
    }

    private func save() async {
        isBusy = true
        defer { isBusy = false }
        do {
            if try await services.vault.fileExists(atRelativePath: VaultLayout.spaceJSON) == false {
                try await services.openVaultPipeline(rebuildIfNeeded: true)
            }
            let type = try await services.schema.createType(
                name: name,
                icon: icon,
                color: color,
                slug: slugOverride.isEmpty ? nil : slugOverride
            )
            errorMessage = nil
            services.focusedTypeID = type.id
            onSaved()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
