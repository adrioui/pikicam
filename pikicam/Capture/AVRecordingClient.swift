import AVFoundation
import CoreImage
import Foundation

actor AVRecordingClient: RecordingClient {
    private let queue: DispatchSerialQueue
    nonisolated let unownedExecutor: UnownedSerialExecutor

    private var session: AVCaptureSession?
    private var videoInput: AVCaptureVideoDataOutput?
    private var audioInput: AVCaptureAudioDataOutput?
    var writers: WriterPair?
    var untouchedInput: AVAssetWriterInput?
    var renditionInput: AVAssetWriterInput?
    var untouchedAdapter: AVAssetWriterInputPixelBufferAdaptor?
    var renditionAdapter: AVAssetWriterInputPixelBufferAdaptor?
    var lookKernel: CIKernel?
    var lookLook = LookParameters()
    var lookMono: MonoState?
    var startedAt: Date?
    var droppedFrames = 0
    private var events: [ProvenanceEvent] = []
    var frameIndex: Int64 = 0
    private var clipID = ClipID()
    private var originalURL: URL?
    private var renditionURL: URL?
    let context = CIContext(options: [.cacheIntermediates: false, .memoryTarget: 1024])
    private var continuation: AsyncStream<RecordingState>.Continuation?

    nonisolated var states: AsyncStream<RecordingState> {
        AsyncStream { continuation in
            Task { await self.register(continuation) }
        }
    }

    private func register(_ continuation: AsyncStream<RecordingState>.Continuation) {
        self.continuation = continuation
        continuation.yield(.idle)
    }

    init() {
        let q = DispatchSerialQueue(label: "piki.pikicam.record")
        self.queue = q
        self.unownedExecutor = q.asUnownedSerialExecutor()
    }

    func start(
        _ intent: RecordingIntent, settings: CameraSettings, look: LookParameters, mono: MonoState?
    ) throws(RecordingError) {
        guard writers == nil else {
            throw .writerFailed(code: -1)
        }
        lookLook = look
        lookMono = mono
        do {
            lookKernel = try PikicamLook.kernel()
        } catch {
            throw .writerFailed(code: -2)
        }

        clipID = ClipID()
        startedAt = Date()
        droppedFrames = 0
        events = [ProvenanceEvent(timestamp: 0, kind: "start", detail: intent.mode.rawValue)]
        frameIndex = 0

        let docs = FileManager.default.temporaryDirectory
        originalURL = docs.appendingPathComponent("piki-original-\(clipID.id.uuidString).mov")
        renditionURL = docs.appendingPathComponent("piki-rendition-\(clipID.id.uuidString).mov")

        writers = try buildWriters(dimensions: Self.dimensions(for: intent.mode))
        attachVideoOutput(dimensions: Self.dimensions(for: intent.mode))
        continuation?.yield(.recording(since: startedAt!))
    }

    private func writerSettings(dimensions: CGSize) -> ([String: Any], [String: Any]) {
        let untouchedSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: dimensions.width,
            AVVideoHeightKey: dimensions.height,
        ]
        let renditionSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: dimensions.width,
            AVVideoHeightKey: dimensions.height,
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_P3_D65,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_2100_HLG,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_2020,
            ],
        ]
        return (untouchedSettings, renditionSettings)
    }

    private func buildWriters(dimensions: CGSize) throws(RecordingError) -> WriterPair {
        let (untouchedSettings, renditionSettings) = writerSettings(dimensions: dimensions)
        let docs = FileManager.default.temporaryDirectory
        originalURL = docs.appendingPathComponent("piki-original-\(clipID.id.uuidString).mov")
        renditionURL = docs.appendingPathComponent("piki-rendition-\(clipID.id.uuidString).mov")

        guard
            let untouched = try? AVAssetWriter(outputURL: originalURL!, fileType: .mov),
            let rendition = try? AVAssetWriter(outputURL: renditionURL!, fileType: .mov)
        else {
            throw .writerFailed(code: -3)
        }

        untouchedInput = AVAssetWriterInput(mediaType: .video, outputSettings: untouchedSettings)
        renditionInput = AVAssetWriterInput(mediaType: .video, outputSettings: renditionSettings)
        untouchedInput?.expectsMediaDataInRealTime = true
        renditionInput?.expectsMediaDataInRealTime = true
        untouchedAdapter = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: untouchedInput!, sourcePixelBufferAttributes: Self.bufferAttributes
        )
        renditionAdapter = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: renditionInput!, sourcePixelBufferAttributes: Self.bufferAttributes
        )
        guard
            let untouchedInput, let renditionInput,
            untouched.canAdd(untouchedInput), rendition.canAdd(renditionInput)
        else {
            throw .writerFailed(code: -4)
        }
        untouched.add(untouchedInput)
        rendition.add(renditionInput)
        guard untouched.startWriting(), rendition.startWriting() else {
            throw .writerFailed(code: Int((untouched.error as NSError?)?.code ?? -5))
        }
        untouched.startSession(atSourceTime: .zero)
        rendition.startSession(atSourceTime: .zero)
        return WriterPair(untouched: untouched, rendition: rendition)
    }

    private func attachVideoOutput(dimensions: CGSize) {
        let session = AVCaptureSession()
        session.sessionPreset = .inputPriority
        guard
            let device = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back
            ).devices.first,
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            continuation?.yield(.failed(.formatUnavailable(reason: "no camera")))
            return
        }
        session.addInput(input)
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = Self.bufferAttributes
        output.alwaysDiscardsLateVideoFrames = false
        output.setSampleBufferDelegate(self.sampleDelegate, queue: self.queue)
        guard session.canAddOutput(output) else {
            continuation?.yield(.failed(.formatUnavailable(reason: "output rejected")))
            return
        }
        session.addOutput(output)
        videoInput = output
        session.startRunning()
        self.session = session
    }

    private var sampleDelegate: SampleBufferForwarder {
        SampleBufferForwarder.shared(for: self)
    }

    nonisolated static var bufferAttributes: [String: Any] {
        [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: 1920,
            kCVPixelBufferHeightKey as String: 1080,
        ]
    }

    nonisolated static func dimensions(for mode: VideoMode) -> CGSize {
        switch mode {
        case .res1080p30, .res1080p60, .proRes422HQ: return CGSize(width: 1920, height: 1080)
        case .res2160p30: return CGSize(width: 3840, height: 2160)
        }
    }

    func setMono(_ mono: MonoState?) {
        lookMono = mono
        events.append(ProvenanceEvent(timestamp: elapsed(), kind: "mono", detail: mono?.preset.rawValue ?? "off"))
    }

    func setZoom(_ factor: CGFloat) {
        events.append(ProvenanceEvent(timestamp: elapsed(), kind: "zoom", detail: "\(factor)"))
        guard let device = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back
        ).devices.first else { return }
        try? device.lockForConfiguration()
        device.videoZoomFactor = max(1, min(factor, device.maxAvailableVideoZoomFactor))
        device.unlockForConfiguration()
    }

    private func elapsed() -> Double {
        guard let startedAt else { return 0 }
        return Date().timeIntervalSince(startedAt)
    }

    private func finalize(_ pair: WriterPair) -> Int {
        let completionBox = FinishBox()
        let semaphore = DispatchSemaphore(value: 0)
        pair.untouched.finishWriting {
            completionBox.untouchedFailed = pair.untouched.status != .completed
            completionBox.untouchedCode = Int((pair.untouched.error as NSError?)?.code ?? -6)
            completionBox.count += 1
            if completionBox.count == 2 { semaphore.signal() }
        }
        pair.rendition.finishWriting {
            completionBox.renditionFailed = pair.rendition.status != .completed
            completionBox.renditionCode = Int((pair.rendition.error as NSError?)?.code ?? -7)
            completionBox.count += 1
            if completionBox.count == 2 { semaphore.signal() }
        }
        semaphore.wait()
        if completionBox.untouchedFailed { return completionBox.untouchedCode }
        if completionBox.renditionFailed { return completionBox.renditionCode }
        return 0
    }

    func stop() throws(RecordingError) -> VideoClip {
        guard let writers else {
            throw .writerFailed(code: -1)
        }
        untouchedInput?.markAsFinished()
        renditionInput?.markAsFinished()
        let pair = WriterPair(untouched: writers.untouched, rendition: writers.rendition)
        let failedCode = finalize(pair)
        session?.stopRunning()
        session = nil
        self.writers = nil
        return try finishClip(failedCode: failedCode)

    }

    private func finishClip(failedCode: Int) throws(RecordingError) -> VideoClip {
        if failedCode != 0 {
            try? FileManager.default.removeItem(at: originalURL!)
            try? FileManager.default.removeItem(at: renditionURL!)
            continuation?.yield(.failed(.writerFailed(code: failedCode)))
            throw .writerFailed(code: failedCode)
        }
        let duration = elapsed()
        continuation?.yield(.idle)
        return VideoClip(
            id: clipID,
            originalURL: originalURL!,
            renditionURL: renditionURL!,
            mode: .res1080p30,
            duration: duration,
            droppedFrames: droppedFrames,
            provenanceEvents: events
        )
    }
}
