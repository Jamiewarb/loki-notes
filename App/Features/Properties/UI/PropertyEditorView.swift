import SwiftUI
import LociCore
import LociDesignSystem

/// Inspector panel: edit property values for an open object.
/// Values persist in YAML frontmatter via `ObjectServing.save`; index updates async.
struct PropertyEditorView: View {
    var services: AppServices
    let objectID: ObjectID

    @State private var defs: [PropertyDef] = []
    @State private var draft = PropertyValueDraft()
    @State private var meta: LociObjectMeta?
    @State private var bodyMarkdown: String = ""
    @State private var typeName: String = ""
    @State private var errorMessage: String?
    @State private var isBusy = false
    @State private var saveGeneration: UInt64 = 0

    var body: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.md)) {
            Text("Properties")
                .font(LociTypography.font(.overline))
                .tracking(0.08)
                .foregroundStyle(LociColors.inkSoft)

            Text(meta?.title.isEmpty == false ? (meta?.title ?? "") : "Untitled")
                .font(LociTypography.font(.headline))
                .foregroundStyle(LociColors.ink)

            Text(typeName.isEmpty ? "Values live in YAML frontmatter." : "\(typeName) · YAML frontmatter")
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.inkSoft)

            LociDivider()

            if defs.isEmpty {
                Text("No property defs on this type yet. Add them from the type dashboard.")
                    .font(LociTypography.font(.callout))
                    .foregroundStyle(LociColors.inkSoft)
            } else {
                ForEach(defs, id: \.id) { def in
                    propertyRow(def)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.danger)
            }

            Spacer(minLength: 0)
        }
        .padding(LociSpacing.stack(.lg))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(LociColors.panel.opacity(0.55))
        .lociAppear(.panel)
        .task(id: objectID.uuidString) { await reload() }
        .accessibilityIdentifier("property-editor")
    }

    @ViewBuilder
    private func propertyRow(_ def: PropertyDef) -> some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.xs)) {
            Text(def.name.uppercased())
                .font(LociTypography.font(.overline))
                .foregroundStyle(LociColors.inkSoft)

            switch def.kind {
            case .checkbox:
                Toggle(
                    def.name,
                    isOn: Binding(
                        get: { (draft.fields[def.id] ?? "false").lowercased() == "true" },
                        set: { on in
                            draft.fields[def.id] = on ? "true" : "false"
                            scheduleSave()
                        }
                    )
                )
                .font(LociTypography.font(.body))
            case .select where !def.options.isEmpty:
                Picker(
                    def.name,
                    selection: Binding(
                        get: { draft.fields[def.id] ?? "" },
                        set: { value in
                            draft.fields[def.id] = value
                            scheduleSave()
                        }
                    )
                ) {
                    Text("—").tag("")
                    ForEach(def.options, id: \.self) { opt in
                        Text(opt).tag(opt)
                    }
                }
                #if os(macOS)
                .pickerStyle(.menu)
                #endif
            case .objectSelect:
                TextField(
                    "Object ids (stub, comma-separated)",
                    text: Binding(
                        get: { draft.fields[def.id] ?? "" },
                        set: { draft.fields[def.id] = $0; scheduleSave() }
                    )
                )
                .textFieldStyle(.roundedBorder)
                .font(LociTypography.font(.body))
            default:
                TextField(
                    placeholder(for: def),
                    text: Binding(
                        get: { draft.fields[def.id] ?? "" },
                        set: { draft.fields[def.id] = $0; scheduleSave() }
                    )
                )
                .textFieldStyle(.roundedBorder)
                .font(LociTypography.font(.body))
            }

            Text(def.kind.rawValue)
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.inkSoft)
        }
        .padding(.bottom, LociSpacing.stack(.sm))
    }

    private func placeholder(for def: PropertyDef) -> String {
        switch def.kind {
        case .number: return "0"
        case .date: return "YYYY-MM-DD"
        case .url: return "https://"
        case .multiSelect: return "a, b"
        default: return def.name
        }
    }

    private func reload() async {
        isBusy = true
        defer { isBusy = false }
        do {
            let objects = try await services.ensureObjectService()
            let opened = try await objects.open(id: objectID)
            meta = opened.meta
            bodyMarkdown = opened.bodyMarkdown
            let type = try await services.schema.loadType(opened.meta.typeID)
            typeName = type.name
            defs = type.properties
            draft = PropertyValueDraft(defs: type.properties, values: opened.meta.properties)
            // Sync live editor session properties if present.
            if let session = services.activeEditorSession, session.objectID == objectID {
                draft = PropertyValueDraft(defs: type.properties, values: session.currentProperties)
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func scheduleSave() {
        saveGeneration &+= 1
        let generation = saveGeneration
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard generation == saveGeneration else { return }
            await flushSave()
        }
    }

    private func flushSave() async {
        do {
            var nextValues = meta?.properties ?? [:]
            draft.apply(to: &nextValues, defs: defs)

            if let session = services.activeEditorSession, session.objectID == objectID {
                session.applyProperties(nextValues)
                await session.flushSave()
                meta?.properties = nextValues
            } else {
                let objects = try await services.ensureObjectService()
                let opened = try await objects.open(id: objectID)
                var next = opened.meta
                next.properties = nextValues
                try await objects.save(meta: next, bodyMarkdown: opened.bodyMarkdown)
                meta = next
                bodyMarkdown = opened.bodyMarkdown
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
