import AVFoundation
import SwiftUI

struct PreviewLayerView: UIViewRepresentable {
    let source: PreviewSource

    final class Coordinator {
        var layer: AVCaptureVideoPreviewLayer?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let layer = source.layer ?? AVCaptureVideoPreviewLayer()
        layer.videoGravity = .resizeAspect
        view.layer.addSublayer(layer)
        context.coordinator.layer = layer
        DispatchQueue.main.async {
            layer.frame = view.bounds
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = context.coordinator.layer {
            layer.frame = uiView.bounds
        }
    }
}

struct Viewfinder: View {
    let source: PreviewSource
    let geometry: FrameGeometry
    let showGrid: Bool

    var body: some View {
        ZStack {
            PreviewLayerView(source: source)
                .accessibilityLabel("Viewfinder")
            GeometryReader { proxy in
                let overlay = CGRect(
                    x: geometry.normalizedRect.minX * proxy.size.width,
                    y: geometry.normalizedRect.minY * proxy.size.height,
                    width: geometry.normalizedRect.width * proxy.size.width,
                    height: geometry.normalizedRect.height * proxy.size.height
                )
                Path { path in
                    path.addRect(CGRect(origin: .zero, size: proxy.size))
                    path.addRect(overlay)
                }
                .fill(style: FillStyle(eoFill: true))
                .foregroundColor(PlateColor.photometricDeep)
                if showGrid {
                    grid(in: overlay)
                }
            }
            reticle
        }
        .clipped()
    }

    private func grid(in rect: CGRect) -> some View {
        Path { path in
            for step in 1...2 {
                let x = rect.minX + rect.width * CGFloat(step) / 3
                let y = rect.minY + rect.height * CGFloat(step) / 3
                path.move(to: CGPoint(x: x, y: rect.minY))
                path.addLine(to: CGPoint(x: x, y: rect.maxY))
                path.move(to: CGPoint(x: rect.minX, y: y))
                path.addLine(to: CGPoint(x: rect.maxY, y: y))
            }
        }
        .stroke(InkColor.gesso.opacity(0.25), lineWidth: UGrid.hairline)
    }

    private var reticle: some View {
        Rectangle()
            .strokeBorder(InkColor.gesso.opacity(0.8), lineWidth: UGrid.hairline)
            .frame(width: 96, height: 64)
            .overlay(
                HStack {
                    ForEach(0..<4, id: \.self) { _ in
                        Rectangle().fill(InkColor.gesso).frame(width: 1.5, height: 10)
                    }
                }
                .offset(y: -32)
            )
            .allowsHitTesting(false)
    }
}
