@preconcurrency import AVFoundation
import CoreImage
import OSLog
import UIKit

@MainActor
final class FrameTimeProbe: ObservableObject {
    private let core = FrameTimeCore()
    private var thermal: [String] = []

    func run(duration: Double) async {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent("frametime.json")
        try? Data().write(to: url)

        let session = AVCaptureSession()
        session.beginConfiguration()
        session.sessionPreset = .hd1920x1080
        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            try? JSONSerialization.data(withJSONObject: ["error": "no camera"]).write(to: url)
            return
        }
        session.addInput(input)
        lockDevice(device)
        session.addOutput(core.output)
        session.commitConfiguration()
        session.startRunning()

        let deadline = Date().addingTimeInterval(duration)
        while Date() < deadline {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            thermal.append(Self.label(ProcessInfo.processInfo.thermalState))
        }
        session.stopRunning()
        core.queue.sync {}
        persist(url: url, result: core.snapshot(), thermal: thermal)
    }

    private func lockDevice(_ device: AVCaptureDevice) {
        try? device.lockForConfiguration()
        device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
        device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
        device.unlockForConfiguration()
    }

    private static func label(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
    }

    private func persist(url: URL, result: FrameTimeCore.Snapshot, thermal: [String]) {
        let payload: [String: Any] = [
            "intervalsMs": result.intervals.map { ($0 * 1000 * 1000).rounded() / 1000 },
            "drops": result.drops,
            "thermal": thermal,
            "frameCount": result.intervals.count + result.drops,
        ]
        try? JSONSerialization.data(withJSONObject: payload).write(to: url)
    }
}

final class FrameTimeCore: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    struct Snapshot {
        let intervals: [Double]
        let drops: Int
    }

    let output = AVCaptureVideoDataOutput()
    let queue = DispatchQueue(label: "piki.pikicam.frametime", qos: .userInitiated)
    private let context = CIContext(options: [.cacheIntermediates: false])
    private var intervals: [Double] = []
    private var drops = 0
    private var lastPTS: CMTime = .invalid
    private var pool: CVPixelBufferPool?

    override init() {
        super.init()
        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: 1920,
            kCVPixelBufferHeightKey as String: 1080,
        ]
        output.videoSettings = attributes
        output.alwaysDiscardsLateVideoFrames = false
        output.setSampleBufferDelegate(self, queue: queue)
        var created: CVPixelBufferPool?
        CVPixelBufferPoolCreate(nil, nil, attributes as CFDictionary, &created)
        pool = created
    }

    func snapshot() -> Snapshot {
        queue.sync {
            Snapshot(intervals: intervals, drops: drops)
        }
    }

    func captureOutput(
        _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection
    ) {
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if lastPTS.isValid {
            let delta = CMTimeSubtract(pts, lastPTS).seconds
            if delta > 1.5 / 30.0 {
                drops += 1
            }
        }
        lastPTS = pts

        guard let source = CMSampleBufferGetImageBuffer(sampleBuffer), let pool else { return }
        var destination: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &destination)
        guard let destination else { return }
        let mono = Look.apply(to: CIImage(cvPixelBuffer: source), mono: true)
        let renderStart = CACurrentMediaTime()
        context.render(
            mono, to: destination, bounds: mono.extent,
            colorSpace: CGColorSpace(name: CGColorSpace.displayP3)!
        )
        intervals.append(CACurrentMediaTime() - renderStart)
    }

    func captureOutput(
        _ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection
    ) {
        drops += 1
    }
}
