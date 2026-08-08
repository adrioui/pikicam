import Foundation
@preconcurrency import AVFoundation
import CoreImage
import CoreVideo

// MARK: - CaptureService

/// An actor managing the AVCaptureSession and photo capture pipeline.
///
/// Uses a custom serial executor to ensure all AVFoundation calls
/// happen on a dedicated serial queue, keeping them off-main and properly isolated.
/// This is necessary because `AVCaptureSession` is not `Sendable` in Swift 6.
actor CaptureService {
    
    // MARK: - Properties

    /// The capture session driving the camera.
    private let session = AVCaptureSession()
    
    /// The photo output used for capturing still images.
    private let photoOutput = AVCapturePhotoOutput()
    
    /// The back-facing wide camera device.
    private var cameraDevice: AVCaptureDevice?
    
    /// Serial queue for all AVFoundation operations.
    private let serialQueue = DispatchSerialQueue(label: "com.pikicam.capture", qos: .userInitiated)
    
    /// Custom executor using the serial queue.
    nonisolated var unownedExecutor: UnownedSerialExecutor {
        serialQueue.asUnownedSerialExecutor()
    }
    
    /// Whether the session is currently running.
    private var isRunning = false

    /// Whether the session has already been configured.
    private var isConfigured = false

    // MARK: - Initialization
    
    init() {}

    // MARK: - Session Configuration

    /// Configures the capture session inputs and outputs once.
    private func configureSessionIfNeeded() throws {
        guard !isConfigured else { return }

        session.beginConfiguration()
        defer { session.commitConfiguration() }
        
        // Configure for high-quality photo capture
        session.sessionPreset = .photo
        
        // Select back-wide camera
        guard let device = selectBackWideCamera() else {
            throw CaptureError.cameraUnavailable
        }
        self.cameraDevice = device
        
        // Add device input
        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else {
                throw CaptureError.cannotAddInput
            }
            session.addInput(input)
        } catch {
            throw CaptureError.inputCreationFailed(underlying: error)
        }
        
        // Add photo output
        guard session.canAddOutput(photoOutput) else {
            throw CaptureError.cannotAddOutput
        }
        session.addOutput(photoOutput)
        
        // Enable RAW capture if available
        configureRAWOutput()
        isConfigured = true
    }

    // MARK: - Session Management

    /// Starts the capture session asynchronously.
    func startSession() async throws {
        guard !isRunning else { return }

        try configureSessionIfNeeded()
        session.startRunning()
        isRunning = true
    }

    /// Stops the capture session asynchronously.
    func stopSession() async {
        guard isRunning else { return }

        session.stopRunning()
        isRunning = false
    }

    /// Returns the capture session for preview layer binding.
    func getSession() -> CaptureSessionBox {
        CaptureSessionBox(session: session)
    }
    
    // MARK: - Photo Capture
    
    /// Captures a single Bayer RAW photo with simultaneous JPEG processing.
    ///
    /// Configures the capture settings to use pure Bayer format (not ProRAW),
    /// which disables all multi-frame computational photography features.
    ///
    /// - Returns: A `PhotoCaptureResult` containing processed and raw data plus the photo.
    /// - Throws: `CaptureError` if capture fails.
    func capturePhoto() async throws -> PhotoCaptureResult {
        #if os(iOS)
        // Ensure we have a valid Bayer format selected
        guard let bayerFormat = await queryAvailableBayerFormats().first else {
            throw CaptureError.noBayerFormatAvailable
        }

        guard let processedCodec = preferredProcessedCodec() else {
            throw CaptureError.noProcessedCodecAvailable
        }

        // Configure photo settings for Bayer RAW + a supported processed format.
        let settings = AVCapturePhotoSettings(
            rawPixelFormatType: bayerFormat,
            processedFormat: [AVVideoCodecKey: processedCodec]
        )
        settings.photoQualityPrioritization = .quality

        // Use the async extension on AVCapturePhotoOutput for delegate bridging.
        let pair = try await photoOutput.capturePhotoPair(with: settings)

        // Extract processed (JPEG) and raw (DNG) data.
        guard let processedPhoto = pair.processedPhoto,
              let rawPhoto = pair.rawPhoto,
              let processedData = processedPhoto.fileDataRepresentation(),
              let rawData = rawPhoto.fileDataRepresentation() else {
            throw CaptureError.missingImageData
        }

        return PhotoCaptureResult(photo: processedPhoto, processedData: processedData, rawData: rawData)
        #else
        throw CaptureError.unsupportedPlatform
        #endif
    }
    
    // MARK: - Format Selection
    
    /// Queries available raw pixel formats and returns those that are pure Bayer.
    ///
    /// Filters out ProRAW formats to ensure we get a single-exposure Bayer readout
    /// with all computational photography disabled.
    ///
    /// - Returns: Array of Bayer raw pixel format type codes.
    func queryAvailableBayerFormats() async -> [OSType] {
        // `isBayerRAWPixelFormat` is main-actor-isolated in the SDK, so the
        // (trivial) query runs on the main actor and returns the result.
        await MainActor.run {
            photoOutput.availableRawPhotoPixelFormatTypes.filter { format in
                Self.isBayerRawPixelFormat(format)
            }
        }
    }

    /// Returns `true` if the pixel format is a pure Bayer raw format
    /// (not ProRAW or processed). Pure Bayer disables all multi-frame
    /// computation (Smart HDR, Deep Fusion, Night Mode) by construction.
    private static func isBayerRawPixelFormat(_ format: OSType) -> Bool {
        switch format {
        case kCVPixelFormatType_14Bayer_RGGB,
             kCVPixelFormatType_14Bayer_GRBG,
             kCVPixelFormatType_14Bayer_GBRG,
             kCVPixelFormatType_14Bayer_BGGR:
            return true
        default:
            return false
        }
    }

    /// Picks a processed-photo codec that this capture output currently supports.
    private func preferredProcessedCodec() -> AVVideoCodecType? {
        if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
            return .hevc
        }

        if photoOutput.availablePhotoCodecTypes.contains(.jpeg) {
            return .jpeg
        }

        return photoOutput.availablePhotoCodecTypes.first
    }
    
    // MARK: - Private Helpers
    
    /// Selects the back-wide camera device.
    ///
    /// Prefers the main wide camera (.builtInWideAngleCamera) over ultra-wide or telephoto.
    /// On devices with multiple lenses, this ensures we get the primary sensor.
    ///
    /// - Returns: The selected AVCaptureDevice, or nil if no suitable camera is found.
    private func selectBackWideCamera() -> AVCaptureDevice? {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .back
        )
        
        // Return the first wide-angle camera found
        return discoverySession.devices.first
    }
    
    /// Configures the photo output for RAW capture.
    ///
    /// Sets `isAppleProRAWEnabled = false` to ensure we get pure Bayer data,
    /// and configures other output properties for quality-first capture.
    private func configureRAWOutput() {
        #if os(iOS)
        // Disable Apple ProRAW to get pure Bayer
        photoOutput.isAppleProRAWEnabled = false
        
        // Set photo quality prioritization to quality over speed
        photoOutput.maxPhotoQualityPrioritization = .quality
        #endif
    }
}

