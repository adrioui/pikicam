import AVFoundation
import CoreImage
import Metal
import Foundation

actor AVScanClient: ScanClient {
    private let queue: DispatchSerialQueue
    nonisolated let unownedExecutor: UnownedSerialExecutor

    private var session: AVCaptureSession?
    private var output: AVCaptureVideoDataOutput?
    private var config: ScanConfig?
    private var startedAt: Date?
    private var frameCount = 0
    private var droppedFrames = 0
    private var lastFrameTime: CMTime = .invalid
    private var advanceX = 0
    private var texture: MTLTexture?
    private var assemblyFailures = 0
    private let device = MTLCreateSystemDefaultDevice()
    private let ciContext = CIContext(options: [.cacheIntermediates: false])
    private var continuation: AsyncStream<ScanState>.Continuation?
    private var lastResult: ScanResult?

    nonisolated var states: AsyncStream<ScanState> {
        AsyncStream { continuation in
            Task { await self.register(continuation) }
        }
    }

    private func register(_ continuation: AsyncStream<ScanState>.Continuation) {
        self.continuation = continuation
        continuation.yield(.idle)
    }

    init() {
        let q = DispatchSerialQueue(label: "piki.pikicam.scan")
        self.queue = q
        self.unownedExecutor = q.asUnownedSerialExecutor()
    }

    func start(_ config: ScanConfig, settings: CameraSettings) throws(ScanError) {
        guard let device else {
            throw .gpuFailed(code: -1)
        }
        self.config = config
        startedAt = Date()
        frameCount = 0
        droppedFrames = 0
        advanceX = 0
        assemblyFailures = 0
        texture = try makeAssemblyTexture(device: device, config: config)
        try attachSession()
        continuation?.yield(.scanning(progress: 0, since: startedAt!))
    }

    private func makeAssemblyTexture(device: MTLDevice, config: ScanConfig) throws(ScanError) -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm, width: 1080, height: config.outputLength, mipmapped: false
        )
        descriptor.usage = [.renderTarget, .shaderRead]
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw .gpuFailed(code: -2)
        }
        return texture
    }

    private func attachSession() throws(ScanError) {
        let session = AVCaptureSession()
        session.sessionPreset = .hd1920x1080
        guard
            let camera = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back
            ).devices.first,
            let input = try? AVCaptureDeviceInput(device: camera),
            session.canAddInput(input)
        else {
            throw .framesStalled
        }
        session.addInput(input)
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = false
        videoOutput.setSampleBufferDelegate(self.forwarder, queue: self.queue)
        guard session.canAddOutput(videoOutput) else {
            throw .framesStalled
        }
        session.addOutput(videoOutput)
        output = videoOutput
        session.startRunning()
        self.session = session
    }

    private var forwarder: ScanForwarder {
        ScanForwarder.shared(for: self)
    }

    func ingest(_ sampleBuffer: CMSampleBuffer) {
        guard let config, let texture, startedAt != nil else { return }
        trackTiming(sampleBuffer, config: config)
        appendColumn(sampleBuffer, config: config, texture: texture)
        frameCount += 1
        advanceX += config.slitWidth
        if advanceX >= 1080 {
            advanceX = 1080
        }
        let progress = Double(advanceX) / 1080.0
        continuation?.yield(.scanning(progress: progress, since: startedAt!))
    }

    private func trackTiming(_ sampleBuffer: CMSampleBuffer, config: ScanConfig) {
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if lastFrameTime.isValid {
            let gap = CMTimeSubtract(timestamp, lastFrameTime).seconds
            if gap > 3.0 / config.frameRate {
                droppedFrames += 1
                if Double(droppedFrames) * 100.0 / Double(max(frameCount, 1)) > 1.0 {
                    continuation?.yield(.failed(.tooManyDrops(droppedFrames)))
                }
            }
        }
        lastFrameTime = timestamp
    }

    private func appendColumn(_ sampleBuffer: CMSampleBuffer, config: ScanConfig, texture: MTLTexture) {

        guard let commandQueue = device?.makeCommandQueue(),
            let commandBuffer = commandQueue.makeCommandBuffer()
        else {
            assemblyFailures += 1
            if assemblyFailures > 1 {
                continuation?.yield(.failed(.gpuFailed(code: -3)))
            }
            return
        }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            droppedFrames += 1
            return
        }
        let slitWidth = config.slitWidth
        let sourceX = 960 - slitWidth / 2
        let ci = CIImage(cvPixelBuffer: pixelBuffer)
        let column = ci.cropped(to: CGRect(x: sourceX, y: 0, width: slitWidth, height: 1080))
            .transformed(by: CGAffineTransform(scaleX: 1, y: CGFloat(config.outputLength) / 1080))
        ciContext.render(
            column, to: texture, commandBuffer: commandBuffer,
            bounds: column.extent, colorSpace: CGColorSpace(name: CGColorSpace.displayP3)!
        )
        commandBuffer.commit()
    }

    func noteDrop() {
        droppedFrames += 1
    }

    func stop() throws(ScanError) -> ScanResult {
        guard let config else {
            throw .framesStalled
        }
        session?.stopRunning()
        session = nil
        var png = Data()
        if let texture {
            png = Self.textureBytes(texture)
        }
        let duration = startedAt.map { Date().timeIntervalSince($0) } ?? 0
        let result = ScanResult(
            id: CaptureID(),
            assemblyBytes: png,
            width: 1080,
            height: config.outputLength,
            config: config,
            frameCount: frameCount,
            droppedFrames: droppedFrames,
            duration: duration,
            isPartial: advanceX < 1080
        )
        lastResult = result
        continuation?.yield(.idle)
        return result
    }

    nonisolated static func textureBytes(_ texture: MTLTexture) -> Data {
        let bytesPerRow = texture.width * 4
        var data = Data(count: bytesPerRow * texture.height)
        data.withUnsafeMutableBytes { raw in
            let region = MTLRegion(
                origin: MTLOrigin(x: 0, y: 0, z: 0),
                size: MTLSize(width: texture.width, height: texture.height, depth: 1)
            )
            texture.getBytes(raw.baseAddress!, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        }
        return data
    }
}

final class ScanForwarder: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private weak var client: AVScanClient?
    private nonisolated(unsafe) static var instances: [ObjectIdentifier: ScanForwarder] = [:]
    private static let lock = NSLock()

    static func shared(for client: AVScanClient) -> ScanForwarder {
        lock.lock()
        defer { lock.unlock() }
        let key = ObjectIdentifier(client)
        if let existing = instances[key] { return existing }
        let forwarder = ScanForwarder(client: client)
        instances[key] = forwarder
        return forwarder
    }

    private init(client: AVScanClient) {
        self.client = client
    }

    func captureOutput(
        _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection
    ) {
        guard let client else { return }
        nonisolated(unsafe) let sending = sampleBuffer
        Task { await client.ingest(sending) }
    }

    func captureOutput(
        _ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection
    ) {
        guard let client else { return }
        Task { await client.noteDrop() }
    }
}
