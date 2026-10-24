import SwiftUI

struct GessoShutterActuator: View {
    let state: ShutterState
    let action: () -> Void

    private let ringDiameter: CGFloat = 72
    private let discDiameter: CGFloat = 56
    private let voidGap: CGFloat = 4

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .strokeBorder(RuleColor.border, lineWidth: 2)
                    .frame(width: ringDiameter, height: ringDiameter)
                Circle()
                    .fill(discFill)
                    .frame(width: discDiameter, height: discDiameter)
                if case .countdown(let remaining) = state {
                    Text("\(remaining)")
                        .font(PikicamFont.mono(.headline))
                        .foregroundStyle(Palette.photometricBlack)
                }
            }
            .frame(width: ringDiameter + voidGap * 2, height: ringDiameter + voidGap * 2)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier(AccessibilityID.Camera.shutter)
        .accessibilityLabel("Shutter")
        .accessibilityValue(stateLabel)
        .accessibilityAddTraits(.isButton)
    }

    private var discFill: Color {
        switch state {
        case .ready, .pressed, .capturing: return Palette.gesso
        case .countdown: return Palette.gesso.opacity(0.85)
        case .saving: return Palette.calico
        case .failed: return SurfaceColor.elevated
        }
    }

    private var stateLabel: String {
        switch state {
        case .ready: return "Ready"
        case .pressed: return "Pressed"
        case .countdown: return "Counting down"
        case .capturing: return "Capturing"
        case .saving: return "Saving"
        case .failed: return "Failed"
        }
    }
}
