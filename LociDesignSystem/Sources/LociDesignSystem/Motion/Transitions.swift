#if canImport(SwiftUI)
import SwiftUI

/// Intentional motion baselines for navigation and appearance (2–3 motions).
public enum LociMotion {
    public static let shellDuration: Double = 0.52
    public static let panelDuration: Double = 0.28
    public static let brandDuration: Double = 0.70

    public static var shell: Animation {
        .easeOut(duration: shellDuration)
    }

    public static var panel: Animation {
        .easeInOut(duration: panelDuration)
    }

    public static var brand: Animation {
        .timingCurve(0.22, 1.0, 0.36, 1.0, duration: brandDuration)
    }
}

public enum LociAppearStyle: Sendable {
    /// Soft rise used for empty states and first paint.
    case soft
    /// Brand mark rise with slight tracking settle.
    case brand
    /// Panel cross-fade for route changes.
    case panel
}

private struct LociAppearModifier: ViewModifier {
    let style: LociAppearStyle
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : offset)
            .onAppear {
                withAnimation(animation) { shown = true }
            }
    }

    private var offset: CGFloat {
        switch style {
        case .soft: return 8
        case .brand: return 12
        case .panel: return 6
        }
    }

    private var animation: Animation {
        switch style {
        case .soft: return LociMotion.shell
        case .brand: return LociMotion.brand
        case .panel: return LociMotion.panel
        }
    }
}

extension View {
    public func lociAppear(_ style: LociAppearStyle = .soft) -> some View {
        modifier(LociAppearModifier(style: style))
    }

    /// Asymmetric push used when swapping shell destinations (PR03).
    public func lociPanelTransition() -> some View {
        transition(
            .asymmetric(
                insertion: .opacity.combined(with: .move(edge: .trailing)).combined(with: .offset(y: 4)),
                removal: .opacity.combined(with: .offset(y: -4))
            )
        )
    }
}
#endif
