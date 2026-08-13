import SwiftUI
import LociCore
import LociDesignSystem

/// Studio destination for type conversion demos (PR28).
struct TypeConversionPanelView: View {
    var services: AppServices
    @State private var status =
        "Pick an open object from Types, or use Convert on an object inspector."
    @State private var lastResult = ""

    var body: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.lg)) {
            HStack(spacing: LociSpacing.stack(.md)) {
                LociIcon(Route.typeConvert.systemImage, size: 22)
                    .foregroundStyle(LociColors.accent)
                Text(Route.typeConvert.title)
                    .font(LociTypography.font(.headline))
                    .foregroundStyle(LociColors.ink)
            }

            Text(
                "Change an object’s type with property mapping. Vault moves `objects/<from>/` → `objects/<to>/`; ObjectID stays stable; index updates via ObjectServing."
            )
            .font(LociTypography.font(.callout))
            .foregroundStyle(LociColors.inkSoft)
            .fixedSize(horizontal: false, vertical: true)

            Text(status)
                .font(LociTypography.font(.callout))
                .foregroundStyle(LociColors.ink)

            if case .object(let id) = services.selectedRoute {
                TypeConversionSheetView(services: services, objectID: id)
            } else {
                LociButton("Open Types to pick an object", style: .secondary) {
                    Task { await services.open(route: .types) }
                }
            }

            if !lastResult.isEmpty {
                Text(lastResult)
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.inkSoft)
            }

            Spacer(minLength: 0)
        }
        .padding(LociSpacing.stack(.lg))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityIdentifier("type-convert-panel")
    }
}

struct TypeConversionInspectorView: View {
    var services: AppServices

    var body: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.md)) {
            Text("Convert")
                .font(LociTypography.font(.overline))
                .foregroundStyle(LociColors.inkSoft)
            Text("Property map · move")
                .font(LociTypography.font(.headline))
                .foregroundStyle(LociColors.ink)
            Text(
                "No feature→feature imports — ObjectServing + SchemaServing + IndexUpdating. Daily notes cannot convert."
            )
            .font(LociTypography.font(.callout))
            .foregroundStyle(LociColors.inkSoft)
            Spacer(minLength: 0)
        }
        .padding(LociSpacing.stack(.lg))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
