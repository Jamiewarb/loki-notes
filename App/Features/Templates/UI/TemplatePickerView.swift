import SwiftUI
import LociCore
import LociDesignSystem

/// Compact list to star / clear the default template for a type (PR14).
struct TemplatePickerView: View {
    var services: AppServices
    let typeID: ObjectTypeID

    @State private var type: ObjectType?
    @State private var templates: [ObjectTemplate] = []
    @State private var errorMessage: String?
    @State private var isBusy = false

    private var store: TemplateStore { TemplateStore(schema: services.schema) }

    var body: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.md)) {
            Text("DEFAULT TEMPLATE")
                .font(LociTypography.font(.overline))
                .tracking(0.08)
                .foregroundStyle(LociColors.inkSoft)

            if templates.isEmpty {
                Text("No templates — use the editor below to add one.")
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.inkSoft)
            } else {
                ForEach(templates, id: \.id) { template in
                    let isDefault = type?.defaultTemplateID == template.id
                    Button {
                        Task { await toggleDefault(template.id, currentlyDefault: isDefault) }
                    } label: {
                        HStack {
                            Text(isDefault ? "★" : "☆")
                                .foregroundStyle(isDefault ? LociColors.accent : LociColors.inkSoft)
                            Text(template.name)
                                .font(LociTypography.font(.body))
                                .foregroundStyle(LociColors.ink)
                            Spacer(minLength: 0)
                            Text(template.id)
                                .font(LociTypography.font(.caption))
                                .foregroundStyle(LociColors.inkSoft)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isBusy)
                    .accessibilityIdentifier("template-pick-\(template.id)")
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.danger)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .task { await reload() }
        .accessibilityIdentifier("template-picker")
    }

    private func reload() async {
        isBusy = true
        defer { isBusy = false }
        do {
            type = try await services.schema.loadType(typeID)
            templates = try await store.list(typeID: typeID)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleDefault(_ id: String, currentlyDefault: Bool) async {
        isBusy = true
        defer { isBusy = false }
        do {
            type = try await store.setDefault(
                typeID: typeID,
                templateID: currentlyDefault ? nil : id
            )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
