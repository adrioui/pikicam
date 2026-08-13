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
    /// The DNG is developed with the zero-process recipe and rotated to match
    /// the device's physical orientation. The DNG is always the full-sensor
    /// original; no crop is applied. The result is in-memory only — it is for
    /// transient UI display and is never encoded to JPEG or persisted.
    ///
    /// - Parameter dngData: The DNG bytes from `AVCapturePhoto.rawFileDataRepresentation()`.
    /// - Parameter orientation: The physical orientation at capture time. Must
    ///   be passed in by the caller (which lives on the main actor) so this
    ///   background actor never reads `UIDevice`.
    /// - Returns: A transient display rendition.
    /// - Throws: `DevelopError` if processing fails.
    func render(
        dngData: Data,
        orientation: CaptureOrientation = .up
    ) async throws -> DNGDisplayRendition {
        let ciImage = try processor.develop(dngData: dngData)
        let oriented = Self.apply(orientation: orientation, to: ciImage)
        let cgImage = try renderBitmap(of: oriented)
        return DNGDisplayRendition(ciImage: oriented, cgImage: cgImage)
    }

    private static func apply(orientation: CaptureOrientation, to image: CIImage) -> CIImage {
        guard let transform = orientation.affineTransform, !transform.isIdentity else { return image }
        let filter = CIFilter(name: "CIAffineTransform")
        filter?.setValue(image, forKey: kCIInputImageKey)
        filter?.setValue(NSValue(cgAffineTransform: transform), forKey: kCIInputTransformKey)
        return filter?.outputImage ?? image
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
/// Captured on the main actor at the moment of capture and passed to the
/// background develop pipeline so the actor never reads `UIDevice`.
enum CaptureOrientation: Sendable {
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

    fileprivate var affineTransform: CGAffineTransform? {
        switch self {
        case .up: return nil
        case .down: return CGAffineTransform(rotationAngle: .pi)
        case .left: return CGAffineTransform(rotationAngle: .pi / 2)
        case .right: return CGAffineTransform(rotationAngle: -.pi / 2)
        }
    }
}