// MARK: - PhotoCaptureResult

/// The result of a photo capture, containing both processed and raw data.
///
/// `AVCapturePhoto` is not `Sendable`, but it is only accessed from within
/// the `CaptureService` actor or transferred to `CameraViewModel` on `@MainActor`.
/// The photo reference is short-lived — data is extracted immediately after capture.
struct PhotoCaptureResult: @unchecked Sendable {
    /// The original captured photo object.
    let photo: AVCapturePhoto

    /// JPEG/HEIC processed image data (ISP-processed preview).
    let processedData: Data

    /// Raw DNG file data from the sensor (Bayer RAW).
    let rawData: Data
}

/// Sendable wrapper for handing the preview layer an AVFoundation session.
///
/// `AVCaptureSession` is managed by `CaptureService`; SwiftUI only stores
/// the reference so `AVCaptureVideoPreviewLayer` can render it.
struct CaptureSessionBox: @unchecked Sendable {
    /// The capture session used by the preview layer.
    let session: AVCaptureSession
}

// MARK: - Errors

enum CaptureError: LocalizedError, Equatable {
    case cameraUnavailable
    case cannotAddInput
    case inputCreationFailed(underlying: Error)
    case cannotAddOutput
    case noBayerFormatAvailable
    case noProcessedCodecAvailable
    case missingImageData
    case unsupportedPlatform

    static func == (lhs: CaptureError, rhs: CaptureError) -> Bool {
        switch (lhs, rhs) {
        case (.cameraUnavailable, .cameraUnavailable),
             (.cannotAddInput, .cannotAddInput),
             (.cannotAddOutput, .cannotAddOutput),
             (.noBayerFormatAvailable, .noBayerFormatAvailable),
             (.noProcessedCodecAvailable, .noProcessedCodecAvailable),
             (.missingImageData, .missingImageData),
             (.unsupportedPlatform, .unsupportedPlatform):
            return true
        case let (.inputCreationFailed(l), .inputCreationFailed(r)):
            let lhsError = l as NSError
            let rhsError = r as NSError
            return lhsError.domain == rhsError.domain && lhsError.code == rhsError.code
        default:
            return false
        }
    }

    var errorDescription: String? {
        switch self {
        case .cameraUnavailable:
            return "No back wide camera is available."
        case .cannotAddInput:
            return "The camera input could not be added to the capture session."
        case .inputCreationFailed(let error):
            return "The camera input could not be created: \(error.localizedDescription)"
        case .cannotAddOutput:
            return "The photo output could not be added to the capture session."
        case .noBayerFormatAvailable:
            return "No Bayer RAW format is available on this camera."
        case .noProcessedCodecAvailable:
            return "No supported processed photo codec is available on this camera."
        case .missingImageData:
            return "The captured photo contains no image data."
        case .unsupportedPlatform:
            return "Camera capture is only supported on iPhone."
        }
    }
}
