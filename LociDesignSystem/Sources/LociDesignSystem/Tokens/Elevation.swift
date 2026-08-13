/// Soft elevation shadows — keep subtle; avoid multi-layer glow aesthetics.
public enum LociElevation: Sendable {
    public static let restY: Double = 8
    public static let restBlur: Double = 24
    public static let restOpacity: Double = 0.08
    public static let raisedY: Double = 18
    public static let raisedBlur: Double = 40
    public static let raisedOpacity: Double = 0.10
}

#if canImport(SwiftUI)
import SwiftUI

public enum LociElevationLevel: Sendable {
    case rest
    case raised
}

private struct LociElevationModifier: ViewModifier {
    let level: LociElevationLevel

    func body(content: Content) -> some View {
        switch level {
        case .rest:
            content.shadow(
                color: LociColors.ink.opacity(LociElevation.restOpacity),
                radius: LociElevation.restBlur / 2,
                x: 0,
                y: LociElevation.restY / 2
            )
        case .raised:
            content.shadow(
                color: LociColors.ink.opacity(LociElevation.raisedOpacity),
                radius: LociElevation.raisedBlur / 2,
                x: 0,
                y: LociElevation.raisedY / 2
            )
        }
    }
}

extension View {
    public func lociElevation(_ level: LociElevationLevel = .rest) -> some View {
        modifier(LociElevationModifier(level: level))
    }
}
#endif
