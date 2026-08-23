import Foundation
@preconcurrency import AVFoundation
import CoreImage
import CoreVideo
import UIKit

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

    /// The currently active wide camera device.
    private var cameraDevice: AVCaptureDevice?

    /// The input currently attached to the session, if any.
    private var cameraInput: AVCaptureDeviceInput?

    /// The physical camera position currently in use.
    private(set) var cameraPosition: CameraPosition = .back

    /// The current flash (torch) mode.
    private(set) var flashMode: FlashMode = .off

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
    /// Prevents zoom, exposure, flash, and duplicate capture operations from
    /// re-entering while a RAW photo is in flight.
    private var isCaptureInFlight = false

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

        // Select the back-wide camera (the capture default).
        guard let device = Self.selectCamera(at: .back) else {
            throw CaptureError.cameraUnavailable
        }
        self.cameraDevice = device
        self.cameraPosition = .back
        self.cameraInput = nil

        // Add device input
        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: device)
        } catch {
            throw CaptureError.inputCreationFailed(underlying: error)
        }
        guard session.canAddInput(input) else {
            throw CaptureError.cannotAddInput
        }
        session.addInput(input)
        cameraInput = input

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

    // MARK: - Camera Controls

    /// Toggles between the back and front cameras.
    ///
    /// Reconfigures the session input inside one begin/commit configuration
    /// block. A freshly added input starts at 1× zoom; the selected torch
    /// mode is reapplied when the new camera has a torch (front cameras do
    /// not), otherwise the flash falls back to `.off` and the caller is told
    /// the new state.
    ///
    /// The switch is transactional: if the new input cannot be added, the
    /// previous input (if any) is restored and the session keeps running
    /// with the original camera.
    ///
    /// - Returns: The newly active `CameraPosition`.
    func toggleCamera() async throws -> CameraPosition {
        guard !isCaptureInFlight else { throw CaptureError.captureInProgress }
        guard isConfigured else { throw CaptureError.sessionNotConfigured }

        let next: CameraPosition = cameraPosition == .back ? .front : .back
        guard let device = Self.selectCamera(at: next.avPosition) else {
            throw CaptureError.cameraUnavailable
        }

        let newInput: AVCaptureDeviceInput
        do {
            newInput = try AVCaptureDeviceInput(device: device)
        } catch {
            throw CaptureError.inputCreationFailed(underlying: error)
        }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        let previous = PreviousCameraState(
            input: cameraInput,
            device: cameraDevice,
            position: cameraPosition,
            flashMode: flashMode
        )
        if let previousInput = previous.input {
            session.removeInput(previousInput)
        }
        guard session.canAddInput(newInput) else {
            // New input cannot be added: try to restore the previous input.
            // If that also fails, the session has no usable input and must
            // not claim a configured state.
            restorePreviousCameraState(previous, removing: nil)
            throw CaptureError.cannotAddInput
        }
        session.addInput(newInput)
        cameraInput = newInput
        cameraDevice = device
        cameraPosition = next

        // A fresh input already starts at 1×; resetting explicitly keeps the
        // state honest if the session is later reconfigured.
        do {
            try applyVideoZoomFactor(1.0, to: device)
            if device.hasTorch {
                // A camera switch must never leave the torch on. The flash
                // mode is a capture-time pulse; the preview stays dark.
                try applyTorchMode(.off, to: device)
            } else if flashMode != .off {
                flashMode = .off
            }
        } catch {
            // Post-switch configuration failed: roll back to the prior camera
            // so the session remains usable with coherent state. The typed
            // error (CaptureError.deviceLockFailed / torchUnavailable) is
            // propagated without swallowing. If the previous input cannot be
            // re-added, the session is left without a usable input and must
            // not claim to be configured.
            restorePreviousCameraState(previous, removing: newInput)
            throw error
        }
        return next
    }

    /// The camera state that must be restored if a camera switch fails, so
    /// both failure paths share one rollback implementation.
    private struct PreviousCameraState {
        let input: AVCaptureDeviceInput?
        let device: AVCaptureDevice?
        let position: CameraPosition
        let flashMode: FlashMode
    }

    /// Restores the session to `previous` after a failed camera switch.
    /// `removing` is the input added by the failed switch that must be torn
    /// down first (nil when the new input was never added). If the previous
    /// input cannot be re-added, the session is left without a usable input
    /// and must not claim a configured state.
    private func restorePreviousCameraState(_ previous: PreviousCameraState, removing newInput: AVCaptureDeviceInput?) {
        if let newInput {
            session.removeInput(newInput)
        }
        var didRestorePrevious = false
        if let previousInput = previous.input, session.canAddInput(previousInput) {
            session.addInput(previousInput)
            didRestorePrevious = true
        }
        if didRestorePrevious {
            cameraInput = previous.input
            cameraDevice = previous.device
            cameraPosition = previous.position
            flashMode = previous.flashMode
        } else {
            isConfigured = false
            cameraInput = nil
            cameraDevice = nil
            cameraPosition = previous.position
            flashMode = previous.flashMode
        }
    }

    /// The zoom range the current camera actually supports
    /// (front cameras typically expose a fixed 1× range).
    func videoZoomRange() async -> ClosedRange<CGFloat> {
        guard let device = cameraDevice else { return 1.0...1.0 }
        return device.minAvailableVideoZoomFactor...device.maxAvailableVideoZoomFactor
    }

    /// Sets the video zoom factor, clamped to the device's available range.
    ///
    /// - Returns: the clamped factor actually applied, which the UI mirrors.
    func setVideoZoomFactor(_ factor: CGFloat) async throws -> CGFloat {
        guard !isCaptureInFlight else { throw CaptureError.captureInProgress }
        guard let device = cameraDevice else { throw CaptureError.sessionNotConfigured }
        let clamped = ZoomMath.clamped(
            factor,
            range: device.minAvailableVideoZoomFactor...device.maxAvailableVideoZoomFactor
        )
        try applyVideoZoomFactor(clamped, to: device)
        return clamped
    }
    /// The device's current zoom factor. Exposed so callers can reconcile
    /// published framing state after a failed post-capture zoom restore.
    func currentVideoZoomFactor() async -> CGFloat? {
        cameraDevice?.videoZoomFactor
    }

    func currentCameraHasTorch() async -> Bool {
        cameraDevice?.hasTorch ?? false
    }

    /// Advances the flash mode off → on → off.
    ///
    /// Selecting a mode never turns the torch on or leaves it on: `on` means
    /// "pulse the torch during the next capture", not "keep the work light
    /// on". RAW single exposures cannot use the processed-pipeline photo
    /// flash, so the torch pulse is the honest flash equivalent for pikicam.
    ///
    /// - Returns: the newly active `FlashMode`.
    func cycleFlash() async throws -> FlashMode {
        guard !isCaptureInFlight else { throw CaptureError.captureInProgress }
        guard let device = cameraDevice, device.hasTorch else {
            throw CaptureError.torchUnavailable
        }
        flashMode = flashMode.next()
        return flashMode
    }

    /// Sets the focus and exposure point of interest to the tapped location.
    ///
    /// Matches the system Camera app's tap-to-meter behavior: the device
    /// focuses and meters at the same normalized point. The point comes from
    /// `PreviewView.devicePoint(for:)`, so it is already in AVFoundation's
    /// normalized capture-device coordinates.
    func setFocusAndExposure(at point: CGPoint) async throws {
        guard !isCaptureInFlight else { throw CaptureError.captureInProgress }
        guard let device = cameraDevice else { throw CaptureError.sessionNotConfigured }
        guard device.isFocusPointOfInterestSupported,
              device.isExposurePointOfInterestSupported else {
            throw CaptureError.focusExposureUnavailable
        }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            device.focusPointOfInterest = point
            device.exposurePointOfInterest = point
            if device.isFocusModeSupported(.autoFocus) {
                device.focusMode = .autoFocus
            }
            if device.isExposureModeSupported(.autoExpose) {
                device.exposureMode = .autoExpose
            }
        } catch {
            throw CaptureError.deviceLockFailed(underlying: error)
        }
    }

    // MARK: - Private Camera Helpers

    /// Applies exposure compensation to the current camera **live**: unlike
    /// zoom, `exposureTargetBias` is safe to change at any time (it steers
    /// the metering decision, not the sensor geometry), so the preview
    /// brightens/darkens immediately — matching every standard camera app.
    ///
    /// The value snaps to 1/3 stops via `ExposureCompensation`, then clamps
    /// to the device's supported bias range (which can be narrower than
    /// ±3 EV). The applied value is returned so the UI publishes exactly
    /// what the device holds.
    ///
    /// - Parameter stops: The requested bias in EV stops.
    /// - Returns: The snapped/clamped stops actually applied.
    /// - Throws: `CaptureError.captureInProgress`, `.sessionNotConfigured`,
    ///   or `.deviceLockFailed`.
    func setExposureBias(_ stops: Double) async throws -> Double {
        guard !isCaptureInFlight else { throw CaptureError.captureInProgress }
        guard let device = cameraDevice else { throw CaptureError.sessionNotConfigured }
        let snapped = ExposureCompensation(stops: stops).stops
        let deviceRange = Double(device.minExposureTargetBias)...Double(device.maxExposureTargetBias)
        let target = max(deviceRange.lowerBound, min(snapped, deviceRange.upperBound))
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            // `exposureTargetBias` itself is get-only; the setter is this
            // asynchronous method. Its completion fires on an arbitrary
            // queue, so resume the actor from there.
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                device.setExposureTargetBias(Float(target)) { _ in
                    continuation.resume()
                }
            }
        } catch {
            throw CaptureError.deviceLockFailed(underlying: error)
        }
        return target
    }

    /// Applies a zoom factor under a configuration lock. The deferred unlock
    /// is installed only after the lock succeeds, so a thrown setter can
    /// never wedge the device's configuration lock.
    private func applyVideoZoomFactor(_ factor: CGFloat, to device: AVCaptureDevice) throws {
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            device.videoZoomFactor = factor
        } catch {
            throw CaptureError.deviceLockFailed(underlying: error)
        }
    }

    /// Applies a torch (flash) mode under a configuration lock.
    private func applyTorchMode(_ mode: FlashMode, to device: AVCaptureDevice) throws {
        guard device.hasTorch, device.isTorchModeSupported(mode.avTorchMode) else {
            throw CaptureError.torchUnavailable
        }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            device.torchMode = mode.avTorchMode
        } catch {
            throw CaptureError.deviceLockFailed(underlying: error)
        }
    }

    // MARK: - Photo Capture

    /// Captures a single Bayer RAW photo (DNG-only).
    ///
    /// Configures the capture settings to use pure Bayer format (not ProRAW),
    /// which disables all multi-frame computational photography features, and
    /// requests RAW only — no processed print is produced or retained.
    ///
    /// Pure-Bayer RAW capture is only legal at 1× on this device: requesting
    /// `rawPixelFormatType` while `videoZoomFactor > 1` makes AVFoundation's
    /// `-[AVCapturePhotoOutput capturePhotoWithSettings:delegate:]` raise an
    /// uncaught ObjC exception → SIGABRT (verified in on-device crash logs).
    /// The capture therefore runs at 1× and the framing zoom is restored
    /// immediately afterwards; the DNG stays the full-sensor original (a
    /// crop is never a capture decision).
    ///
    /// - Returns: The captured full-sensor DNG and the capture timestamp.
    /// - Throws: `CaptureError` if capture fails.
    func capturePhoto(aspectRatio: AspectRatio = .ratio4x3) async throws -> CapturedDNG {
        #if os(iOS)
        guard !isCaptureInFlight else { throw CaptureError.captureInProgress }
        isCaptureInFlight = true
        defer { isCaptureInFlight = false }

        // Ensure we have a valid Bayer format selected. Checked first so a
        // platform without a Bayer sensor (e.g. the simulator) fails with the
        // explicit no-Bayer error rather than a session precondition error.
        guard let bayerFormat = await queryActiveBayerFormat() else {
            throw CaptureError.noBayerFormatAvailable
        }

        guard let device = cameraDevice else {
            throw CaptureError.sessionNotConfigured
        }

        // Remember the framing zoom, capture at 1×, then restore it. A failed
        // restore is propagated as a typed error so the caller never observes
        // success with a stale 1× zoom / divergent UI state.
        let captureZoom = device.videoZoomFactor
        let needsZoomReset = captureZoom != 1.0
        if needsZoomReset {
            try applyVideoZoomFactor(1.0, to: device)
        }

        let dngData: Data
        do {
            if needsZoomReset {
                // Let the session settle on the 1× format before capturing:
                // an immediate capture right after the zoom change can return
                // incomplete photo data.
                try await Task.sleep(nanoseconds: 250_000_000)
            }

            // Configure RAW-only photo settings: the sole delivered payload is the
            // Bayer DNG. No processed format is requested and no processed data
            // is retained.
            let settings = AVCapturePhotoSettings(rawPixelFormatType: bayerFormat)
            // Never set `photoQualityPrioritization` on RAW captures: AVFoundation
            // raises NSInvalidArgumentException ("Unsupported when capturing RAW")
            // at capture time. The default (.balanced) is used.

            // Flash is a torch pulse: turn it on for the exposure and back off
            // immediately after, so the flash never stays on after capture.
            let shouldPulseTorch = flashMode == .on && device.hasTorch
            if shouldPulseTorch {
                try applyTorchMode(.on, to: device)
            }

            // Use the async extension on AVCapturePhotoOutput for delegate bridging.
            let photo = try await photoOutput.capturePhoto(with: settings)

            // Turning the torch back off after the exposure is best-effort: a
            // post-capture cleanup failure must never discard a successfully
            // captured DNG.
            if shouldPulseTorch {
                try? applyTorchMode(.off, to: device)
            }

            guard let fileData = photo.fileDataRepresentation() else {
                throw CaptureError.missingImageData
            }
            dngData = fileData
        } catch {
            // Capture (or the settle sleep) failed after the 1× switch: restore
            // the framing zoom before propagating the original error. Also make
            // sure a failed capture never leaves the torch on.
            //
            // Both restores are best-effort here: a restore failure must never
            // mask the capture error that caused this path (the success path
            // below propagates zoom-restore failures explicitly; here the
            // original capture failure is the diagnostic that matters).
            if needsZoomReset {
                try? applyVideoZoomFactor(captureZoom, to: device)
            }
            if flashMode == .on, cameraDevice?.hasTorch == true {
                try? applyTorchMode(.off, to: device)
            }
            if let captureError = error as? CaptureError {
                throw captureError
            }
            throw CaptureError.captureFailed(underlying: error)
        }

        // Capture succeeded: restore the framing zoom. A failure here does not
        // silently return the DNG with the device left at 1× — the typed error
        // is propagated and the DNG is not reported as a successful capture
        // with stale zoom. The device remains at 1× but the error makes the
        // state divergence explicit and the next capture will re-apply framing.
        if needsZoomReset {
            try applyVideoZoomFactor(captureZoom, to: device)
        }

        let orientation = await MainActor.run { CaptureOrientation(orientation: UIDevice.current.orientation) }
        return CapturedDNG(
            data: dngData,
            capturedAt: Date(),
            orientation: orientation,
            aspectRatio: aspectRatio,
            zoomFactor: captureZoom
        )
        #else
        throw CaptureError.unsupportedPlatform
        #endif
    }

    // MARK: - Format Selection

    /// Returns a pure-Bayer RAW pixel format the photo output currently
    /// supports, or `nil` if none does.
    ///
    /// `AVCapturePhotoOutput.availableRawPhotoPixelFormatTypes` is the static
    /// output-wide list of RAW formats this output can produce. It is the
    /// same list AVFoundation validates `rawPixelFormatType` against at
    /// `capturePhotoWithSettings:` time; requesting a format outside it raises
    /// an uncaught ObjC `NSInvalidArgumentException` → SIGABRT.
    func queryActiveBayerFormat() async -> OSType? {
        await MainActor.run { () -> OSType? in
            photoOutput.availableRawPhotoPixelFormatTypes
                .filter { Self.isBayerRawPixelFormat($0) }
                .first
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

    // MARK: - Private Helpers

    /// Selects the wide-angle camera at the given position.
    ///
    /// Prefers the main wide camera (.builtInWideAngleCamera) over ultra-wide or
    /// telephoto. On devices with multiple lenses, this ensures we get the primary
    /// sensor for the requested position.
    ///
    /// - Returns: The selected AVCaptureDevice, or nil if no suitable camera exists.
    private static func selectCamera(at position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: position
        )

        // Return the first wide-angle camera found
        return discoverySession.devices.first
    }

    /// Configures the photo output for RAW capture.
    ///
    /// Sets `isAppleProRAWEnabled = false` to ensure we get pure Bayer data.
    /// `maxPhotoQualityPrioritization` is deliberately left at its default:
    /// setting it to `.quality` makes `capturePhotoWithSettings:` raise an
    /// NSInvalidArgumentException ("Unsupported when capturing RAW") whenever
    /// the capture settings request RAW — an uncaught ObjC exception that
    /// aborts the app (verified on-device via crash logs).
    private func configureRAWOutput() {
        #if os(iOS)
        // Disable Apple ProRAW to get pure Bayer
        photoOutput.isAppleProRAWEnabled = false
        #endif
    }
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
    case missingImageData
    case captureFailed(underlying: Error)
    case captureInProgress
    case captureTimedOut
    case unsupportedPlatform
    case sessionNotConfigured
    case torchUnavailable
    case focusExposureUnavailable
    case deviceLockFailed(underlying: Error)

    static func == (lhs: CaptureError, rhs: CaptureError) -> Bool {
        switch (lhs, rhs) {
        case (.cameraUnavailable, .cameraUnavailable),
             (.cannotAddInput, .cannotAddInput),
             (.cannotAddOutput, .cannotAddOutput),
             (.noBayerFormatAvailable, .noBayerFormatAvailable),
             (.missingImageData, .missingImageData),
             (.captureInProgress, .captureInProgress),
             (.captureTimedOut, .captureTimedOut),
             (.unsupportedPlatform, .unsupportedPlatform),
             (.sessionNotConfigured, .sessionNotConfigured),
             (.torchUnavailable, .torchUnavailable),
             (.focusExposureUnavailable, .focusExposureUnavailable):
            return true
        case let (.inputCreationFailed(l), .inputCreationFailed(r)),
             let (.deviceLockFailed(l), .deviceLockFailed(r)),
             let (.captureFailed(l), .captureFailed(r)):
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
        case .missingImageData:
            return "The captured photo contains no image data."
        case .captureFailed(let error):
            return "The photo could not be captured: \(error.localizedDescription)"
        case .captureInProgress:
            return "A photo is already being captured."
        case .captureTimedOut:
            return "The photo capture did not complete in time."
        case .unsupportedPlatform:
            return "Camera capture is only supported on iPhone."
        case .sessionNotConfigured:
            return "The capture session is not configured yet."
        case .torchUnavailable:
            return "This camera has no flash (torch)."
        case .focusExposureUnavailable:
            return "This camera does not support tap-to-focus/exposure."
        case .deviceLockFailed(let error):
            return "The camera could not be configured: \(error.localizedDescription)"
        }
    }
}
