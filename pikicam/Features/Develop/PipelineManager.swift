import Foundation
import CoreImage
import Metal

/// Manages the selection and configuration of the raw development pipeline.
///
/// `PipelineManager` provides a unified interface for choosing between
/// different processing backends:
/// - **Phase 1:** `CIRAWZeroProcessor` (CIRAWFilter-based, always available)
/// - **Phase 2:** `MetalDebayerProcessor` (custom Metal kernels)
/// - **Phase 3:** `LibRawProcessor` (full control via LibRaw, not yet integrated)
///
/// The manager handles fallback logic — if the Metal or LibRaw pipeline is
/// unavailable on a given device, it falls back to CIRAWFilter automatically.
///
/// Marked `nonisolated`: pipeline management and development are pure
/// computation with no UI state, executed on background actors.
nonisolated final class PipelineManager: Sendable {

    // MARK: - Pipeline Selection

    /// The available processing pipeline backends.
    enum Pipeline: String, CaseIterable, Sendable {
        /// Apple's CIRAWFilter-based pipeline (Phase 1, always available).
        case ciRaw = "CIRAWFilter"
        /// Custom Metal compute pipeline (Phase 2+).
        case metal = "Metal"
        /// LibRaw-based pipeline (Phase 3+).
        case libRaw = "LibRaw"
    }

    /// The currently active pipeline.
    private let activePipeline: Pipeline

    /// The CIRAWFilter-based processor (always available).
    private let ciRawProcessor = CIRAWZeroProcessor()

    /// The Metal-based processor (Phase 2+).
    private let metalProcessor = MetalDebayerProcessor()

    /// The LibRaw-based processor (Phase 3+).
    private let libRawProcessor = LibRawProcessor()

    // MARK: - Initialization

    init(preferredPipeline: Pipeline = .ciRaw) {
        self.activePipeline = preferredPipeline
    }

    // MARK: - Processing

    /// Develops DNG data using the active pipeline with automatic fallback.
    ///
    /// If the preferred pipeline fails, it falls back to CIRAWFilter.
    func develop(dngData: Data, mode: CaptureMode) throws -> CIImage {
        switch activePipeline {
        case .ciRaw:
            return try ciRawProcessor.develop(dngData: dngData, mode: mode)

        case .metal:
            do {
                return try metalProcessor.develop(dngData: dngData, mode: mode)
            } catch {
                // Fallback to CIRAWFilter on Metal failure.
                return try ciRawProcessor.develop(dngData: dngData, mode: mode)
            }

        case .libRaw:
            do {
                return try libRawProcessor.develop(dngData: dngData, mode: mode)
            } catch {
                // LibRaw not integrated yet — fall back to Metal, then CIRAW.
                do {
                    return try metalProcessor.develop(dngData: dngData, mode: mode)
                } catch {
                    return try ciRawProcessor.develop(dngData: dngData, mode: mode)
                }
            }
        }
    }

    /// Returns the effective pipeline that was actually used (after fallback).
    var effectivePipeline: Pipeline {
        switch activePipeline {
        case .ciRaw: return .ciRaw
        case .metal: return metalAvailable ? .metal : .ciRaw
        case .libRaw: return .ciRaw // LibRaw not yet integrated
        }
    }

    /// Whether Metal is available on this device.
    private var metalAvailable: Bool {
        MTLCreateSystemDefaultDevice() != nil
    }

    /// Returns a description of the active pipeline for debugging.
    var pipelineDescription: String {
        "\(activePipeline.rawValue) (effective: \(effectivePipeline.rawValue))"
    }

    // MARK: - Pipeline Selection with Fallback Check

    /// Returns the list of pipelines available on this device.
    static var availablePipelines: [Pipeline] {
        var available: [Pipeline] = [.ciRaw]
        if MTLCreateSystemDefaultDevice() != nil {
            available.append(.metal)
        }
        // LibRaw availability is determined at link time.
        // For now, it's not available.
        return available
    }
}
