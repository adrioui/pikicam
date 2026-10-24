import AVFoundation
import CoreMedia
import Foundation
import Synchronization

struct CaptureOutcome: @unchecked Sendable {
    var success = false
    var error = ""
    var isRawPhoto = false
    var pixelFormat = ""
    var rawWidth = 0
    var rawHeight = 0
    var expectedPhotoCount = 0
    var fusion = false
    var cadc = false
    var stabilization = false
    var redEye = false
    var flashEnabled = false
    var fileBytes = 0
    var fileData: Data?
    var durationSeconds = 0.0
    var iso = 0.0
}

final class PhotoDelegateBox: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let state = Mutex<(CheckedContinuation<CaptureOutcome, Never>?, Bool)>((nil, false))

    func resume(with continuation: CheckedContinuation<CaptureOutcome, Never>) {
        state.withLock { s in
            if s.0 == nil { s.0 = continuation } else { continuation.resume(returning: CaptureOutcome(success: false, error: "double-resume prevented")) }
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        var outcome = CaptureOutcome()
        if let error {
            outcome.error = "\(error)"
        } else {
            outcome.success = true
            outcome.isRawPhoto = photo.isRawPhoto
            if let buffer = photo.pixelBuffer {
                outcome.pixelFormat = CameraProbes.fourCCString(CVPixelBufferGetPixelFormatType(buffer))
            }
            let rs = photo.resolvedSettings
            outcome.rawWidth = Int(rs.rawPhotoDimensions.width)
            outcome.rawHeight = Int(rs.rawPhotoDimensions.height)
            outcome.expectedPhotoCount = rs.expectedPhotoCount
            outcome.flashEnabled = rs.isFlashEnabled
            if let data = photo.fileDataRepresentation() {
                outcome.fileBytes = data.count
                outcome.fileData = data
            }
            if let exif = photo.metadata[kCGImagePropertyExifDictionary as String] as? [String: Any] {
                outcome.iso = (exif["ISOSpeedRatings"] as? [NSNumber])?.first?.doubleValue ?? 0
                outcome.durationSeconds = exif["ExposureTime"] as? Double ?? 0
            }
        }
        let continuation = state.withLock { s -> CheckedContinuation<CaptureOutcome, Never>? in
            guard let c = s.0, !s.1 else { return nil }
            s.1 = true
            return c
        }
        continuation?.resume(returning: outcome)
    }
}

