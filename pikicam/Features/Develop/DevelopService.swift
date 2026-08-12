import Foundation
import UIKit
import CoreImage
import Metal

// MARK: - DevelopService

/// An actor managing the RAW image development pipeline.
///
/// Delegates development to a `RAWProcessor` (a `CIRAWZeroProcessor` by
/// default) and encodes the result as a JPEG with a reused Metal-backed
/// `CIContext`. The actor keeps `CIContext` access thread-safe.
actor DevelopService {

    // MARK: - Properties

    /// The processor that turns DNG bytes into a developed image.
    private let processor: RAWProcessor

    /// Reused CIContext for rendering (Metal-backed, cache disabled).
    private let ciContext: CIContext

    /// Color space used for the final JPEG.
    private let colorSpace: CGColorSpace

    // MARK: - Initialization

    init(processor: RAWProcessor? = nil) {
        self.processor = processor ?? CIRAWZeroProcessor()

        let colorSpace = CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB()
        self.colorSpace = colorSpace

        // Metal-backed CIContext with no intermediates caching for minimal memory.
        if let device = MTLCreateSystemDefaultDevice() {
            self.ciContext = CIContext(
                mtlDevice: device,
                options: [
                    .cacheIntermediates: false,
                    .outputColorSpace: colorSpace,
                ]
            )
        } else {
            self.ciContext = CIContext(
                options: [
                    .cacheIntermediates: false,
                    .outputColorSpace: colorSpace,
                ]
            )
        }
    }

    // MARK: - Development

    /// Develops a RAW DNG file into a viewable JPEG with zero processing.
    ///
    /// This is the core of pikicam's "zero-processing" philosophy. The DNG data
    /// is processed through the current RAW processor with all computational
    /// photography enhancements disabled.
    ///
    /// - Parameters:
    ///   - dngData: The raw DNG file data from AVCapturePhoto.rawFileDataRepresentation().
    ///   - mode: The development mode determining which enhancements are applied.
    ///   - cropFactor: The zoom factor the capture was framed at (≥ 1.0). The
    ///     DNG is full-sensor (pure-Bayer RAW only captures at 1×); cropping
    ///     the print to `1/cropFactor` of the frame reproduces the composition
    ///     the user saw.
    /// - Returns: A `DevelopResult` containing JPEG data and the CIImage.
    /// - Throws: `DevelopError` if processing fails.
    func develop(
        dngData: Data,
        mode: CaptureMode = .zero,
        cropFactor: CGFloat = 1.0
    ) async throws -> DevelopResult {
        let ciImage = try processor.develop(dngData: dngData, mode: mode)
        let framed = ciImage.cropped(to: ZoomMath.cropRect(
            in: ciImage.extent, for: cropFactor
        ))
        let oriented = Self.applyOrientationRotation(to: framed)
        let jpegData = try encodeJPEG(oriented)
        return DevelopResult(jpegData: jpegData, ciImage: oriented)
    }

    /// Applies device-orientation rotation so the saved image matches the
    /// physical orientation when captured (best-practice: like native Camera app).
    private static func applyOrientationRotation(to image: CIImage) -> CIImage {
        let orientation = UIDevice.current.orientation
        let rotationAngle: CGFloat = switch orientation {
        case .landscapeLeft: .pi / 2
        case .landscapeRight: -.pi / 2
        case .portraitUpsideDown: .pi
        default: 0
        }
        guard rotationAngle != 0 else { return image }
        // Best-practice: use CoreImage's native rotation filter rather than geometric transform.
        let filter = CIFilter(name: "CIAffineTransform")
        filter?.setValue(image, forKey: kCIInputImageKey)
        let transform = CGAffineTransform(rotationAngle: rotationAngle)
        filter?.setValue(NSValue(cgAffineTransform: transform), forKey: kCIInputTransformKey)
        return filter?.outputImage ?? image
    }

    // MARK: - JPEG Encoding

    /// Encodes a `CIImage` to JPEG using the reused `CIContext`.
    ///
    /// - Parameter ciImage: The image to encode.
    /// - Returns: JPEG-encoded data.
    /// - Throws: `DevelopError.jpegEncodingFailed` if encoding fails.
    private func encodeJPEG(_ ciImage: CIImage) throws -> Data {
        guard let jpegData = ciContext.jpegRepresentation(
            of: ciImage,
            colorSpace: colorSpace,
            options: [:]
        ) else {
            throw DevelopError.jpegEncodingFailed
        }
        return jpegData
    }
}
