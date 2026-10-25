import SwiftUI

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
