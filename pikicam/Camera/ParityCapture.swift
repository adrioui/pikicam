@preconcurrency import AVFoundation
import Foundation

enum ParityCapture {
    @MainActor
    static func run() async {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let engine = CameraEngine()
        engine.isMonoOn = false
        await engine.start()
        for _ in 0..<40 where !engine.isRunning {
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
        WalkMark.mark(engine.isRunning ? "parity-session-ready" : "parity-session-never-ran")
        guard engine.isRunning else {
            WalkMark.mark("parity-end")
            return
        }
        WalkMark.mark("parity-begin")

        if let still = await engine.capturePhoto() {
            try? still.data.write(to: docs.appendingPathComponent("parity-still.dng"))
            WalkMark.mark("parity-still-taken")
        }

        engine.mode = .video
        await engine.startRecording()
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        await engine.stopRecording()

        let source = docs.appendingPathComponent("last-source-clip.mov")
        let destination = docs.appendingPathComponent("parity-video.mov")
        for _ in 0..<20 where !FileManager.default.fileExists(atPath: source.path) {
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        try? FileManager.default.removeItem(at: destination)
        if FileManager.default.fileExists(atPath: source.path) {
            try? FileManager.default.copyItem(at: source, to: destination)
            WalkMark.mark("parity-video-taken")
        }
        WalkMark.mark("parity-end")
    }
}
