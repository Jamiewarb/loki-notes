import SwiftUI
import LociCore
import LociDesignSystem

/// Inspector control: pin or unpin the open object (PR34).
struct PinToggleButton: View {
    var services: AppServices
    let objectID: ObjectID

    @State private var isPinned = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: LociSpacing.stack(.sm)) {
            Text("Pin")
                .font(LociTypography.font(.overline))
                .tracking(0.08)
                .foregroundStyle(LociColors.inkSoft)

            Text("Pins live in space.json and sync with the vault. The index is display-only.")
                .font(LociTypography.font(.caption))
                .foregroundStyle(LociColors.inkSoft)

            LociButton(
                isPinned ? "Unpin" : "Pin",
                style: .secondary,
                systemImage: isPinned ? "pin.slash" : "pin"
            ) {
                Task { await toggle() }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(LociTypography.font(.caption))
                    .foregroundStyle(LociColors.danger)
            }
        }
        .padding(LociSpacing.stack(.lg))
        .task { await reload() }
        .onChange(of: objectID) { _, _ in
            Task { await reload() }
        }
        .onChange(of: services.pinRefreshNonce) { _, _ in
            Task { await reload() }
        }
    }

    private func toggle() async {
        errorMessage = nil
        do {
            let store = PinStore(
                pins: services.schema,
                index: services.index,
                objects: services.objects
            )
            if isPinned {
                _ = try await store.unpin(objectID)
            } else {
                _ = try await store.pin(objectID)
            }
            services.bumpPinRefresh()
            await reload()
        } catch LociError.pinLimitReached(let cap) {
            errorMessage = "Pin limit is \(cap)."
        } catch {
            errorMessage = "Could not update pin."
        }
    }

    private func reload() async {
        do {
            isPinned = try await PinStore(
                pins: services.schema,
                index: services.index,
                objects: services.objects
            ).isPinned(objectID)
        } catch {
            isPinned = false
        }
    }
}
