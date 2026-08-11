import SwiftUI

// MARK: - GridOverlayView

/// The rule-of-thirds (3×3) framing grid drawn over the live preview.
///
/// Line positions come from `GridGeometry` (pure, unit-tested): two vertical
/// lines at 1/3 and 2/3 of the width, two horizontal lines at 1/3 and 2/3 of
/// the height — a full 3×3 grid, matching the pro-camera convention (Moment
/// Pro Camera / rule of thirds). The overlay only exists in the view
/// hierarchy while enabled, so UI tests can assert its appearance/disappearance
/// via the `grid-overlay` identifier.
struct GridOverlayView: View {
    let showsGrid: Bool

    var body: some View {
        if showsGrid {
            GeometryReader { proxy in
                let size = proxy.size
                Path { path in
                    // Two vertical lines, two horizontal lines → full 3×3.
                    for x in GridGeometry.verticalLineXs(in: size) {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                    }
                    for y in GridGeometry.horizontalLineYs(in: size) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    }
                }
                .stroke(.white.opacity(0.6), lineWidth: 1)
            }
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier("grid-overlay")
        }
    }
}

#Preview("Grid overlay") {
    GridOverlayView(showsGrid: true)
        .frame(width: 300, height: 600)
        .background(.black)
}
