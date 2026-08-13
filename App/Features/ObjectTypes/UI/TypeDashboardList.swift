import SwiftUI
import LociCore
import LociDesignSystem

/// Grouped object rows for a type dashboard (PR41). Board view: `TypeDashboardBoard`.
struct TypeDashboardList: View {
    let type: ObjectType?
    let typeID: ObjectTypeID
    let sections: [DashboardSection]
    let activeCollection: ObjectCollection?
    let selectedCollectionID: String?
    let isBusy: Bool
    var onOpen: (ObjectID) async -> Void
    var onRemoveFromCollection: (String, ObjectID) async -> Void

    private var isEmpty: Bool {
        sections.allSatisfy(\.objects.isEmpty)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.sm)) {
            if isEmpty {
                LociEmptyState(
                    title: activeCollection == nil
                        ? "No \(type?.name ?? "objects") yet"
                        : "Empty collection",
                    message: activeCollection == nil
                        ? "Create one to write markdown under objects/\(typeID.rawValue)/."
                        : "Add objects from the collection controls above.",
                    systemImage: type?.icon ?? "doc"
                )
            } else {
                ForEach(sections, id: \.key) { section in
                    header(section.key)
                    ForEach(section.objects, id: \.id.uuidString) { item in
                        objectRow(item)
                    }
                }
                .lociAppear(.soft)
            }

            header("Recently opened")
            Text("Stub — session recents land with navigation polish. Use All for now.")
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.inkSoft)
        }
    }

    private func header(_ title: String) -> some View {
        Text(title.uppercased())
            .font(LociTypography.font(.overline))
            .tracking(0.08)
            .foregroundStyle(LociColors.inkSoft)
            .padding(.top, LociSpacing.stack(.sm))
    }

    @ViewBuilder
    private func objectRow(_ item: LociObjectMeta) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: LociSpacing.stack(.md)) {
            Button {
                Task { await onOpen(item.id) }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: LociSpacing.stack(.md)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title.isEmpty ? "Untitled" : item.title)
                            .font(LociTypography.font(.headline))
                            .foregroundStyle(LociColors.ink)
                        Text(propertyPreview(item))
                            .font(LociTypography.font(.caption))
                            .foregroundStyle(LociColors.inkSoft)
                        Text(item.relativePath)
                            .font(LociTypography.font(.caption))
                            .foregroundStyle(LociColors.inkSoft)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, LociSpacing.stack(.sm))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("type-object-\(item.id.uuidString.lowercased())")

            if let selectedCollectionID {
                LociButton("Remove", style: .secondary) {
                    Task { await onRemoveFromCollection(selectedCollectionID, item.id) }
                }
                .disabled(isBusy)
            }
        }
    }

    private func propertyPreview(_ item: LociObjectMeta) -> String {
        guard let type, !type.properties.isEmpty else { return "" }
        let bits = type.properties.prefix(3).compactMap { def -> String? in
            guard let value = item.properties[def.id] else { return nil }
            let shown = PropertyValueFormatting.displayString(value)
            guard !shown.isEmpty else { return nil }
            return "\(def.name): \(shown)"
        }
        return bits.joined(separator: " · ")
    }
}
