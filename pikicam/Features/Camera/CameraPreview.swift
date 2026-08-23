import SwiftUI
import AVFoundation

/// A SwiftUI `UIViewRepresentable` wrapping `PreviewView` for the live
/// camera preview.
///
/// Bridges the UIKit-based `AVCaptureVideoPreviewLayer` into SwiftUI.
/// The preview always displays the full sensor feed; aspect-ratio framing is
/// a SwiftUI compositional mask over the same feed. No crop is applied to the
/// capture pipeline and the DNG remains unchanged full-sensor.
struct CameraPreview: UIViewRepresentable {
    /// The capture session to display.
    let session: AVCaptureSession?

    /// The preview rotation angle in degrees.
    var rotationAngle: CGFloat = 90

    /// Called when the user taps the preview. The point is already converted
    /// to AVFoundation's normalized capture-device coordinates, ready for
    /// `setFocusAndExposure(at:)`.
    var onTap: ((CGPoint) -> Void)?

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.session = session
        view.videoGravity = .resizeAspectFill
        view.setVideoRotationAngle(rotationAngle)
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tap)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.session = session
        uiView.setVideoRotationAngle(rotationAngle)
        context.coordinator.onTap = onTap
    }

    static func dismantleUIView(_ uiView: PreviewView, coordinator: Coordinator) {
        uiView.session = nil
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap)
    }

    final class Coordinator: NSObject {
        var onTap: ((CGPoint) -> Void)?

        init(onTap: ((CGPoint) -> Void)?) {
            self.onTap = onTap
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let view = recognizer.view as? PreviewView else { return }
            let location = recognizer.location(in: view)
            onTap?(view.devicePoint(for: location))
        }
    }
}

extension PreviewView {
    /// Converts a point in the view's coordinate space to the device's point of interest.
    func devicePoint(for viewPoint: CGPoint) -> CGPoint {
        previewLayer.captureDevicePointConverted(fromLayerPoint: viewPoint)
    }

    /// Converts a capture device point of interest to the view's point.
    func layerPoint(for devicePoint: CGPoint) -> CGPoint {
        previewLayer.layerPointConverted(fromCaptureDevicePoint: devicePoint)
    }
}
