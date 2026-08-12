import Foundation
import SwiftUI
import AVFoundation
import Photos

// MARK: - ReviewResult

/// The artifact shown in the post-capture review overlay. Carries both
/// asset identifiers so the overlay can delete them on demand.
struct ReviewResult: Sendable {
    let jpegData: Data
    let captureZoom: CGFloat
    let timestamp: Date
    let savedAssets: SavedAssets
}

/// The local identifiers of the two assets saved to Photos for a capture.
struct SavedAssets: Sendable {
    let printID: String
    let rawID: String?
}

// MARK: - CameraViewModel

/// Owns the camera UI state and orchestrates capture → develop → save.
@MainActor
@Observable
final class CameraViewModel {

    let captureService = CaptureService()
    let developService: DevelopService
    let storageService = StorageService()

    // Authorization
    private(set) var cameraAuthStatus: AVAuthorizationStatus = .notDetermined
    private(set) var photoAuthStatus: PHAuthorizationStatus = .notDetermined
    var hasRequiredAuth: Bool {
        cameraAuthStatus == .authorized && photoAuthStatus == .authorized
    }

    // Session
    private(set) var isSessionRunning = false
    private(set) var isConfigured = false
    private(set) var error: Error?

    // Capture
    private(set) var isCapturing = false
    private(set) var lastReviewResult: ReviewResult?

    // Camera controls
    private(set) var cameraPosition: CameraPosition = .back
    private(set) var flashMode: FlashMode = .off
    private(set) var flashAvailable = false
    var isRAWEnabled: Bool = true
    var showsGrid = false
    var aspectRatio: AspectRatio = .ratio4x3
    var exposureCompensation: ExposureCompensation = .zero
    private(set) var zoomFactor: CGFloat = 1.0
    private(set) var zoomRange: ClosedRange<CGFloat> = 1.0...1.0

    // Self-timer
    var selfTimer: SelfTimerOption = .off
    private(set) var selfTimerRemaining: Int = 0
    private var selfTimerTask: Task<Void, Never>?

    init() {
        self.developService = DevelopService()
        cameraAuthStatus = AVCaptureDevice.authorizationStatus(for: .video)
        photoAuthStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    // MARK: - Authorization

    @discardableResult
    func requestCameraAccess() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        cameraAuthStatus = granted ? .authorized : .denied
        return granted
    }

