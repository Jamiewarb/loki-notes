import SwiftUI
import LociCore
import LociDesignSystem

/// Template CRUD for a type: body markdown + default property values + star default (PR14).
struct TemplateEditorView: View {
    var services: AppServices
    let typeID: ObjectTypeID

    @State private var type: ObjectType?
    @State private var templates: [ObjectTemplate] = []
    @State private var draft = TemplateDraft()
    @State private var editingID: String?
    @State private var errorMessage: String?
    @State private var isBusy = false

    private var store: TemplateStore { TemplateStore(schema: services.schema) }

    var body: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.lg)) {
            Text("TEMPLATES")
                .font(LociTypography.font(.overline))
                .tracking(0.08)
                .foregroundStyle(LociColors.inkSoft)

            Text(type?.name ?? typeID.rawValue)
                .font(LociTypography.font(.headline))
                .foregroundStyle(LociColors.ink)

            Text("Stored in `.loci/templates/<id>.md`. Starred default applies on create.")
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.inkSoft)
                .frame(maxWidth: 520, alignment: .leading)

            if templates.isEmpty {
                Text("No templates yet — add a default with headings and property presets.")
                    .font(LociTypography.font(.callout))
                    .foregroundStyle(LociColors.inkSoft)
            } else {
                VStack(alignment: .leading, spacing: LociSpacing.stack(.sm)) {
                    ForEach(templates, id: \.id) { template in
                        templateRow(template)
                    }
                }
            }

            LociDivider()

            Text(editingID == nil ? "Add template" : "Edit template")
                .font(LociTypography.font(.overline))
                .foregroundStyle(LociColors.inkSoft)

            formField(title: "Name", text: $draft.name, placeholder: "Default Book")
            if editingID == nil {
                formField(title: "Slug (optional)", text: $draft.slug, placeholder: "default")
            }

            VStack(alignment: .leading, spacing: LociSpacing.stack(.xs)) {
                Text("BODY MARKDOWN")
                    .font(LociTypography.font(.overline))
                    .foregroundStyle(LociColors.inkSoft)
                TextEditor(text: $draft.bodyMarkdown)
                    .font(LociTypography.font(.body))
                    .frame(minHeight: 120, maxHeight: 220)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(LociColors.inkSoft.opacity(0.25), lineWidth: 1)
                    )
            }
            .frame(maxWidth: 520, alignment: .leading)

            if let defs = type?.properties, !defs.isEmpty {
                Text("DEFAULT PROPERTY VALUES")
                    .font(LociTypography.font(.overline))
                    .foregroundStyle(LociColors.inkSoft)
                ForEach(defs, id: \.id) { def in
                    formField(
                        title: def.name,
                        text: Binding(
                            get: { draft.propertyDrafts[def.id] ?? "" },
                            set: { draft.propertyDrafts[def.id] = $0 }
                        ),
                        placeholder: def.kind == .select
                            ? (def.options.first ?? "value")
                            : def.kind.rawValue
                    )
                }
            }

            Toggle("Star as default for new objects", isOn: $draft.makeDefault)
                .font(LociTypography.font(.body))
                .foregroundStyle(LociColors.ink)

            HStack(spacing: LociSpacing.stack(.md)) {
                LociButton(editingID == nil ? "Add template" : "Save template", style: .primary) {
                    Task { await save() }
                }
                .disabled(isBusy || draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if editingID != nil {
                    LociButton("Cancel", style: .secondary) {
                        draft = TemplateDraft()
                        editingID = nil
                    }
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
        .accessibilityIdentifier("template-editor")
    }

    @ViewBuilder
    private func templateRow(_ template: ObjectTemplate) -> some View {
        let isDefault = type?.defaultTemplateID == template.id
        HStack(alignment: .firstTextBaseline, spacing: LociSpacing.stack(.md)) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: LociSpacing.stack(.sm)) {
                    Text(template.name)
                        .font(LociTypography.font(.body))
                        .foregroundStyle(LociColors.ink)
                    if isDefault {
                        Text("★ default")
                            .font(LociTypography.font(.caption))
                            .foregroundStyle(LociColors.accent)
                    }
                }
                Text(".\(template.id) · \(template.defaultProperties.count) props")
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.inkSoft)
            }
            Spacer(minLength: 0)
            if !isDefault {
                LociButton("Star", style: .secondary) {
                    Task { await star(template.id) }
                }
                .disabled(isBusy)
            }
            LociButton("Edit", style: .secondary) {
                draft = TemplateDraft(
                    template: template,
                    defs: type?.properties ?? [],
                    isDefault: isDefault
                )
                editingID = template.id
            }
            .disabled(isBusy)
            LociButton("Remove", style: .secondary) {
                Task { await remove(template.id) }
            }
            .disabled(isBusy)
        }
        .padding(.vertical, LociSpacing.stack(.xs))
        .accessibilityIdentifier("template-row-\(template.id)")
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

    private func save() async {
        isBusy = true
        defer { isBusy = false }
        do {
            let defs = type?.properties ?? []
            let props = draft.makeDefaultProperties(defs: defs)
            if let editingID {
                let template = ObjectTemplate(
                    id: editingID,
                    typeID: typeID,
                    name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines),
                    bodyMarkdown: draft.bodyMarkdown,
                    defaultProperties: props
                )
                _ = try await store.save(template)
                if draft.makeDefault {
                    type = try await store.setDefault(typeID: typeID, templateID: editingID)
                }
            } else {
                _ = try await store.create(
                    typeID: typeID,
                    name: draft.name,
                    bodyMarkdown: draft.bodyMarkdown,
                    defaultProperties: props,
                    slug: draft.slug.isEmpty ? nil : draft.slug,
                    makeDefault: draft.makeDefault
                )
            }
            draft = TemplateDraft()
            editingID = nil
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func star(_ id: String) async {
        isBusy = true
        defer { isBusy = false }
        do {
            type = try await store.setDefault(typeID: typeID, templateID: id)
            templates = try await store.list(typeID: typeID)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func remove(_ id: String) async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await store.delete(id)
            if editingID == id {
                draft = TemplateDraft()
                editingID = nil
            }
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
