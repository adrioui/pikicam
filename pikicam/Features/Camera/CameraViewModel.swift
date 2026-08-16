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
    let libraryModel: PikicamLibraryModel

    init(libraryModel: PikicamLibraryModel) {
        self.libraryModel = libraryModel
        cameraAuthStatus = AVCaptureDevice.authorizationStatus(for: .video)
        photoAuthStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    // Authorization
    private(set) var cameraAuthStatus: AVAuthorizationStatus = .notDetermined
    private(set) var photoAuthStatus: PHAuthorizationStatus = .notDetermined
    /// Pikicam needs camera plus Photos read-write, but either `.authorized`
    /// or `.limited` suffices: the single `.photo` DNG resource is creatable
    /// under limited, and visibility gaps are reconciled by
    /// `PhotoLibraryManager` (retains while hidden, prunes only under full
    /// authorization; disallowed operations surface as typed errors).
    var hasRequiredAuth: Bool {
        cameraAuthStatus == .authorized
            && (photoAuthStatus == .authorized || photoAuthStatus == .limited)
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
    // Monotonic guard for pinch-zoom: rapid `.onChanged` ticks spawn
    // concurrent `setZoom` tasks, and only the newest request may publish
    // `zoomFactor` — otherwise a stale task's return overwrites a newer one.
    private var zoomGeneration = 0

    // Self-timer
    var selfTimer: SelfTimerOption = .off
    private(set) var selfTimerRemaining: Int = 0
    private var selfTimerTask: Task<Void, Never>?
    // Generation guard for capture cancellation; a new capture (or a cancel)
    // bumps it so stale tasks drop out of the phase machine.
    private var captureGeneration = 0

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

    /// Requests Photos read-write access. Both `.authorized` and `.limited`
    /// satisfy the DNG-only contract (`one .photo DNG`, no print pair);
    /// `PhotoLibraryManager` handles limited visibility via retention/pruning
    /// and typed `PhotoLibraryError` failures for disallowed operations.
    @discardableResult
    func requestPhotoLibraryAccess() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        photoAuthStatus = status
        return status == .authorized || status == .limited
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
        selfTimerRemaining = 0
        cancelCapture()
        await captureService.clearExposureBias()
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
        zoomGeneration += 1 // invalidate in-flight zoom tasks from the old camera
        do {
            cameraPosition = try await captureService.toggleCamera()
            zoomFactor = 1.0
            exposureCompensation = .zero
            await captureService.clearExposureBias()
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
        zoomGeneration += 1
        let gen = zoomGeneration
        do {
            let applied = try await captureService.setVideoZoomFactor(clamped)
            // Only the newest request publishes: a stale task's return must
            // not overwrite a newer zoom the device already applied.
            guard gen == zoomGeneration else { return }
            zoomFactor = applied
        } catch {
            self.error = error
        }
    }

    func toggleGrid() {
        guard phase == .idle else { return }
        showsGrid.toggle()
    }

    func setFramingMode(_ mode: FramingMode) {
        guard phase == .idle else { return }
        framingMode = mode
    }


    /// Cycles the exposure compensation off → +1/3 → … → +3 → −3 → … and
    /// hands the committed value to `CaptureService` for the next capture.
    ///
    /// `exposureCompensation` is the single source of truth: the HUD reads it,
    /// the next tap cycles from it, and the actor applies it atomically with
    /// the RAW capture. There is no pending/committed split to diverge.
    func cycleExposureCompensation() {
        guard phase == .idle else { return }
        exposureCompensation = exposureCompensation.next()
        let committed = exposureCompensation
        Task { await captureService.setExposureBias(committed.stops) }
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

    /// Begins the shutter operation: countdown (if armed) → capture → single
    /// DNG save. Mutually exclusive with any in-flight phase; a second shutter
    /// while `countdown` cancels the countdown instead.
    func capture() {
        switch phase {
        case .countdown:
            cancelCapture()
        case .idle:
            error = nil
            guard isConfigured, isSessionRunning else { return }
            captureGeneration += 1
            let gen = captureGeneration
            phase = selfTimer == .off ? .capturing : .countdown
            captureTask = Task {
                await runCapture(generation: gen)
            }
        case .capturing, .savingDNG:
            break // never starts a duplicate
        }
    }

    private func runCapture(generation gen: Int) async {
        guard !Task.isCancelled, captureGeneration == gen else { return }
        do {
            if selfTimer != .off {
                await runSelfTimerCountdown(generation: gen)
                guard !Task.isCancelled, captureGeneration == gen, phase == .idle else { return }
                phase = .capturing
            } else {
                guard !Task.isCancelled, captureGeneration == gen, phase == .capturing else { return }
            }
            let dng = try await captureService.capturePhoto()
            guard !Task.isCancelled, captureGeneration == gen else { return }
            phase = .savingDNG
            let capture = try await libraryModel.save(dng)
            guard !Task.isCancelled, captureGeneration == gen else { return }
            libraryModel.select(capture)
            guard captureGeneration == gen else { return }
            phase = .idle
        } catch {
            guard captureGeneration == gen else { return }
            if Task.isCancelled { return }
            // Only capture-pipeline failures can leave the device zoom
            // divergent (a failed post-capture restore); a Photos save
            // failure cannot, so the extra actor hop is scoped to the case
            // that needs it.
            if error is CaptureError, let actualZoom = await captureService.currentVideoZoomFactor() {
                zoomFactor = actualZoom
            }
            self.error = error
            phase = .idle
        }
        if captureGeneration == gen {
            captureTask = nil
        }
    }

    private func runSelfTimerCountdown(generation gen: Int) async {
        guard !Task.isCancelled, captureGeneration == gen else { return }
        phase = .countdown
        selfTimerRemaining = selfTimer.seconds
        selfTimerTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while self.selfTimerRemaining > 0,
                  !Task.isCancelled,
                  self.captureGeneration == gen {
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return
                }
                guard !Task.isCancelled, self.captureGeneration == gen else { return }
                self.selfTimerRemaining -= 1
            }
        }
        await selfTimerTask?.value
        if captureGeneration == gen, phase == .countdown, selfTimerRemaining == 0 {
            phase = .idle
        }
    }

    private func cancelCapture() {
        captureGeneration += 1
        captureTask?.cancel()
        captureTask = nil
        selfTimerTask?.cancel()
        selfTimerRemaining = 0
        phase = .idle
    }
}

// MARK: - SelfTimerOption

/// Self-timer delay before the shutter fires. Cycled via HUD.
nonisolated enum SelfTimerOption: Sendable, CaseIterable {
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
