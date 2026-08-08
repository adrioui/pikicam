#if canImport(UIKit)
import AVFoundation
import UIKit

/// A UIView subclass whose `layerClass` is `AVCaptureVideoPreviewLayer`.
///
/// This provides the live camera preview by embedding the AVCaptureSession's
/// video output directly into the view hierarchy. Using the system's preview
/// layer gives us best performance and battery life, plus automatic HDR
/// tone-mapping and support for iOS 26 Deferred Start.
///
/// ## Usage
/// Assign the `CaptureService.session` to `previewLayer.session` after
/// the session is configured.
final class PreviewView: UIView {
    // MARK: - Preview Layer

    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            fatalError("Expected AVCaptureVideoPreviewLayer")
        }
        return layer
    }

    // MARK: - Configuration

    /// The capture session to preview.
    var session: AVCaptureSession? {
        get { previewLayer.session }
        set { previewLayer.session = newValue }
    }

    /// The video gravity for the preview.
    var videoGravity: AVLayerVideoGravity {
        get { previewLayer.videoGravity }
        set { previewLayer.videoGravity = newValue }
    }

    /// Configures the preview layer's connection for rotation changes.
    func setVideoRotationAngle(_ angle: CGFloat) {
        guard let connection = previewLayer.connection else { return }
        if connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
        }
    }

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        previewLayer.videoGravity = .resizeAspectFill
    }
}
#endif
