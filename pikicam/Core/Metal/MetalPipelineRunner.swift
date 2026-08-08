import Foundation
import Metal
import CoreImage

// MARK: - MetalPipelineRunner

/// Orchestrates the Metal compute pipeline for Phase 2 custom debayering.
///
/// This class manages the Metal device, command queue, and texture cache
/// needed to run the Phase 2 debayer pipeline (grand-plan.md §3.3):
///
/// ```
/// raw Bayer → linearize → black subtract → white balance
///          → demosaic (Malvar/bilinear) → color matrix → gamma
/// ```
///
/// Each step is a separate compute kernel in `debayer.metal`. The runner
/// chains them into a single `MTLCommandBuffer` for efficient GPU execution.
///
/// ## Thread Safety
/// This class is `@unchecked Sendable` because `MTLDevice` and
/// `MTLCommandQueue` are thread-safe per Apple's documentation, but are
/// not formally annotated as `Sendable`.
nonisolated final class MetalPipelineRunner: @unchecked Sendable {

    // MARK: - Properties

    /// The Metal device used for compute.
    private let device: MTLDevice

    /// The command queue for submitting work.
    private let commandQueue: MTLCommandQueue

    /// The pipeline state for each kernel.
    private var pipelineStates: [String: MTLComputePipelineState] = [:]

    // MARK: - Kernel Names

    private enum Kernel: String, CaseIterable {
        case linearize = "linearizeKernel"
        case blackSubtract = "blackSubtractKernel"
        case whiteBalance = "whiteBalanceKernel"
        case malvarDebayer = "malvarDebayerKernel"
        case bilinearDebayer = "bilinearDebayerKernel"
        case colorMatrix = "colorMatrixKernel"
    }

    // MARK: - Initialization

    init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw MetalPipelineError.deviceUnavailable
        }
        self.device = device
        guard let commandQueue = device.makeCommandQueue() else {
            throw MetalPipelineError.commandQueueCreationFailed
        }
        self.commandQueue = commandQueue

        // Load the metal library from the bundle
        let library = try device.makeDefaultLibrary(bundle: Bundle.main)
        for kernel in Kernel.allCases {
            guard let function = library.makeFunction(name: kernel.rawValue) else {
                throw MetalPipelineError.kernelNotFound(kernel.rawValue)
            }
            pipelineStates[kernel.rawValue] = try device.makeComputePipelineState(function: function)
        }
    }

    // MARK: - Pipeline Execution

    /// Runs the full debayer pipeline on raw Bayer data.
    ///
    /// - Parameters:
    ///   - bayerTexture: The raw Bayer texture (single-channel, from CVMetalTexture).
    ///   - metadata: DNG metadata for uniform computation.
    ///   - algorithm: Which demosaic algorithm to use (.malvar or .bilinear).
    /// - Returns: A `CIImage` containing the developed output.
    /// - Throws: `MetalPipelineError` if any step fails.
    func runPipeline(
        bayerTexture: MTLTexture,
        metadata: DNGMetadata,
        algorithm: DemosaicAlgorithm = .malvar
    ) throws -> CIImage {
        let width = metadata.width
        let height = metadata.height

        // Create intermediate textures
        let blackSubtracted = try makeSingleChannelTexture(width: width, height: height)
        let whiteBalanced = try makeSingleChannelTexture(width: width, height: height)
        let demosaiced = try makeRGBATexture(width: width, height: height)
        let output = try makeRGBATexture(width: width, height: height)

        // Build uniforms buffer
        let uniforms = buildUniforms(from: metadata)

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw MetalPipelineError.commandBufferCreationFailed
        }

        // Step 1: Linearize is currently identity; most iPhone DNGs omit LinearizationTable.
        if metadata.linearizationTable != nil {
            // TODO: Create linearization LUT texture and run linearizeKernel.
        }

        // Step 2: Black Subtract
        if let pipeline = pipelineStates[Kernel.blackSubtract.rawValue] {
            encoder.setComputePipelineState(pipeline)
            encoder.setTexture(bayerTexture, index: 0)
            encoder.setTexture(blackSubtracted, index: 1)
            uniforms.withUnsafeBytes { ptr in
                encoder.setBytes(ptr.baseAddress!, length: ptr.count, index: 0)
            }
            dispatchThreads(encoder, pipeline: pipeline, width: width, height: height)
        }

        // Step 3: White Balance
        if let pipeline = pipelineStates[Kernel.whiteBalance.rawValue] {
            encoder.setComputePipelineState(pipeline)
            encoder.setTexture(blackSubtracted, index: 0)
            encoder.setTexture(whiteBalanced, index: 1)
            uniforms.withUnsafeBytes { ptr in
                encoder.setBytes(ptr.baseAddress!, length: ptr.count, index: 0)
            }
            dispatchThreads(encoder, pipeline: pipeline, width: width, height: height)
        }

        // Step 4: Demosaic
        let debayerKernel = (algorithm == .bilinear) ? Kernel.bilinearDebayer : Kernel.malvarDebayer
        if let pipeline = pipelineStates[debayerKernel.rawValue] {
            encoder.setComputePipelineState(pipeline)
            encoder.setTexture(whiteBalanced, index: 0)
            encoder.setTexture(demosaiced, index: 1)
            uniforms.withUnsafeBytes { ptr in
                encoder.setBytes(ptr.baseAddress!, length: ptr.count, index: 0)
            }
            dispatchThreads(encoder, pipeline: pipeline, width: width, height: height)
        }

        // Step 5: Color Matrix + Gamma
        if let pipeline = pipelineStates[Kernel.colorMatrix.rawValue] {
            encoder.setComputePipelineState(pipeline)
            encoder.setTexture(demosaiced, index: 0)
            encoder.setTexture(output, index: 1)
            uniforms.withUnsafeBytes { ptr in
                encoder.setBytes(ptr.baseAddress!, length: ptr.count, index: 0)
            }
            dispatchThreads(encoder, pipeline: pipeline, width: width, height: height)
        }

        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        // Convert the output MTLTexture to CIImage
        guard let image = CIImage(mtlTexture: output) else {
            throw MetalPipelineError.imageCreationFailed
        }
        return image
    }

    // MARK: - Texture Creation

    /// Creates a single-channel (R16Float) texture for intermediate Bayer data.
    private func makeSingleChannelTexture(width: Int, height: Int) throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = .type2D
        descriptor.pixelFormat = .r16Float
        descriptor.width = width
        descriptor.height = height
        descriptor.usage = [.shaderRead, .shaderWrite]
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw MetalPipelineError.textureCreationFailed
        }
        return texture
    }

    /// Creates an RGBA (RGBA16Float) texture for demosaiced/output data.
    private func makeRGBATexture(width: Int, height: Int) throws -> MTLTexture {
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = .type2D
        descriptor.pixelFormat = .rgba16Float
        descriptor.width = width
        descriptor.height = height
        descriptor.usage = [.shaderRead, .shaderWrite]
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw MetalPipelineError.textureCreationFailed
        }
        return texture
    }

    // MARK: - Uniforms

    /// Builds the `DemosaicUniforms` buffer data from DNG metadata.
    ///
    /// The byte layout must match `DemosaicUniforms` in `debayer.metal` exactly.
    /// Metal aligns `float3x3` members to 16-byte boundaries with a 48-byte
    /// stride, so `colorMatrix` and `xyzToDisplayP3` are written at offsets 48
    /// and 96 respectively, with padding inserted so each matrix starts on a
    /// 16-byte boundary. Writing the matrices contiguously (no padding) would
    /// shift every `float3x3` 4 bytes late and 12 bytes short, corrupting the
    /// color transforms on the GPU.
    private func buildUniforms(from metadata: DNGMetadata) -> Data {
        // Layout (byte offsets):
        //   0   uint cfaPattern
        //   4   uint width
        //   8   uint height
        //  12   float blackLevel[4]            (16 bytes)
        //  28   float whiteLevel
        //  32   float wbGain[3]                (12 bytes) -> ends at 44
        //  44   4-byte padding (colorMatrix must land at 48)
        //  48   float3x3 colorMatrix           (36 used, 12 pad) -> ends at 96
        //  96   float3x3 xyzToDisplayP3        (36 used, 12 pad) -> ends at 144
        // 144   float gamma
        // 148   uint hasLinearizationTable     -> ends at 152
        var data = Data(count: 152)

        func write(_ value: UInt32, at offset: Int) {
            var v = value
            data.replaceSubrange(offset..<offset + 4, with: Data(bytes: &v, count: 4))
        }
        func write(_ value: Float, at offset: Int) {
            var v = value
            data.replaceSubrange(offset..<offset + 4, with: Data(bytes: &v, count: 4))
        }

        write(metadata.cfaPatternIndex, at: 0)
        write(UInt32(metadata.width), at: 4)
        write(UInt32(metadata.height), at: 8)

        let blacks = metadata.blackLevel
        for i in 0..<4 {
            write(i < blacks.count ? blacks[i] : 0.0, at: 12 + i * 4)
        }

        write(metadata.whiteLevel, at: 28)

        let gains = metadata.whiteBalanceGains
        for i in 0..<3 {
            write(i < gains.count ? gains[i] : 1.0, at: 32 + i * 4)
        }
        // Offset 44 is 4 bytes of padding (already zero from Data(count:)).

        let colorMat = metadata.preferredColorMatrix
        for i in 0..<9 {
            let v = i < colorMat.count ? colorMat[i] : (i % 4 == 0 ? 1.0 : 0.0)
            write(v, at: 48 + i * 4)
        }

        let xyzToP3: [Float] = [
            2.37029, -0.81347, -0.43082,
            -0.12073, 1.21084, -0.06581,
            0.01582, -0.07815, 1.02381,
        ]
        for i in 0..<9 {
            write(xyzToP3[i], at: 96 + i * 4)
        }

        write(1.0 as Float, at: 144) // gamma (1.0 = linear identity)
        write(metadata.linearizationTable != nil ? UInt32(1) : UInt32(0), at: 148)

        return data
    }

    // MARK: - Thread Dispatch

    /// Dispatches compute threads with appropriate threadgroup size.
    private func dispatchThreads(
        _ encoder: MTLComputeCommandEncoder,
        pipeline: MTLComputePipelineState,
        width: Int,
        height: Int
    ) {
        let threadGroupWidth = min(pipeline.maxTotalThreadsPerThreadgroup, 16)
        let threadGroupHeight = max(1, min(pipeline.maxTotalThreadsPerThreadgroup / threadGroupWidth, 16))
        let threadGroupSize = MTLSize(
            width: threadGroupWidth,
            height: threadGroupHeight,
            depth: 1
        )
        let threadGroups = MTLSize(
            width: (width + threadGroupSize.width - 1) / threadGroupSize.width,
            height: (height + threadGroupSize.height - 1) / threadGroupSize.height,
            depth: 1
        )
        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
    }
}

// MARK: - MetalPipelineError

enum MetalPipelineError: LocalizedError {
    case deviceUnavailable
    case commandQueueCreationFailed
    case kernelNotFound(String)
    case commandBufferCreationFailed
    case imageCreationFailed
    case textureCreationFailed

    var errorDescription: String? {
        switch self {
        case .deviceUnavailable:
            return "Metal is not available on this device."
        case .commandQueueCreationFailed:
            return "Failed to create a Metal command queue."
        case .kernelNotFound(let name):
            return "Metal kernel '\(name)' was not found in the shader library."
        case .commandBufferCreationFailed:
            return "Failed to create a Metal command buffer."
        case .imageCreationFailed:
            return "Failed to create a Core Image image from the Metal texture."
        case .textureCreationFailed:
            return "Failed to create a Metal texture."
        }
    }
}
