import SwiftUI
import LociCore
import LociDesignSystem

/// Add / edit / remove property definitions on a type (schema JSON).
struct PropertyDefsEditorView: View {
    var services: AppServices
    let typeID: ObjectTypeID

    @State private var type: ObjectType?
    @State private var draft = PropertyDraft()
    @State private var editingID: String?
    @State private var errorMessage: String?
    @State private var isBusy = false

    var body: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.lg)) {
            Text("PROPERTY DEFS")
                .font(LociTypography.font(.overline))
                .tracking(0.08)
                .foregroundStyle(LociColors.inkSoft)

            Text(type?.name ?? typeID.rawValue)
                .font(LociTypography.font(.headline))
                .foregroundStyle(LociColors.ink)

            Text("Stored in `.loci/types/\(typeID.rawValue).json`. Values live on objects (frontmatter).")
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.inkSoft)
                .frame(maxWidth: 520, alignment: .leading)

            if let props = type?.properties, !props.isEmpty {
                VStack(alignment: .leading, spacing: LociSpacing.stack(.sm)) {
                    ForEach(props, id: \.id) { def in
                        HStack(alignment: .firstTextBaseline, spacing: LociSpacing.stack(.md)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(def.name)
                                    .font(LociTypography.font(.body))
                                    .foregroundStyle(LociColors.ink)
                                Text(".\(def.id) · \(def.kind.rawValue)")
                                    .font(LociTypography.font(.caption))
                                    .foregroundStyle(LociColors.inkSoft)
                            }
                            Spacer(minLength: 0)
                            LociButton("Edit", style: .secondary) {
                                draft = PropertyDraft(def: def)
                                editingID = def.id
                            }
                            .disabled(isBusy)
                            LociButton("Remove", style: .secondary) {
                                Task { await remove(def.id) }
                            }
                            .disabled(isBusy)
                        }
                        .padding(.vertical, LociSpacing.stack(.xs))
                    }
                }
            } else {
                Text("No properties yet — add status, rating, etc.")
                    .font(LociTypography.font(.callout))
                    .foregroundStyle(LociColors.inkSoft)
            }

            LociDivider()

            Text(editingID == nil ? "Add property" : "Edit property")
                .font(LociTypography.font(.overline))
                .foregroundStyle(LociColors.inkSoft)

            formField(title: "Name", text: $draft.name, placeholder: "Status")
            formField(title: "Id (optional)", text: $draft.id, placeholder: "auto from name")

            HStack(spacing: LociSpacing.stack(.md)) {
                Text("Kind")
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.inkSoft)
                Picker("Kind", selection: $draft.kind) {
                    ForEach(PropertyKind.allCases, id: \.self) { kind in
                        Text(kind.rawValue).tag(kind)
                    }
                }
                #if os(macOS)
                .pickerStyle(.menu)
                #endif
            }

            if draft.kind == .select || draft.kind == .multiSelect {
                formField(
                    title: "Options (comma-separated)",
                    text: $draft.optionsText,
                    placeholder: "To Read, Reading, Done"
                )
            }

            if draft.kind == .objectSelect {
                Text("Object-select is a stub — values store id refs; link picker arrives later.")
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.inkSoft)
            }

            HStack(spacing: LociSpacing.stack(.md)) {
                LociButton(editingID == nil ? "Add property" : "Save property", style: .primary) {
                    Task { await upsert() }
                }
                .disabled(isBusy || draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if editingID != nil {
                    LociButton("Cancel", style: .secondary) {
                        draft = PropertyDraft()
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
        .accessibilityIdentifier("property-defs-editor")
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
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func upsert() async {
        isBusy = true
        defer { isBusy = false }
        do {
            let def = try draft.makeDef()
            type = try await services.schema.upsertProperty(typeID, def: def)
            draft = PropertyDraft()
            editingID = nil
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func remove(_ id: String) async {
        isBusy = true
        defer { isBusy = false }
        do {
            type = try await services.schema.removeProperty(typeID, propertyID: id)
            if editingID == id {
                draft = PropertyDraft()
                editingID = nil
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
