import AVFoundation
import Foundation

final class WriterPair: @unchecked Sendable {
    let untouched: AVAssetWriter
    let rendition: AVAssetWriter

    init(untouched: AVAssetWriter, rendition: AVAssetWriter) {
        self.untouched = untouched
        self.rendition = rendition
    }
}

final class FinishBox: @unchecked Sendable {
    var count = 0
    var untouchedFailed = false
    var renditionFailed = false
    var untouchedCode = 0
    var renditionCode = 0
}

final class SampleBufferForwarder: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private weak var client: AVRecordingClient?
    private nonisolated(unsafe) static var instances: [ObjectIdentifier: SampleBufferForwarder] = [:]
    private static let lock = NSLock()

    static func shared(for client: AVRecordingClient) -> SampleBufferForwarder {
        lock.lock()
        defer { lock.unlock() }
        let key = ObjectIdentifier(client)
        if let existing = instances[key] { return existing }
        let forwarder = SampleBufferForwarder(client: client)
        instances[key] = forwarder
        return forwarder
    }

    private init(client: AVRecordingClient) {
        self.client = client
    }

    func captureOutput(
        _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection
    ) {
        guard let client else { return }
        let buffer = sampleBuffer
        nonisolated(unsafe) let sending = buffer
        Task { await client.ingest(sending) }
    }

    func captureOutput(
        _ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection
    ) {
        guard let client else { return }
        Task { await client.noteDrop() }
    }
}

extension AVRecordingClient {
    func noteDrop() {
        droppedFrames += 1
    }
}