actor FixtureCaptureAgent {
    private let queue: DispatchSerialQueue
    nonisolated let unownedExecutor: UnownedSerialExecutor

    init() {
        let q = DispatchSerialQueue(label: "piki.probe.capture")
        self.queue = q
        self.unownedExecutor = q.asUnownedSerialExecutor()
    }

    struct FixtureResult: Sendable {
        var captures: [JSONValue] = []
        var determinism: JSONValue = .null
    }

    func captureSeries(outputDir: URL, configuration: ProbeCaptureConfiguration, output: AVCapturePhotoOutput) async -> FixtureResult {
        var result = FixtureResult()

        let session = AVCaptureSession()
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back
        ).devices.first else {
            result.determinism = .dict(["error": "no wide camera"])
            return result
        }

        guard let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else {
            result.determinism = .dict(["error": "input failed"])
            return result
        }

        session.beginConfiguration()
        session.addInput(input)
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        session.commitConfiguration()

        let determinism = Self.configureDeterminism(session: session, device: device, output: output)
        result.determinism = determinism
        if !session.isRunning {
            session.startRunning()
        }

        guard let rawFormat = output.availableRawPhotoPixelFormatTypes
            .first(where: AVCapturePhotoOutput.isBayerRAWPixelFormat) else {
            result.determinism = .dict(["error": "no bayer format after attach"])
            session.stopRunning()
            return result
        }

        let format = device.activeFormat
        var ladders: [Double] = []
        let minISO = Double(format.minISO)
        let maxISO = Double(format.maxISO)
        for step in 0..<6 {
            ladders.append(minISO + (maxISO - minISO) * Double(step) / 5)
        }
        var durations: [Double] = []
        let minDuration = format.minExposureDuration.seconds
        let maxDuration = min(format.maxExposureDuration.seconds, 1.0 / 30)
        for step in 0..<4 {
            let d = minDuration * pow(maxDuration / minDuration, Double(step) / 3)
            durations.append(d)
        }

        var index = 0
        for iso in ladders {
            for duration in durations {
                index += 1
                let name = "flat_iso\(Int(iso))_exp\(Int(duration * 1_000_000))"
                let outcome = await captureOnce(
                    session: session, device: device, output: output,
                    rawFormat: rawFormat, iso: iso, duration: duration, flash: false
                )
                if outcome.success, let bytes = outcome.fileData {
                    try? bytes.write(to: outputDir.appendingPathComponent("\(name).dng"), options: [.atomic])
                }
                result.captures.append(.dict([
                    "name": name,
                    "iso": iso,
                    "duration": duration,
                    "success": outcome.success,
                    "error": outcome.error,
                    "isRaw": outcome.isRawPhoto,
                    "pixelFormat": outcome.pixelFormat,
                    "rawDims": "\(outcome.rawWidth)x\(outcome.rawHeight)",
                    "fileBytes": outcome.fileBytes,
                ]))
            }
        }

        let rich = await captureOnce(
            session: session, device: device, output: output,
            rawFormat: rawFormat, iso: nil, duration: nil, flash: false
        )
        if rich.success, let bytes = rich.fileData {
            try? bytes.write(to: outputDir.appendingPathComponent("fixture-bayer-rich.dng"), options: [.atomic])
            result.captures.append(.dict([
                "name": "fixture-bayer-rich", "success": rich.success,
                "rawDims": "\(rich.rawWidth)x\(rich.rawHeight)", "fileBytes": rich.fileBytes,
            ]))
        }

        if device.hasFlash, output.supportedFlashModes.contains(.on) {
            let flash = await captureOnce(
                session: session, device: device, output: output,
                rawFormat: rawFormat, iso: nil, duration: nil, flash: true
            )
            result.captures.append(.dict([
                "name": "flash-raw-probe", "success": flash.success, "error": flash.error,
                "flashEnabled": flash.flashEnabled, "fileBytes": flash.fileBytes,
                "isRaw": flash.isRawPhoto, "pixelFormat": flash.pixelFormat,
            ]))
        }

        session.stopRunning()
        return result
    }

    private func captureOnce(
        session: AVCaptureSession, device: AVCaptureDevice, output: AVCapturePhotoOutput,
        rawFormat: OSType, iso: Double?, duration: Double?, flash: Bool
    ) async -> CaptureOutcome {
        if iso != nil || duration != nil {
            let exposureEx = PIKExceptionCatcher.catchException {
                try? device.lockForConfiguration()
                device.setExposureModeCustom(
                    duration: duration.map { CMTime(seconds: $0, preferredTimescale: 1_000_000) }
                        ?? AVCaptureDevice.currentExposureDuration,
                    iso: iso.map { Float($0) } ?? AVCaptureDevice.currentISO,
                    completionHandler: { _ in }
                )
                device.unlockForConfiguration()
            }
            if let exposureEx {
                return CaptureOutcome(success: false, error: "exposure rejected: \(exposureEx.name)")
            }
        }

        let settings = AVCapturePhotoSettings(rawPixelFormatType: rawFormat)
        settings.photoQualityPrioritization = .speed
        settings.maxPhotoDimensions = output.maxPhotoDimensions
        settings.flashMode = flash ? .on : .off

        let delegate = PhotoDelegateBox()
        return await withCheckedContinuation { (continuation: CheckedContinuation<CaptureOutcome, Never>) in
            delegate.resume(with: continuation)
            output.capturePhoto(with: settings, delegate: delegate)
        }
    }

    private static func configureDeterminism(session: AVCaptureSession, device: AVCaptureDevice, output: AVCapturePhotoOutput) -> JSONValue {
        session.automaticallyConfiguresCaptureDeviceForWideColor = false
        try? device.lockForConfiguration()
        if device.isGeometricDistortionCorrectionSupported {
            device.isGeometricDistortionCorrectionEnabled = false
        }
        let modeEx = PIKExceptionCatcher.catchException { AVCaptureDevice.centerStageControlMode = .app }
        if modeEx == nil {
            PIKExceptionCatcher.catchException { AVCaptureDevice.isCenterStageEnabled = false }
        }
        if device.activeFormat.isVideoHDRSupported {
            device.automaticallyAdjustsVideoHDREnabled = false
            device.isVideoHDREnabled = false
        }
        if device.isLowLightBoostSupported {
            device.automaticallyEnablesLowLightBoostWhenAvailable = false
        }
        device.activeColorSpace = .P3_D65
        device.videoZoomFactor = 1.0
        device.unlockForConfiguration()

        let dims = device.activeFormat.supportedMaxPhotoDimensions
            .max { $0.width * $0.height < $1.width * $1.height }
        if let dims {
            output.maxPhotoDimensions = dims
        }

        let wideColorReadback = session.automaticallyConfiguresCaptureDeviceForWideColor
        var determinism: [String: JSONValue] = [:]
        determinism["wideColorAutoConfig"] = .bool(wideColorReadback)
        determinism["activeColorSpace"] = .string("\(device.activeColorSpace.rawValue)")
        determinism["gdcEnabled"] = .bool(device.isGeometricDistortionCorrectionEnabled)
        determinism["centerStageControlMode"] = .string("\(AVCaptureDevice.centerStageControlMode.rawValue)")
        determinism["centerStageModeSetException"] = .string(modeEx.map { "\($0.name)" } ?? "")
        determinism["centerStageEnabled"] = .bool(AVCaptureDevice.isCenterStageEnabled)
        determinism["videoHDR"] = .bool(device.isVideoHDREnabled)
        determinism["lowLightBoost"] = .bool(device.automaticallyEnablesLowLightBoostWhenAvailable)
        determinism["zoomFactor"] = .string("\(device.videoZoomFactor)")
        determinism["maxPhotoDimensions"] = .string("\(output.maxPhotoDimensions.width)x\(output.maxPhotoDimensions.height)")
        return .dict(determinism)
    }
}

struct ProbeCaptureConfiguration: Sendable {
    struct Ladders: Sendable {
        var isos: [Double] = [32, 100, 200, 400, 800, 1600]
        var durations: [Double] = [1.0 / 240, 1.0 / 120, 1.0 / 60, 1.0 / 30]
    }
    var ladders = Ladders()
}