    /// Full read-write access is required: on iOS 26, PhotoKit rejects every
    /// RAW+print pair layout for apps holding only add-only authorization
    /// (`PHPhotosErrorChangeNotSupported` / 3300, verified on-device). The
    /// "Allow Selected Photos" grant also cannot pair RAW companions.
    @discardableResult
    func requestPhotoLibraryAccess() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        photoAuthStatus = status
        return status == .authorized
    }

    func requestAllPermissions() async -> Bool {
        let camera = await requestCameraAccess()
        let photos = await requestPhotoLibraryAccess()
        return camera && photos
    }

    // MARK: - Session Lifecycle

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

    func stop() async {
        selfTimerTask?.cancel()
        await captureService.stopSession()
        isSessionRunning = false
    }

    private func refreshCameraControlState() async {
        zoomRange = await captureService.videoZoomRange()
        flashAvailable = await captureService.currentCameraHasTorch()
        cameraPosition = await captureService.cameraPosition
        flashMode = await captureService.flashMode
    }

    // MARK: - Camera Controls

    func toggleCamera() async {
        do {
            cameraPosition = try await captureService.toggleCamera()
            zoomFactor = 1.0
            await refreshCameraControlState()
        } catch {
            self.error = error
        }
    }

    func cycleFlash() async {
        do {
            flashMode = try await captureService.cycleFlash()
        } catch {
            self.error = error
        }
    }

    /// Zoom never changes during a capture (changing `videoZoomFactor` while
    /// a RAW capture is in flight can crash AVFoundation). Captures at zoom
    /// ≥ 1× run at 1× internally and restore the framing immediately
    /// (`CaptureService.capturePhoto`).
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

    func toggleGrid() { showsGrid.toggle() }
    func toggleRAW() { isRAWEnabled.toggle() }
    func cycleAspectRatio() { aspectRatio = aspectRatio.next() }

    /// Deletes the print and (if present) DNG asset for the last capture and
    /// dismisses the review overlay.
    func deleteLastCapture() {
        guard let review = lastReviewResult else { return }
        let assets = review.savedAssets
        lastReviewResult = nil
        Task { try? await storageService.deletePair(printID: assets.printID, rawID: assets.rawID) }
    }

    func cycleExposureCompensation() {
        exposureCompensation = exposureCompensation.next()
        Task { try? await captureService.setExposureBias(exposureCompensation.stops) }
    }

    func clearReview() { lastReviewResult = nil }

    /// Deletes the print and (if present) DNG asset for the last capture and
    /// dismisses the review overlay.
    /// Cycles self-timer off → 3s → 10s → off. Cancels any in-flight countdown.
    func cycleSelfTimer() {
        selfTimerTask?.cancel()
        selfTimerRemaining = 0
        selfTimer = selfTimer.next()
    }

    /// Cancels an in-flight self-timer countdown (e.g. on shutter cancel).
    func cancelSelfTimer() {
        selfTimerTask?.cancel()
        selfTimerRemaining = 0
    }

    // MARK: - Capture Pipeline

    /// Capture → develop → save. If the self-timer is non-zero, waits for the
    /// countdown first (with cancel support).
    func capture() async {
        guard !isCapturing, isConfigured else { return }
        if selfTimer != .off {
            await runSelfTimerCountdown()
        }
        guard !isCapturing else { return } // cancelled during countdown

        isCapturing = true
        defer { isCapturing = false }

        do {
            let photoResult = try await captureService.capturePhoto()
            let orientation = CaptureOrientation(orientation: UIDevice.current.orientation)
            let developResult = try await developService.develop(
                dngData: photoResult.rawData,
                cropFactor: photoResult.captureZoom,
                aspect: aspectRatio,
                orientation: orientation
            )
            let savedAssets: SavedAssets
            if isRAWEnabled {
                let (printID, rawID) = try await storageService.savePair(
                    processedData: developResult.jpegData,
                    rawData: photoResult.rawData
                )
                savedAssets = SavedAssets(printID: printID, rawID: rawID)
            } else {
                let printID = try await storageService.savePrintOnly(processedData: developResult.jpegData)
                savedAssets = SavedAssets(printID: printID, rawID: nil)
            }
            lastReviewResult = ReviewResult(
                jpegData: developResult.jpegData,
                captureZoom: photoResult.captureZoom,
                timestamp: Date(),
                savedAssets: savedAssets
            )
        } catch {
            self.error = error
        }
    }

    private func runSelfTimerCountdown() async {
        selfTimerRemaining = selfTimer.seconds
        selfTimerTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while self.selfTimerRemaining > 0, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                self.selfTimerRemaining -= 1
            }
        }
        await selfTimerTask?.value
    }
}

// MARK: - SelfTimerOption

/// Self-timer delay before the shutter fires. Cycled via HUD.
enum SelfTimerOption: Sendable, CaseIterable {
    case off
    case threeSeconds
    case tenSeconds

    var seconds: Int {
        switch self {
        case .off: return 0
        case .threeSeconds: return 3
        case .tenSeconds: return 10
        }
    }

    var label: String {
        switch self {
        case .off: return "Off"
        case .threeSeconds: return "3s"
        case .tenSeconds: return "10s"
        }
    }

    func next() -> SelfTimerOption {
        switch self {
        case .off: return .threeSeconds
        case .threeSeconds: return .tenSeconds
        case .tenSeconds: return .off
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
