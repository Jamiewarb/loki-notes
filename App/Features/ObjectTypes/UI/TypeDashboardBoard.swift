import SwiftUI
import LociCore
import LociDesignSystem

/// Board columns from `KanbanMove.columns` (PR42). Cards open objects;
/// VoiceOver “Move to …” is required — drag is Apple-only and optional.
struct TypeDashboardBoard: View {
    let type: ObjectType?
    let columns: [DashboardSection]
    let groupBy: String?
    let isBusy: Bool
    var onOpen: (ObjectID) async -> Void
    var onMove: (ObjectID, String) async -> Void

    private var destinationKeys: [String] {
        columns.map(\.key)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.sm)) {
            if KanbanMove.isUngrouped(groupBy) {
                Text(KanbanMove.ungroupedCaption)
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.inkSoft)
                    .accessibilityIdentifier("kanban-ungrouped-caption")
            }
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(alignment: .top, spacing: LociSpacing.stack(.md)) {
                    ForEach(columns, id: \.key) { column in
                        columnView(column)
                    }
                }
            }
        }
        .accessibilityIdentifier("kanban-board")
    }

    private func columnView(_ column: DashboardSection) -> some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.sm)) {
            Text(column.key.uppercased())
                .font(LociTypography.font(.overline))
                .tracking(0.08)
                .foregroundStyle(LociColors.inkSoft)
            if column.objects.isEmpty {
                Text("No cards")
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.inkSoft)
            } else {
                ForEach(column.objects, id: \.id.uuidString) { item in
                    card(item, columnKey: column.key)
                }
            }
        }
        .frame(minWidth: 220, maxWidth: 280, alignment: .topLeading)
        .padding(LociSpacing.stack(.sm))
        .accessibilityIdentifier("kanban-column")
        .accessibilityLabel(column.key)
        .modifier(KanbanColumnDropModifier(
            destinationKey: column.key,
            isBusy: isBusy,
            onMove: onMove
        ))
    }

    private func card(_ item: LociObjectMeta, columnKey: String) -> some View {
        let title = item.title.isEmpty ? "Untitled" : item.title
        let moveTargets = destinationKeys.filter { $0 != columnKey }
        return VStack(alignment: .leading, spacing: LociSpacing.stack(.xs)) {
            Button {
                Task { await onOpen(item.id) }
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(LociTypography.font(.headline))
                        .foregroundStyle(LociColors.ink)
                    Text(propertyPreview(item))
                        .font(LociTypography.font(.caption))
                        .foregroundStyle(LociColors.inkSoft)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, LociSpacing.stack(.xs))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("kanban-card")
            .accessibilityLabel(title)

            if !moveTargets.isEmpty {
                Menu("Move to …") {
                    ForEach(moveTargets, id: \.self) { key in
                        Button("Move to \(key)") {
                            Task { await onMove(item.id, key) }
                        }
                        .accessibilityLabel("Move \(title) to \(key)")
                    }
                }
                .disabled(isBusy)
                .accessibilityIdentifier("kanban-move-\(item.id.uuidString.lowercased())")
                .accessibilityLabel("Move \(title)")
            }
        }
        .padding(LociSpacing.stack(.sm))
        .modifier(KanbanCardDragModifier(objectID: item.id))
    }

    private func propertyPreview(_ item: LociObjectMeta) -> String {
        guard let type, !type.properties.isEmpty else { return item.relativePath }
        let bits = type.properties.prefix(3).compactMap { def -> String? in
            guard let value = item.properties[def.id] else { return nil }
            let shown = PropertyValueFormatting.displayString(value)
            guard !shown.isEmpty else { return nil }
            return "\(def.name): \(shown)"
        }
        if bits.isEmpty { return item.relativePath }
        return bits.joined(separator: " · ")
    }
}
