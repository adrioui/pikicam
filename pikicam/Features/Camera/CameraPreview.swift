import SwiftUI
import AVFoundation

/// A SwiftUI `UIViewRepresentable` wrapping `PreviewView` for the live
/// camera preview.
///
/// Bridges the UIKit-based `AVCaptureVideoPreviewLayer` into SwiftUI.
/// The preview always displays the full 4:3 sensor feed; framing (Photo vs
/// Square) is a SwiftUI compositional mask over the same feed. No crop is
/// applied to the capture pipeline and the DNG remains unchanged full-sensor.
struct CameraPreview: UIViewRepresentable {
    /// The capture session to display.
    let session: AVCaptureSession?

    /// The preview rotation angle in degrees.
    var rotationAngle: CGFloat = 90

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.session = session
        view.videoGravity = .resizeAspectFill
        view.setVideoRotationAngle(rotationAngle)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.session = session
        uiView.setVideoRotationAngle(rotationAngle)
    }

    /// Disconnect the session when the view is removed.
    static func dismantleUIView(_ uiView: PreviewView, coordinator: ()) {
        uiView.session = nil
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
