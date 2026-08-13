import SwiftUI
import LociDesignSystem

/// Atmospheric paper gradient — shared shell + gallery chrome.
struct LociAtmosphereBackground: View {
    var body: some View {
        ZStack {
            LociColors.paper
            RadialGradient(
                colors: [LociColors.mist.opacity(0.85), .clear],
                center: .topLeading,
                startRadius: 20,
                endRadius: 520
            )
            RadialGradient(
                colors: [LociColors.meadow.opacity(0.7), .clear],
                center: .topTrailing,
                startRadius: 10,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
    }
}
