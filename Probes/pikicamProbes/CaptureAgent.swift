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

    func captureSeries(
        outputDir: URL, configuration: ProbeCaptureConfiguration, output: AVCapturePhotoOutput
    ) async -> FixtureResult {
        var result = FixtureResult()

        guard let attached = Self.attachedWideSession(output: output) else {
            result.determinism = .dict(["error": "session attach failed"])
            return result
        }
        result.determinism = Self.configureDeterminism(
            session: attached.session, device: attached.device, output: output
        )
        if !attached.session.isRunning {
            attached.session.startRunning()
        }

        guard
            let rawFormat = output.availableRawPhotoPixelFormatTypes
                .first(where: AVCapturePhotoOutput.isBayerRAWPixelFormat)
        else {
            result.determinism = .dict(["error": "no bayer format after attach"])
            attached.session.stopRunning()
            return result
        }

        let context = CaptureContext(
            session: attached.session, device: attached.device, output: output, rawFormat: rawFormat
        )
        await captureFlatLadder(context: context, outputDir: outputDir, into: &result)
        await captureRichFrame(context: context, outputDir: outputDir, into: &result)
        await captureFlashProbe(context: context, into: &result)

        attached.session.stopRunning()
        return result
    }

    private static func attachedWideSession(
        output: AVCapturePhotoOutput
    )
        -> (session: AVCaptureSession, device: AVCaptureDevice)?
    {
        let session = AVCaptureSession()
        session.sessionPreset = .photo
        guard
            let device = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back
            ).devices.first
        else {
            return nil
        }
        guard let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else {
            return nil
        }
        session.beginConfiguration()
        session.addInput(input)
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        session.commitConfiguration()
        return (session, device)
    }

    private func captureFlatLadder(context: CaptureContext, outputDir: URL, into result: inout FixtureResult) async {
        let format = context.device.activeFormat
        let ladders = Self.isoLadder(format: format)
        let durations = Self.durationLadder(format: format)
        for iso in ladders {
            for duration in durations {
                let name = "flat_iso\(Int(iso))_exp\(Int(duration * 1_000_000))"
                let outcome = await captureOnce(
                    context: context, iso: iso, duration: duration, flash: false
                )
                if outcome.success, let bytes = outcome.fileData {
                    try? bytes.write(to: outputDir.appendingPathComponent("\(name).dng"), options: [.atomic])
                }
                result.captures.append(
                    .dict([
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
    }

    private func captureRichFrame(context: CaptureContext, outputDir: URL, into result: inout FixtureResult) async {
        let rich = await captureOnce(context: context, iso: nil, duration: nil, flash: false)
        if rich.success, let bytes = rich.fileData {
            try? bytes.write(to: outputDir.appendingPathComponent("fixture-bayer-rich.dng"), options: [.atomic])
            result.captures.append(
                .dict([
                    "name": "fixture-bayer-rich", "success": rich.success,
                    "rawDims": "\(rich.rawWidth)x\(rich.rawHeight)", "fileBytes": rich.fileBytes,
                ]))
        }
    }

    private func captureFlashProbe(context: CaptureContext, into result: inout FixtureResult) async {
        guard context.device.hasFlash, context.output.supportedFlashModes.contains(.on) else { return }
        let flash = await captureOnce(context: context, iso: nil, duration: nil, flash: true)
        result.captures.append(
            .dict([
                "name": "flash-raw-probe", "success": flash.success, "error": flash.error,
                "flashEnabled": flash.flashEnabled, "fileBytes": flash.fileBytes,
                "isRaw": flash.isRawPhoto, "pixelFormat": flash.pixelFormat,
            ]))
    }

    private static func isoLadder(format: AVCaptureDevice.Format) -> [Double] {
        let minISO = Double(format.minISO)
        let maxISO = Double(format.maxISO)
        return (0..<6).map { minISO + (maxISO - minISO) * Double($0) / 5 }
    }

    private static func durationLadder(format: AVCaptureDevice.Format) -> [Double] {
        let minDuration = format.minExposureDuration.seconds
        let maxDuration = min(format.maxExposureDuration.seconds, 1.0 / 30)
        return (0..<4).map { minDuration * pow(maxDuration / minDuration, Double($0) / 3) }
    }

    struct CaptureContext: @unchecked Sendable {
        let session: AVCaptureSession
        let device: AVCaptureDevice
        let output: AVCapturePhotoOutput
        let rawFormat: OSType
    }

    private func captureOnce(
        context: CaptureContext, iso: Double?, duration: Double?, flash: Bool
    ) async -> CaptureOutcome {
        if iso != nil || duration != nil {
            let exposureEx = PIKExceptionCatcher.catchException {
                try? context.device.lockForConfiguration()
                context.device.setExposureModeCustom(
                    duration: duration.map { CMTime(seconds: $0, preferredTimescale: 1_000_000) }
                        ?? AVCaptureDevice.currentExposureDuration,
                    iso: iso.map { Float($0) } ?? AVCaptureDevice.currentISO,
                    completionHandler: { _ in }
                )
                context.device.unlockForConfiguration()
            }
            if let exposureEx {
                return CaptureOutcome(success: false, error: "exposure rejected: \(exposureEx.name)")
            }
        }

        let settings = AVCapturePhotoSettings(rawPixelFormatType: context.rawFormat)
        settings.photoQualityPrioritization = .speed
        settings.maxPhotoDimensions = context.output.maxPhotoDimensions
        settings.flashMode = flash ? .on : .off

        let delegate = PhotoDelegateBox()
        return await withCheckedContinuation { (continuation: CheckedContinuation<CaptureOutcome, Never>) in
            delegate.resume(with: continuation)
            context.output.capturePhoto(with: settings, delegate: delegate)
        }
    }

    private static func configureDeterminism(
        session: AVCaptureSession, device: AVCaptureDevice, output: AVCapturePhotoOutput
    ) -> JSONValue {
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
        determinism["maxPhotoDimensions"] = .string(
            "\(output.maxPhotoDimensions.width)x\(output.maxPhotoDimensions.height)")
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
