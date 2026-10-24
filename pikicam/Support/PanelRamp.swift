import SwiftUI

/// 17-step grey ramp, 0..255 in 16-code steps, full-screen on the exact
/// delivery path (no color space conversion beyond the display's). The
/// owner measures this with a colorimeter; docs/SKIN.md holds the claim.
struct PanelRamp: View {
    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                ForEach(0..<17, id: \.self) { step in
                    Rectangle()
                        .fill(Color(white: Double(step) / 16.0))
                        .frame(width: proxy.size.width / 17)
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityLabel("Grey ramp, 17 steps")
    }
}
