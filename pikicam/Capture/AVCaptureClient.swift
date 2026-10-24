@preconcurrency import AVFoundation
import Foundation

actor AVCaptureClient: CaptureClient {
    private let queue: DispatchSerialQueue
    nonisolated let unownedExecutor: UnownedSerialExecutor

    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var device: AVCaptureDevice?
    private var determinism = DeviceDeterminism(
        geometricDistortionCorrection: .notSupported,
        centerStage: .notSupported,
        videoHDR: .notSupported,
        lowLightBoost: .notSupported,
        colorSpace: ""
    )
    private var stateContinuation: AsyncStream<SessionState>.Continuation?
    private var readingsContinuation: AsyncStream<DeviceReadings>.Continuation?

    let preview: PreviewSource

    nonisolated var sessionStates: AsyncStream<SessionState> {
        AsyncStream { continuation in
            Task { await self.register(stateContinuation: continuation) }
        }
    }

    nonisolated var readings: AsyncStream<DeviceReadings> {
        AsyncStream { continuation in
            Task { await self.register(readingsContinuation: continuation) }
        }
    }

    nonisolated var meters: AsyncStream<MeterReading> {
        AsyncStream { _ in }
    }

    init() {
        let q = DispatchSerialQueue(label: "piki.pikicam.capture")
        self.queue = q
        self.unownedExecutor = q.asUnownedSerialExecutor()
        self.preview = PreviewSource(provider: { [session] in
            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspect
            return layer
        })
    }

    private func register(stateContinuation: AsyncStream<SessionState>.Continuation) {
        self.stateContinuation = stateContinuation
    }

    private func register(readingsContinuation: AsyncStream<DeviceReadings>.Continuation) {
        self.readingsContinuation = readingsContinuation
    }

    func start(lens: LensKind) throws(CaptureError) {
        guard let captureDevice = Self.discover(lens) else {
            throw .noBayerLens
        }
        session.sessionPreset = .photo
        session.beginConfiguration()
        guard let input = try? AVCaptureDeviceInput(device: captureDevice), session.canAddInput(input) else {
            session.commitConfiguration()
            throw .sessionStartFailed(code: -1)
        }
        session.addInput(input)
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        session.commitConfiguration()

        determinism = try DeviceConfiguration.apply(session: session, device: captureDevice, output: photoOutput)
        let dims = DeviceConfiguration.largestPhotoDimensions(captureDevice)
        photoOutput.maxPhotoDimensions = dims
        photoOutput.maxPhotoQualityPrioritization = .speed
        if photoOutput.isZeroShutterLagEnabled {
            do {
                try captureDevice.lockForConfiguration()
                captureDevice.unlockForConfiguration()
            } catch {
                throw .deviceLockFailed
            }
        }
        photoOutput.isAutoDeferredPhotoDeliveryEnabled = false

        device = captureDevice
        if !session.isRunning {
            session.startRunning()
        }
        stateContinuation?.yield(.running(lens))
    }

    func stop() {
        if session.isRunning {
            session.stopRunning()
        }
        stateContinuation?.yield(.idle)
    }

    var capabilities: DeviceCapabilities {
        get async {
            await capabilitiesValue()
        }
    }

    private func capabilitiesValue() async -> DeviceCapabilities {
        guard let device else {
            return DeviceCapabilities(
                lenses: [], exposureLimits: [:],
                whiteBalanceLimits: WhiteBalanceLimits(temperature: 2000...10000, tint: -150...150, maxGain: 8),
                flashSupported: false, focusLockSupported: false,
                rawDimensions: CGSize.zero,
                bayerFormat: BayerFormat(osType: kCVPixelFormatType_14Bayer_RGGB)
            )
        }
        let format = device.activeFormat
        let limits = ExposureLimits(
            iso: Double(format.minISO)...Double(format.maxISO),
            exposureDuration: format.minExposureDuration.seconds...format.maxExposureDuration.seconds,
            bias: Double(device.minExposureTargetBias)...Double(device.maxExposureTargetBias)
        )
        let lenses = Self.availableLenses()
        return DeviceCapabilities(
            lenses: lenses,
            exposureLimits: Dictionary(uniqueKeysWithValues: lenses.map { ($0.kind, limits) }),
            whiteBalanceLimits: WhiteBalanceLimits(
                temperature: 2000...10000, tint: -150...150, maxGain: Double(device.maxWhiteBalanceGain)),
            flashSupported: device.hasFlash && photoOutput.supportedFlashModes.contains(.on),
            focusLockSupported: device.isLockingFocusWithCustomLensPositionSupported,
            rawDimensions: CGSize(width: CGFloat(dims.width), height: CGFloat(dims.height)),
            bayerFormat: DeviceConfiguration.bayerFormat(for: photoOutput)
                ?? BayerFormat(osType: kCVPixelFormatType_14Bayer_RGGB)
        )
    }

    private var dims: CMVideoDimensions {
        guard let device else { return CMVideoDimensions(width: 0, height: 0) }
        return DeviceConfiguration.largestPhotoDimensions(device)
    }

    func apply(_ settings: CameraSettings) {}

    func capture(_ request: CaptureRequest) async throws(CaptureError) -> RawCapture {
        guard let device else {
            throw .sessionStartFailed(code: -2)
        }
        guard let bayer = DeviceConfiguration.bayerFormat(for: photoOutput) else {
            throw .noBayerLens
        }
        if device.videoZoomFactor != 1.0 {
            throw .configurationRejected(determinism)
        }
        let settings = Self.makeSettings(format: bayer, output: photoOutput, flash: request.settings.light)
        let delegate = PhotoCaptureDelegateBox()
        let outcome: PhotoCaptureDelegateBox.Outcome = await withCheckedContinuation { continuation in
            delegate.hold(continuation)
            photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
        switch outcome {
        case .failure(let message):
            throw .unexpectedResolvedSettings(message)
        case .success(let photo):
            switch PhotoBoundary.validate(photo, requestedFormat: bayer) {
            case .success(let capture):
                return capture
            case .failure(let rejection):
                throw CaptureError(rejection)
            }
        }
    }

    nonisolated static func makeSettings(
        format: BayerFormat, output: AVCapturePhotoOutput, flash: LightMode
    ) -> AVCapturePhotoSettings {
        let settings = AVCapturePhotoSettings(rawPixelFormatType: format.osType)
        settings.photoQualityPrioritization = .speed
        settings.maxPhotoDimensions = output.maxPhotoDimensions
        settings.flashMode = flash == .flash ? .on : .off
        settings.metadata[kCGImagePropertyTIFFSoftware as String] = "pikicam"
        return settings
    }

    nonisolated private static func discover(_ lens: LensKind) -> AVCaptureDevice? {
        let type: AVCaptureDevice.DeviceType
        switch lens {
        case .ultraWide: type = .builtInUltraWideCamera
        case .wide: type = .builtInWideAngleCamera
        case .telephoto: type = .builtInTelephotoCamera
        }
        return AVCaptureDevice.DiscoverySession(deviceTypes: [type], mediaType: .video, position: .back).devices.first
    }

    nonisolated static func availableLenses() -> [Lens] {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInUltraWideCamera, .builtInWideAngleCamera, .builtInTelephotoCamera],
            mediaType: .video, position: .back
        )
        return discovery.devices.compactMap { device in
            let kind: LensKind
            switch device.deviceType {
            case .builtInUltraWideCamera: kind = .ultraWide
            case .builtInWideAngleCamera: kind = .wide
            case .builtInTelephotoCamera: kind = .telephoto
            default: return nil
            }
            let fov = Double(device.activeFormat.videoFieldOfView)
            let focal = Int((18 / 2 / tan(fov * Double.pi / 360)).rounded())
            return Lens(kind: kind, uniqueID: device.uniqueID, equivalentFocalLength: focal)
        }
    }
}
