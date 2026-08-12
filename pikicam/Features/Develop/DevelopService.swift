import Foundation
import CoreImage
import UIKit
import Metal

// MARK: - DevelopService

/// Develops a RAW DNG into a viewable JPEG with all computational
/// photography disabled (zero-process). Owns the Metal-backed `CIContext`
/// that turns `CIImage`s into encoded bytes.
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

    // MARK: - Development

    /// Develops a RAW DNG into a JPEG, cropped to the framing zoom and
    /// rotated to match the device's physical orientation.
    ///
    /// - Parameter dngData: The DNG bytes from `AVCapturePhoto.rawFileDataRepresentation()`.
    /// - Parameter cropFactor: The zoom factor the capture was framed at (≥ 1.0).
    ///   The DNG is full-sensor; cropping the print reproduces the framing.
    /// - Parameter orientation: The physical orientation at capture time. Must
    ///   be passed in by the caller (which lives on the main actor) so this
    ///   background actor never reads `UIDevice` directly.
    /// - Returns: JPEG data and the rotated, cropped `CIImage`.
    func develop(
        dngData: Data,
        mode: CaptureMode = .zero,
        cropFactor: CGFloat = 1.0,
        orientation: CaptureOrientation = .up
    ) async throws -> DevelopResult {
        let ciImage = try processor.develop(dngData: dngData, mode: mode)
        let framed = ciImage.cropped(to: ZoomMath.cropRect(in: ciImage.extent, for: cropFactor))
        let oriented = Self.apply(orientation: orientation, to: framed)
        let jpegData = try encodeJPEG(oriented)
        return DevelopResult(jpegData: jpegData, ciImage: oriented)
    }

    private static func apply(orientation: CaptureOrientation, to image: CIImage) -> CIImage {
        guard let transform = orientation.affineTransform, !transform.isIdentity else { return image }
        let filter = CIFilter(name: "CIAffineTransform")
        filter?.setValue(image, forKey: kCIInputImageKey)
        filter?.setValue(NSValue(cgAffineTransform: transform), forKey: kCIInputTransformKey)
        return filter?.outputImage ?? image
    }

    private func encodeJPEG(_ ciImage: CIImage) throws -> Data {
        guard let jpegData = ciContext.jpegRepresentation(of: ciImage, colorSpace: colorSpace, options: [:]) else {
            throw DevelopError.jpegEncodingFailed
        }
        return jpegData
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
