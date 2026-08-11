import Foundation
import SwiftUI
import AVFoundation
import Photos

// MARK: - CameraViewModel

/// The main view model for the camera screen.
///
/// Owned by the `@MainActor` and uses `@Observable` (iOS 17+) for fine-grained
/// view updates. Bridges the `CaptureService` actor to the SwiftUI layer and
/// orchestrates the capture → develop → save pipeline.
///
/// ## Pipeline Flow
/// ```
/// Permission → Configure Session → Start Preview
///   → Shutter → CaptureService.capturePhoto()
///   → DevelopService.develop(dngData)        // zero-process
///   → StorageService.savePair(print, raw)
/// ```
@MainActor
@Observable
final class CameraViewModel {

    // MARK: - Services

    /// The actor managing the AVCaptureSession pipeline.
    let captureService = CaptureService()

    /// The actor managing zero-process RAW development.
    let developService: DevelopService

    /// The actor managing photo library saves.
    let storageService = StorageService()

    // MARK: - Authorization State

    /// Whether the user has granted camera access.
    private(set) var cameraAuthStatus: AVAuthorizationStatus = .notDetermined

    /// Whether the user has granted photo library write access.
    private(set) var photoAuthStatus: PHAuthorizationStatus = .notDetermined

    /// Computed: true when both camera and photo library access are granted.
    var hasRequiredAuth: Bool {
        cameraAuthStatus == .authorized && photoAuthStatus == .authorized
    }

    // MARK: - Session State

    /// Whether the capture session is running.
    private(set) var isSessionRunning = false

    /// Whether configuration is in progress or has completed.
    private(set) var isConfigured = false

    /// Configuration or capture error, if any.
    private(set) var error: Error?

    // MARK: - Capture State

    /// Whether a photo capture is currently in flight.
    private(set) var isCapturing = false

    // MARK: - Camera Controls

    /// The physical camera currently in use.
    private(set) var cameraPosition: CameraPosition = .back

    /// The current flash (torch) mode.
    private(set) var flashMode: FlashMode = .off

    /// Whether the current camera has a torch (drives the flash button).
    private(set) var flashAvailable = false

    /// Whether the 3×3 framing grid is shown over the preview.
    var showsGrid = false

    /// The zoom factor currently applied to the camera.
    private(set) var zoomFactor: CGFloat = 1.0

    /// The zoom range the current camera supports.
    private(set) var zoomRange: ClosedRange<CGFloat> = 1.0...1.0

    // MARK: - Initialization

    init() {
        self.developService = DevelopService()
        cameraAuthStatus = AVCaptureDevice.authorizationStatus(for: .video)
        photoAuthStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    // MARK: - Authorization

    /// Requests camera access if not yet determined.
    @discardableResult
    func requestCameraAccess() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        cameraAuthStatus = granted ? .authorized : .denied
        return granted
    }

    /// Requests full photo library access if not yet determined.
    ///
    /// Full (read-write) access is required: on iOS 26, PhotoKit rejects every
    /// RAW+print pair layout for apps holding only add-only authorization
    /// (PHPhotosErrorChangeNotSupported / 3300, verified on-device). The
    /// "Allow Selected Photos" (limited) grant also cannot pair RAW
    /// companions, so only `.authorized` counts here.
    @discardableResult
    func requestPhotoLibraryAccess() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        photoAuthStatus = status
        return status == .authorized
    }

    /// Requests all required permissions. Returns `true` once all are granted.
    func requestAllPermissions() async -> Bool {
        let camera = await requestCameraAccess()
        let photos = await requestPhotoLibraryAccess()
        return camera && photos
    }

    // MARK: - Session Lifecycle

    /// Configures the capture session and starts it.
    func start() async {
        guard hasRequiredAuth else {
            error = CameraViewModelError.missingPermissions
            return
        }

        do {
            try await captureService.startSession()
            isConfigured = true
            isSessionRunning = true
            await refreshCameraControlState()
        } catch {
            self.error = error
            isConfigured = false
        }
    }

    /// Stops the capture session.
    func stop() async {
        await captureService.stopSession()
        isSessionRunning = false
    }

    /// Re-reads device-dependent control state after the session or camera
    /// position changes.
    private func refreshCameraControlState() async {
        zoomRange = await captureService.videoZoomRange()
        flashAvailable = await captureService.currentCameraHasTorch()
        cameraPosition = await captureService.cameraPosition
        flashMode = await captureService.flashMode
    }

    // MARK: - Camera Controls

    /// Flips between the back and front cameras.
    func toggleCamera() async {
        do {
            cameraPosition = try await captureService.toggleCamera()
            zoomFactor = 1.0
            await refreshCameraControlState()
        } catch {
            self.error = error
        }
    }

    /// Advances flash off → on → auto → off.
    func cycleFlash() async {
        do {
            flashMode = try await captureService.cycleFlash()
        } catch {
            self.error = error
        }
    }

    /// Applies a (clamped) zoom factor from the pinch gesture.
    ///
    /// The zoom is a device-level property: the sensor crops its readout so
    /// the preview shows the framed field of view. The value is clamped to the
    /// device's valid range and applied under `lockForConfiguration()`.
    /// Zoom is never changed while a capture is in flight (changing
    /// `videoZoomFactor` during RAW capture can crash AVFoundation); captures
    /// at a zoom ≥ 1× run at 1× internally and restore the framing immediately
    /// (see `CaptureService.capturePhoto`).
    func setZoom(_ factor: CGFloat) async {
        guard !isCapturing else { return }
        let clamped = ZoomMath.clamped(factor, range: zoomRange)
        guard clamped != zoomFactor else { return }
        do {
            zoomFactor = try await captureService.setVideoZoomFactor(clamped)
        } catch {
            self.error = error
        }
    }

    /// Toggles the 3×3 framing grid.
    func toggleGrid() {
        showsGrid.toggle()
    }

    // MARK: - Capture Pipeline

    /// Captures a single photo: capture → zero-develop → save.
    ///
    /// The pipeline runs across three actors, each on its own queue:
    /// 1. `CaptureService` captures the Bayer RAW + processed preview.
    /// 2. `DevelopService` zero-develops the DNG into a print, cropped to the
    ///    framing zoom (the DNG is full-sensor; the crop is print-time only).
    /// 3. `StorageService` saves both the DNG and print to the Photos library.
    ///
    /// The zoom is a device property that crops the sensor; pure-Bayer RAW
    /// only captures at 1× (AVFoundation crashes otherwise), so the capture
    /// runs at 1× and the framing zoom is restored immediately. The print is
    /// cropped to the framing zoom so the saved photo matches the composition.
    func capture() async {
        guard !isCapturing, isConfigured else { return }

        isCapturing = true
        defer { isCapturing = false }

        do {
            // Step 1: Capture pure Bayer RAW (captured at 1× internally; the
            // framing zoom is restored before the capture returns).
            let photoResult = try await captureService.capturePhoto()

            // Step 2: Zero-develop the DNG, cropping the print to the framing
            // zoom so the saved photo matches what the user composed.
            let developResult = try await developService.develop(
                dngData: photoResult.rawData,
                cropFactor: photoResult.captureZoom
            )

            // Step 3: Save the print + DNG pair to the Photos library.
            try await storageService.savePair(
                processedData: developResult.jpegData,
                rawData: photoResult.rawData
            )
        } catch {
            self.error = error
        }
    }
}

// MARK: - Errors

enum CameraViewModelError: LocalizedError {
    case missingPermissions

    var errorDescription: String? {
        switch self {
        case .missingPermissions:
            return "Camera and photo library access are required."
        }
    }
}
