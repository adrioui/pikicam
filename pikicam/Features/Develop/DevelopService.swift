import Foundation
import CoreImage
import UIKit
import Metal

// MARK: - DevelopService

/// Renders a RAW DNG into a transient in-memory display rendition with all
/// computational photography disabled (zero-process). Owns the Metal-backed
/// `CIContext` that turns `CIImage`s into display-ready bitmaps.
///
/// DevelopService is used only for transient full-screen rendering of the
/// original DNG. Nothing here is persisted: no JPEG is encoded and no file
/// is written.
actor DevelopService {

    private let processor: RAWProcessor
    private let ciContext: CIContext
    private let colorSpace: CGColorSpace

    init(processor: RAWProcessor? = nil) {
        self.processor = processor ?? CIRAWZeroProcessor()
        self.colorSpace = CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB()

        if let device = MTLCreateSystemDefaultDevice() {
            self.ciContext = CIContext(
                mtlDevice: device,
                options: [.cacheIntermediates: false, .outputColorSpace: self.colorSpace]
            )
        } else {
            self.ciContext = CIContext(options: [.cacheIntermediates: false, .outputColorSpace: self.colorSpace])
        }
    }

    // MARK: - Rendering

    /// Renders a RAW DNG into a transient display rendition.
    ///
    /// The DNG is developed with the zero-process recipe and cropped to the
    /// selected aspect/zoom framing. The DNG asset remains the unchanged
    /// full-sensor original; the crop is non-destructive and applied only at
    /// develop/view time. The result is in-memory only — it is for transient
    /// UI display and is never encoded to JPEG or persisted.
    ///
    /// Orientation is **not** applied here: `CIRAWFilter` already bakes the
    /// DNG's EXIF orientation into its output (verified empirically — a
    /// 4032×3024 sensor buffer tagged Orientation 6 develops to a 3024×4032
    /// upright extent), so the developed image arrives upright in the space
    /// the user framed in. Rotating again would double-rotate every capture
    /// whose DNG carries a non-up orientation tag.
    ///
    /// - Parameter dngData: The DNG bytes from `AVCapturePhoto.rawFileDataRepresentation()`.
    /// - Parameter aspectRatio: The aspect-ratio crop selected at capture.
    /// - Parameter zoomFactor: The framing zoom selected at capture.
    /// - Returns: A transient display rendition.
    /// - Throws: `DevelopError` if processing fails.
    func render(
        dngData: Data,
        aspectRatio: AspectRatio = .ratio4x3,
        zoomFactor: CGFloat = 1.0
    ) async throws -> DNGDisplayRendition {
        let ciImage = try processor.develop(dngData: dngData)
        // The crop runs on the developed (already upright) extent — the same
        // space the preview aperture occupies — so what the user framed
        // inside the mask is exactly what this crop keeps.
        let framed = ciImage.cropped(
            to: PrintCrop.rect(in: ciImage.extent, zoomFactor: zoomFactor, aspect: aspectRatio)
        )
        let cgImage = try renderBitmap(of: framed)
        return DNGDisplayRendition(ciImage: framed, cgImage: cgImage)
    }

    /// Renders the image to a display bitmap in the pipeline's color space.
    ///
    /// All `CIContext` use happens here, inside the actor, off-main.
    private func renderBitmap(of ciImage: CIImage) throws -> CGImage {
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            throw DevelopError.renderingFailed
        }
        return cgImage
    }
}

// MARK: - CaptureOrientation

/// The physical orientation the device was held in when the shutter fired.
/// Captured on the main actor at the moment of capture and persisted as
/// capture provenance. The develop pipeline does **not** consume it:
/// `CIRAWFilter` bakes the DNG's EXIF orientation into its output, so the
/// developed image is already upright (see `DevelopService.render`).
nonisolated public enum CaptureOrientation: Sendable, Codable {
    case up
    case down
    case left
    case right

    init(orientation: UIDeviceOrientation) {
        switch orientation {
        case .landscapeLeft: self = .left
        case .landscapeRight: self = .right
        case .portraitUpsideDown: self = .down
        default: self = .up
        }
    }
}
