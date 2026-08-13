import SwiftUI
import LociCore
import LociDesignSystem

/// Sort / property-filter / group-by chrome for a type dashboard (PR41).
struct TypeDashboardControls: View {
    let properties: [PropertyDef]
    @Binding var sortKey: String
    @Binding var groupByKey: String
    @Binding var filterKey: String
    @Binding var filterText: String
    var onApplyFilter: () -> Void
    var onClearFilter: () -> Void

    private var groupable: [PropertyDef] {
        DashboardGrouping.groupableProperties(properties)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.sm)) {
            HStack(spacing: LociSpacing.stack(.md)) {
                Picker("Sort", selection: $sortKey) {
                    Text("Title A–Z").tag(QuerySort.titleAsc.rawValue)
                    Text("Title Z–A").tag(QuerySort.titleDesc.rawValue)
                    Text("Updated").tag(QuerySort.updatedDesc.rawValue)
                    Text("Created").tag(QuerySort.createdDesc.rawValue)
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("type-dashboard-sort")
                .frame(maxWidth: 180)

                Picker("Group by", selection: $groupByKey) {
                    Text("None").tag("none")
                    Text("Tag").tag(DashboardGrouping.tagGroupBy)
                    ForEach(groupable, id: \.id) { def in
                        Text(def.name).tag(def.id)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("type-dashboard-group")
                .frame(maxWidth: 180)
            }

            HStack(spacing: LociSpacing.stack(.sm)) {
                Picker("Property", selection: $filterKey) {
                    Text("Any property").tag("")
                    ForEach(properties, id: \.id) { def in
                        Text(def.name).tag(def.id)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("type-dashboard-filter-key")
                .frame(maxWidth: 180)

                TextField("Equals", text: $filterText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 180)
                    .onSubmit { onApplyFilter() }
                    .accessibilityIdentifier("type-dashboard-filter-text")

                LociButton("Apply filter", style: .secondary) { onApplyFilter() }
                if !filterKey.isEmpty || !filterText.isEmpty {
                    LociButton("Clear filter", style: .secondary) { onClearFilter() }
                }
            }
        }
    }
}
