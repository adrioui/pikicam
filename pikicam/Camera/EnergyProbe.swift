import UIKit

@MainActor
final class EnergyProbe {
    struct Phase: Codable {
        let name: String
        let startPercent: Double
        let endPercent: Double
        let seconds: Double
    }

    static func run() async {
        UIDevice.current.isBatteryMonitoringEnabled = true
        guard UIDevice.current.batteryState != .unknown else {
            markError("battery level unavailable")
            return
        }
        let engine = CameraEngine()
        engine.isMonoOn = false
        await engine.start()
        for _ in 0..<40 where !engine.isRunning {
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
        guard engine.isRunning else {
            markError("camera never started")
            return
        }
        var phases: [Phase] = []
        phases.append(await idlePhase())
        phases.append(await burstPhase(engine: engine))
        phases.append(await recordPhase(engine: engine))
        persist(phases)
        WalkMark.mark("energy-probe-done")
    }

    private static func idlePhase() async -> Phase {
        let start = sample()
        let begin = Date()
        try? await Task.sleep(nanoseconds: 180_000_000_000)
        return phase("idle-preview-180s", from: start, since: begin)
    }

    private static func burstPhase(engine: CameraEngine) async -> Phase {
        let start = sample()
        let begin = Date()
        for index in 0..<20 {
            if let capture = await engine.capturePhoto() {
                await engine.saveToPhotos(capture)
            }
            WalkMark.mark("energy-burst-\(index)")
        }
        return phase("burst-20-captures", from: start, since: begin)
    }

    private static func recordPhase(engine: CameraEngine) async -> Phase {
        let start = sample()
        let begin = Date()
        engine.mode = .video
        await engine.startRecording()
        try? await Task.sleep(nanoseconds: 60_000_000_000)
        await engine.stopRecording()
        return phase("record-60s", from: start, since: begin)
    }

    private static func persist(_ phases: [Phase]) {
        let payload: [String: Any] = ["provenance": "agent-measured, USB-connected", "phases": phases]
        if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]) {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            try? data.write(to: docs.appendingPathComponent("energy.json"), options: [.atomic])
        }
        WalkMark.mark("energy-probe-done")
    }

    private static func phase(_ name: String, from start: Double, since begin: Date) -> Phase {
        Phase(name: name, startPercent: start, endPercent: sample(), seconds: Date().timeIntervalSince(begin))
    }

    private static func sample() -> Double {
        Double(UIDevice.current.batteryLevel) * 100
    }

    private static func markError(_ reason: String) {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let payload = ["error": reason]
        if let data = try? JSONSerialization.data(withJSONObject: payload) {
            try? data.write(to: docs.appendingPathComponent("energy.json"), options: [.atomic])
        }
    }
}
