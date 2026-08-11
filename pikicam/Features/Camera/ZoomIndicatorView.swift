import SwiftUI

/// The current zoom factor ("1.0x" …) shown above the shutter — a small
/// monochrome capsule, matching the pro-camera HUD language.
struct ZoomIndicatorView: View {
    let factor: CGFloat

    var body: some View {
        Text(ZoomMath.label(for: factor))
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.black.opacity(0.45), in: Capsule())
            .accessibilityIdentifier("zoom-indicator")
            .accessibilityValue(ZoomMath.label(for: factor))
    }
}

#Preview("Zoom indicator") {
    ZoomIndicatorView(factor: 2.5)
        .padding()
        .background(.black)
}
