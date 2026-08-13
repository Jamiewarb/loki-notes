import SwiftUI
import LociCore
import LociDesignSystem

/// Property-mapping UI for changing an object’s type (PR28).
struct TypeConversionSheetView: View {
    var services: AppServices
    let objectID: ObjectID

    @State private var types: [ObjectType] = []
    @State private var selectedTarget: ObjectTypeID?
    @State private var plan: TypeConversionPlan?
    @State private var mappings: [TypeConversionPropertyMap] = []
    @State private var status = "Pick a target type to preview property mapping."
    @State private var errorMessage: String?
    @State private var isBusy = false
    @State private var sourceTypeID: ObjectTypeID?

    private var store: TypeConversionStore {
        TypeConversionStore(objects: services.objects, schema: services.schema)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.lg)) {
            header
            typePicker
            mappingSection
            footer
        }
        .padding(LociSpacing.stack(.lg))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task { await loadTypes() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.sm)) {
            HStack(spacing: LociSpacing.stack(.md)) {
                LociIcon(Route.typeConvert.systemImage, size: 22)
                    .foregroundStyle(LociColors.accent)
                Text("Convert type")
                    .font(LociTypography.font(.headline))
                    .foregroundStyle(LociColors.ink)
            }
            Text(
                "Maps PropertyDefs → target, moves the file under `objects/<type>/`, keeps ObjectID stable, then reindexes."
            )
            .font(LociTypography.font(.callout))
            .foregroundStyle(LociColors.inkSoft)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var typePicker: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.sm)) {
            Text("Target type")
                .font(LociTypography.font(.overline))
                .foregroundStyle(LociColors.inkSoft)
            if types.isEmpty {
                Text("No convertible types yet.")
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.inkSoft)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: LociSpacing.stack(.sm)) {
                        ForEach(types, id: \.id) { type in
                            let selected = selectedTarget == type.id
                            LociButton(type.name, style: selected ? .primary : .secondary) {
                                Task { await selectTarget(type.id) }
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var mappingSection: some View {
        if let plan {
            VStack(alignment: .leading, spacing: LociSpacing.stack(.sm)) {
                Text("\(plan.sourceTypeID.rawValue) → \(plan.targetTypeID.rawValue)")
                    .font(LociTypography.font(.callout))
                    .foregroundStyle(LociColors.ink)
                Text("\(plan.sourceRelativePath) → \(plan.proposedRelativePath)")
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.inkSoft)

                ForEach(Array(mappings.enumerated()), id: \.offset) { index, map in
                    mappingRow(index: index, map: map, plan: plan)
                }

                let dropped = TypeConversionMapper.droppedPropertyIDs(in: mappings)
                let unmappedRequired = TypeConversionMapper.unmappedRequiredTargetIDs(
                    targetDefs: plan.targetDefs,
                    mappings: mappings
                )
                if !dropped.isEmpty {
                    Text("Dropped: \(dropped.joined(separator: ", "))")
                        .font(LociTypography.font(.caption))
                        .foregroundStyle(LociColors.inkSoft)
                }
                if !unmappedRequired.isEmpty {
                    Text("Required unmapped: \(unmappedRequired.joined(separator: ", "))")
                        .font(LociTypography.font(.caption))
                        .foregroundStyle(LociColors.danger)
                }
            }
        }
    }

    private func mappingRow(
        index: Int,
        map: TypeConversionPropertyMap,
        plan: TypeConversionPlan
    ) -> some View {
        let sourceName = plan.sourceDefs.first { $0.id == map.sourcePropertyID }?.name
            ?? map.sourcePropertyID
        return HStack(spacing: LociSpacing.stack(.sm)) {
            Text(sourceName)
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.ink)
                .frame(maxWidth: .infinity, alignment: .leading)

            Menu {
                Button("Drop") {
                    mappings[index].targetPropertyID = nil
                }
                ForEach(plan.targetDefs, id: \.id) { def in
                    Button(def.name) {
                        mappings[index].targetPropertyID = def.id
                    }
                }
            } label: {
                Text(targetLabel(for: map, plan: plan))
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.accent)
            }
        }
    }

    private func targetLabel(for map: TypeConversionPropertyMap, plan: TypeConversionPlan) -> String {
        guard let tid = map.targetPropertyID else { return "Drop ▾" }
        return (plan.targetDefs.first { $0.id == tid }?.name ?? tid) + " ▾"
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.sm)) {
            Text(status)
                .font(LociTypography.font(.callout))
                .foregroundStyle(LociColors.ink)
            if let errorMessage {
                Text(errorMessage)
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.danger)
            }
            HStack(spacing: LociSpacing.stack(.md)) {
                LociButton(isBusy ? "Converting…" : "Convert", style: .primary) {
                    Task { await applyConversion() }
                }
                .disabled(selectedTarget == nil || isBusy)
                Spacer(minLength: 0)
            }
        }
    }

    private func loadTypes() async {
        do {
            let objects = try await services.ensureObjectService()
            let opened = try await objects.open(id: objectID)
            sourceTypeID = opened.meta.typeID
            types = try await store.listConvertibleTypes(excluding: opened.meta.typeID)
            status = "Source: \(opened.meta.typeID.rawValue) · \(opened.meta.title)"
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func selectTarget(_ typeID: ObjectTypeID) async {
        selectedTarget = typeID
        isBusy = true
        defer { isBusy = false }
        do {
            guard let next = try await store.plan(id: objectID, toTypeID: typeID) else {
                errorMessage = "Object service unavailable"
                return
            }
            plan = next
            mappings = next.mappings
            status = "Ready — \(next.mappings.count) source properties mapped."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applyConversion() async {
        guard let selectedTarget else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            // Flush dirty editor before path move.
            if let session = services.activeEditorSession, session.objectID == objectID {
                await session.flushSave()
            }
            guard let result = try await store.convert(
                id: objectID,
                toTypeID: selectedTarget,
                propertyMap: mappings
            ) else {
                errorMessage = "Object service unavailable"
                return
            }
            status =
                "Converted → \(result.newRelativePath) · id \(result.objectID.uuidString.lowercased())"
            errorMessage = nil
            // Reload editor at same ObjectID (path/type changed).
            await services.open(objectID: result.objectID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
