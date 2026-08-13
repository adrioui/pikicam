import SwiftUI

// MARK: - GridOverlayView

/// The rule-of-thirds (3x3) framing grid clipped to the visible compositional
/// aperture.
///
/// Positions come from `GridGeometry` (pure, unit-tested) and are inset to
/// the aperture rect passed by the camera layout. The overlay renders only
/// when enabled so UI tests can assert presence via `grid-overlay`.
struct GridOverlayView: View {
    let showsGrid: Bool

    /// The aperture rect in the parent's coordinate space. When nil the grid
    /// fills the containing view; when provided the grid is clipped to that
    /// rect so Square's masked bands never show grid lines.
    var apertureRect: CGRect? = nil

    var body: some View {
        if showsGrid {
            GeometryReader { proxy in
                let frame = apertureRect ?? CGRect(origin: .zero, size: proxy.size)
                let size = frame.size
                Path { path in
                    for x in GridGeometry.verticalLineXs(in: size) {
                        let sx = frame.minX + x
                        path.move(to: CGPoint(x: sx, y: frame.minY))
                        path.addLine(to: CGPoint(x: sx, y: frame.maxY))
                    }
                    for y in GridGeometry.horizontalLineYs(in: size) {
                        let sy = frame.minY + y
                        path.move(to: CGPoint(x: frame.minX, y: sy))
                        path.addLine(to: CGPoint(x: frame.maxX, y: sy))
                    }
                }
                .stroke(.white.opacity(0.6), lineWidth: 0.7)
            }
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier("grid-overlay")
        }
    }
}

#Preview("Grid overlay - photo") {
    GridOverlayView(showsGrid: true)
        .frame(width: 300, height: 400)
        .background(.black)
}

#Preview("Grid overlay - square aperture") {
    GeometryReader { proxy in
        let w = proxy.size.width
        let h = w * 4 / 3 // photo aperture
        let aperture = CGRect(x: 0, y: (proxy.size.height - h) / 2, width: w, height: h)
        // Square opening centered in the photo aperture
        let squareSize = min(aperture.width, aperture.height) * 0.9
        let square = CGRect(
            x: aperture.midX - squareSize / 2,
            y: aperture.midY - squareSize / 2,
            width: squareSize, height: squareSize
        )
        ZStack {
            Color.black
            Color.black.opacity(0.2).frame(height: h).position(x: w / 2, y: proxy.size.height / 2)
            GridOverlayView(showsGrid: true, apertureRect: square)
        }
    }
    .frame(width: 300, height: 600)
    .background(.black)
}
