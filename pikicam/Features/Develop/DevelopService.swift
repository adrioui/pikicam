import Foundation
import CoreImage
import Metal

// MARK: - DevelopService

/// An actor managing the RAW image development pipeline.
///
/// Uses a reused Metal-backed `CIContext` for performance and delegates actual
/// processing to a `RAWProcessor` implementation (Phase 1: CIRAWZeroProcessor).
///
/// The actor isolation ensures thread-safe access to the CIContext and processor state.
actor DevelopService {

    // MARK: - Properties

    /// The pipeline manager for selecting between processing backends.
    private let pipelineManager: PipelineManager

    /// Reused CIContext for rendering (Metal-backed, cache disabled).
    private let ciContext: CIContext

    // MARK: - Initialization

    init(pipeline: PipelineManager.Pipeline = .ciRaw) {
        self.pipelineManager = PipelineManager(preferredPipeline: pipeline)

        let displayP3 = CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB()

        // Metal-backed CIContext with no intermediates caching for minimal memory.
        if let device = MTLCreateSystemDefaultDevice() {
            self.ciContext = CIContext(
                mtlDevice: device,
                options: [
                    .cacheIntermediates: false,
                    .outputColorSpace: displayP3,
                ]
            )
        } else {
            self.ciContext = CIContext(
                options: [
                    .cacheIntermediates: false,
                    .outputColorSpace: displayP3,
                ]
            )
        }
    }

    // MARK: - Development

    /// Develops a RAW DNG file into a viewable JPEG image with zero processing.
    ///
    /// This is the core of pikicam's "zero-processing" philosophy. The DNG data
    /// is processed through the current RAW processor with all computational
    /// photography enhancements disabled.
    ///
    /// - Parameter dngData: The raw DNG file data from AVCapturePhoto.rawFileDataRepresentation().
    /// - Returns: A `DevelopResult` containing JPEG data and the CIImage.
    /// - Throws: `DevelopError` if processing fails.
    func develop(dngData: Data, mode: CaptureMode = .zero) async throws -> DevelopResult {
        let ciImage = try pipelineManager.develop(dngData: dngData, mode: mode)
        let jpegData = try encodeJPEG(ciImage)
        return DevelopResult(jpegData: jpegData, ciImage: ciImage)
    }

    // MARK: - JPEG Encoding

    /// Encodes a `CIImage` to JPEG using the reused `CIContext`.
    ///
    /// - Parameter ciImage: The image to encode.
    /// - Returns: JPEG-encoded data.
    /// - Throws: `DevelopError.jpegEncodingFailed` if encoding fails.
    private func encodeJPEG(_ ciImage: CIImage) throws -> Data {
        let displayP3: CGColorSpace
        if let space = CGColorSpace(name: CGColorSpace.displayP3) {
            displayP3 = space
        } else {
            throw DevelopError.colorSpaceUnavailable
        }

        guard let jpegData = ciContext.jpegRepresentation(
            of: ciImage,
            colorSpace: displayP3,
            options: [:]
        ) else {
            throw DevelopError.jpegEncodingFailed
        }
        return jpegData
    }
}
