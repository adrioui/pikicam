import SwiftUI
import AVFoundation

#if canImport(UIKit)
/// A SwiftUI `UIViewRepresentable` wrapping `PreviewView` for the live
/// camera preview.
///
/// Bridges the UIKit-based `AVCaptureVideoPreviewLayer` into the SwiftUI
/// view hierarchy. This approach is preferred over rendering preview frames
/// via `CIImage` because the system preview layer provides:
/// - Best performance and battery life
/// - Automatic HDR tone-mapping
/// - Deferred Start support (iOS 26+)
/// - No CPU/GPU overhead for preview rendering
struct CameraPreview: UIViewRepresentable {
    /// The capture session to display in the preview.
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

    /// Disconnect the session when the view is removed to avoid
    /// rendering artifacts.
    static func dismantleUIView(_ uiView: PreviewView, coordinator: ()) {
        uiView.session = nil
    }
}
#else
/// Placeholder preview used when the package is type-checked on non-iOS platforms.
struct CameraPreview: View {
    /// The capture session to display in the preview.
    let session: AVCaptureSession?

    var body: some View {
        Color.black
    }
}
#endif
