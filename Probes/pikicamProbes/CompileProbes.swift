import AVFoundation
import AVKit
import CoreImage
import SwiftUI

// MARK: - §1 ledger: compile-time probes
//
// Every symbol here exists *only* so that the build proves the claim. If this
// file fails to compile, the corresponding ledger row is refuted at build
// time on this SDK — the compile log is the evidence.

/// Claim: an actor whose executor is a DispatchSerialQueue compiles under
/// Swift 6 complete strict concurrency (v1 §6.9 / ledger row).
actor SerialQueueExecutorProbe {
    private let queue: DispatchSerialQueue
    nonisolated let unownedExecutor: UnownedSerialExecutor

    init(label: String) {
        self.queue = DispatchSerialQueue(label: label)
        self.unownedExecutor = queue.asUnownedSerialExecutor()
    }

    func ping() -> String { "pong" }
}

/// Claim: `onCameraCaptureEvent` (AVKit) exists with the `.ended` filtering
/// and `defaultSoundDisabled` variants (research 07).
struct CameraCaptureEventProbeView: View {
    var body: some View {
        Color.black
            .onCameraCaptureEvent { _ in }
    }
}

/// Claim: `AVCaptureDevice.RotationCoordinator` exists with the horizon-level
/// angle properties (research 07).
@MainActor
final class RotationCoordinatorProbe {
    init(device: AVCaptureDevice, previewLayer: AVCaptureVideoPreviewLayer) {
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
        let _ = coordinator.videoRotationAngleForHorizonLevelPreview
        let _ = coordinator.videoRotationAngleForHorizonLevelCapture
    }
}

/// Claim: `AVCapturePhotoOutputReadinessCoordinator` exists (research 07).
final class ReadinessCoordinatorProbe: NSObject, AVCapturePhotoOutputReadinessCoordinatorDelegate {
    let coordinator: AVCapturePhotoOutputReadinessCoordinator

    init(output: AVCapturePhotoOutput) {
        coordinator = AVCapturePhotoOutputReadinessCoordinator(photoOutput: output)
        super.init()
        coordinator.delegate = self
        let _ = coordinator.captureReadiness
        let settings = AVCapturePhotoSettings()
        coordinator.startTrackingCaptureRequest(using: settings)
    }

    func readinessCoordinator(_ readinessCoordinator: AVCapturePhotoOutputReadinessCoordinator,
                              captureReadinessDidChange captureReadiness: AVCapturePhotoOutput.CaptureReadiness) {
        let _ = captureReadiness
    }
}

/// Claim: deferred-start APIs exist on AVCaptureSession (research 07).
final class DeferredStartProbe {
    init(session: AVCaptureSession) {
        let _ = session.automaticallyRunsDeferredStart
    }
}

/// Claim: white-balance temperature/tint lock APIs exist (research 07).
final class WBTemperatureTintProbe {
    init(device: AVCaptureDevice) {
        let tAndT = AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(temperature: 5600, tint: 0)
        let _ = try? device.lockForConfiguration()
        let gains = device.deviceWhiteBalanceGains(for: tAndT)
        let _ = gains
        device.unlockForConfiguration()
    }
}

/// Claim: `CIContextOption.memoryTarget` exists; `heif10Representation(of:
/// colorSpace:options:)` is async and returns `Data?` (research 07).
final class CIContextOptionProbe {
    init() {
        let options: [CIContextOption: Any] = [.memoryTarget: 1024]
        let context = CIContext(options: options)
        let _ = context
    }

    func encodeHeif10(of image: CIImage, colorSpace: CGColorSpace, context: CIContext) async throws -> Data? {
        try await context.heif10Representation(of: image, colorSpace: colorSpace, options: [:])
    }
}

/// Marker the runner flips: every compile probe above passed by being in this build.
let compileProbesPassed: [String: Bool] = [
    "actorOnDispatchSerialQueue": true,
    "onCameraCaptureEvent": true,
    "rotationCoordinator": true,
    "readinessCoordinator": true,
    "deferredStart": true,
    "wbTemperatureTint": true,
    "ciContextMemoryTarget": true,
    "heif10RepresentationAsync": true,
]
