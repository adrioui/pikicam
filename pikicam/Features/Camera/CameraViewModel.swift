import Foundation
import SwiftUI
import AVFoundation
import Photos

// MARK: - CameraViewModel

/// Owns the camera UI state and orchestrates capture → single DNG save.
///
/// The camera has one mutually exclusive phase — `idle`, `countdown`,
/// `capturing`, or `savingDNG` — so a second shutter action can never start
/// a duplicate capture while one is in flight. Saving persists exactly one
/// unchanged full-sensor DNG through `PhotoLibraryManager`; the latest
/// capture is published only after the Photos commit succeeds.
@MainActor
@Observable
final class CameraViewModel {

    /// The single observable camera phase. Exactly one is active at a time.
    enum Phase: Equatable, Sendable {
        /// No capture activity; the shutter can start one.
        case idle
        /// The self-timer is counting down; the shutter cancels it.
        case countdown
        /// The sensor exposure is in flight.
        case capturing
        /// The captured DNG is being committed to Photos.
        case savingDNG
    }

    let captureService = CaptureService()
    let libraryModel = PikicamLibraryModel()

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

    // Capture phase
    private(set) var phase: Phase = .idle
    private var captureTask: Task<Void, Never>?

    // Camera controls
    private(set) var cameraPosition: CameraPosition = .back
    private(set) var flashMode: FlashMode = .off
    private(set) var flashAvailable = false
    var framingMode: FramingMode = .photo
    var showsGrid = false
    var exposureCompensation: ExposureCompensation = .zero
    private(set) var zoomFactor: CGFloat = 1.0
    private(set) var zoomRange: ClosedRange<CGFloat> = 1.0...1.0

    // Self-timer
    var selfTimer: SelfTimerOption = .off
    private(set) var selfTimerRemaining: Int = 0
    private var selfTimerTask: Task<Void, Never>?

    init() {
        cameraAuthStatus = AVCaptureDevice.authorizationStatus(for: .video)
        photoAuthStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    // MARK: - Authorization

    /// Re-reads the current camera authorization without prompting.
    func refreshCameraAuthorization() {
        cameraAuthStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }

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
        cancelCapture()
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
        guard phase == .idle else { return }
        do {
            cameraPosition = try await captureService.toggleCamera()
            zoomFactor = 1.0
            exposureCompensation = .zero
            await refreshCameraControlState()
        } catch {
            self.error = error
        }
    }

    func cycleFlash() async {
        guard phase == .idle else { return }
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
        guard phase == .idle else { return }
        let clamped = ZoomMath.clamped(factor, range: zoomRange)
        guard clamped != zoomFactor else { return }
        do {
            zoomFactor = try await captureService.setVideoZoomFactor(clamped)
        } catch {
            self.error = error
        }
    }

    func toggleGrid() {
        guard phase == .idle else { return }
        showsGrid.toggle()
    }

    func cycleFramingMode() {
        guard phase == .idle else { return }
        framingMode = framingMode.next()
    }

    func cycleExposureCompensation() {
        guard phase == .idle else { return }
        exposureCompensation = exposureCompensation.next()
        Task { try? await captureService.setExposureBias(exposureCompensation.stops) }
    }

    /// Cycles self-timer off → 3s → 10s → off. Cancels any in-flight countdown.
    func cycleSelfTimer() {
        guard phase == .idle else { return }
        selfTimerTask?.cancel()
        selfTimerRemaining = 0
        selfTimer = selfTimer.next()
    }

    /// Cancels an in-flight self-timer countdown (e.g. on shutter cancel).
    func cancelSelfTimer() {
        guard phase == .countdown else { return }
        selfTimerTask?.cancel()
        selfTimerRemaining = 0
        phase = .idle
    }

    // MARK: - Capture Pipeline

    /// Begins the shutter operation: countdown (if armed) → capture → single
    /// DNG save. Mutually exclusive with any in-flight phase; a second shutter
    /// while `countdown` cancels the countdown instead.
    func capture() {
        switch phase {
        case .countdown:
            cancelSelfTimer()
        case .idle:
            guard isConfigured else { return }
            captureTask = Task { await runCapture() }
        case .capturing, .savingDNG:
            break // never starts a duplicate
        }
    }

    private func runCapture() async {
        if selfTimer != .off {
            await runSelfTimerCountdown()
        }
        guard !Task.isCancelled, phase == .idle else { return }

        phase = .capturing
        do {
            let dng = try await captureService.capturePhoto()
            phase = .savingDNG
            let capture = try await libraryModel.save(dng.data)
            libraryModel.select(capture)
            // Publish the latest capture only after the Photos commit.
            
            // Brief restrained capture feedback; state returns to idle.
            phase = .idle
        } catch {
            self.error = error
            phase = .idle
        }
        captureTask = nil
    }

    private func runSelfTimerCountdown() async {
        phase = .countdown
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
        if phase == .countdown, selfTimerRemaining == 0 {
            phase = .idle
        }
    }

    private func cancelCapture() {
        captureTask?.cancel()
        captureTask = nil
        phase = .idle
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
