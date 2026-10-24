import AVFoundation
import SwiftUI

@main
struct ProbeApp: App {
    @StateObject private var recorder = ProbeRecorder()

    var body: some Scene {
        WindowGroup {
            ProbeRootView(recorder: recorder)
        }
    }
}

struct ProbeRootView: View {
    @ObservedObject var recorder: ProbeRecorder
    @State private var running = false

    var body: some View {
        VStack(spacing: 12) {
            Text("PIKI PROBES")
            Text(running ? "RUNNING" : (recorder.lastRecord == "done" ? "DONE" : "IDLE"))
            Text(recorder.lastRecord)
            if recorder.lastRecord == "done" {
                Text("PROBES-DONE")
            }
        }
        .task {
            guard !running else { return }
            running = true
            await runAllProbes(recorder: recorder)
            recorder.record("done", "ok")
            running = false
        }
    }
}

@MainActor
func runAllProbes(recorder: ProbeRecorder) async {
    recorder.record("compileProbes", "ok", .dictionary(compileProbesPassed.mapValues(JSONValue.bool)))

    recorder.record("deviceDiscovery", "ok", CameraProbes.dumpDeviceCapabilities())
    recorder.record("videoFormats", "ok", VideoProbes.videoFormatsProbe())
    recorder.record("photoSettingsDetached", "ok", CameraProbes.photoSettingsProbe())

    let fixtureData = await runCIRAWProbes(recorder: recorder)
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let fixturesDir = docs.appendingPathComponent("fixtures")
    try? FileManager.default.createDirectory(at: fixturesDir, withIntermediateDirectories: true)

    let capturedDNG = await runCaptureProbes(
        recorder: recorder, fixturesDir: fixturesDir, fixtureData: fixtureData
    )
    await runPhotoKitProbes(recorder: recorder, fixtureData: fixtureData ?? capturedDNG)
    runTrapProbe(recorder: recorder, fixtureData: fixtureData ?? capturedDNG, docs: docs)
}

@MainActor
private func runCIRAWProbes(recorder: ProbeRecorder) async -> Data? {
    guard let fixtureData = CIRAWProbes.loadFixture() else {
        recorder.record("fixture", "error", .string("IMG_1361.DNG not in bundle"))
        return nil
    }
    recorder.record("cirawInitModern", "ok", CIRAWProbes.initProbe(data: fixtureData))
    recorder.record("cirawInitDeprecated", "ok", CIRAWProbes.deprecatedInitProbe(data: fixtureData))
    recorder.record("cirawControlsProRAW", "ok", CIRAWProbes.controlReadbackProbe(data: fixtureData))
    recorder.record("edrHeadroom", "ok", LinearRenderProbes.edrProbe(data: fixtureData))
    recorder.record("heif10", "ok", await LinearRenderProbes.heif10Probe(data: fixtureData))
    return fixtureData
}

@MainActor
private func runCaptureProbes(
    recorder: ProbeRecorder, fixturesDir: URL, fixtureData: Data?
) async -> Data? {
    guard await requestCamera() else {
        recorder.record("cameraPermission", "denied")
        return nil
    }
    recorder.record("cameraPermission", "ok")

    let agent = FixtureCaptureAgent()
    let configuration = ProbeCaptureConfiguration()
    let output = AVCapturePhotoOutput()
    let outcome = await agent.captureSeries(outputDir: fixturesDir, configuration: configuration, output: output)
    recorder.record(
        "captureSeries", "ok",
        .dict([
            "determinism": outcome.determinism,
            "captures": .array(outcome.captures),
        ]))
    recorder.record("photoOutputAttached", "ok", await attachedOutputProbe())

    let bayerURL = fixturesDir.appendingPathComponent("fixture-bayer-rich.dng")
    if let bayerData = try? Data(contentsOf: bayerURL) {
        recorder.record("cirawControlsBayer", "ok", CIRAWProbes.controlReadbackProbe(data: bayerData))
        recorder.record("edrHeadroomBayer", "ok", LinearRenderProbes.edrProbe(data: bayerData))
        return bayerData
    }
    recorder.record("cirawControlsBayer", "skipped", .string("no captured bayer fixture"))
    return nil
}

@MainActor
private func attachedOutputProbe() async -> JSONValue {
    await withCheckedContinuation { (continuation: CheckedContinuation<JSONValue, Never>) in
        DispatchQueue.global().async {
            continuation.resume(returning: CameraProbes.attachedOutputProbe())
        }
    }
}

@MainActor
private func runPhotoKitProbes(recorder: ProbeRecorder, fixtureData: Data?) async {
    guard await PhotoKitProbes.requestAuthorization() else {
        recorder.record("photoKitPermission", "denied")
        return
    }
    recorder.record("photoKitPermission", "ok")
    guard let dng = fixtureData, let heic = await PhotoKitProbes.makeSmallHEIC(from: dng) else {
        recorder.record("photoKitShapes", "skipped")
        return
    }
    let shapes = await PhotoKitProbes.probeShapes(dng: dng, heic: heic)
    let encoder = JSONEncoder()
    let shapesData = (try? encoder.encode(shapes)) ?? Data()
    let shapesJSON = (try? JSONDecoder().decode([JSONValue].self, from: shapesData)) ?? []
    recorder.record("photoKitShapes", "ok", .array(shapesJSON))
}

@MainActor
private func runTrapProbe(recorder: ProbeRecorder, fixtureData: Data?, docs: URL) {
    recorder.record("trap-probe", "crash-expected")
    let fallback = try? Data(contentsOf: docs.appendingPathComponent("fixtures/fixture-bayer-rich.dng"))
    if let dng = fixtureData ?? fallback {
        _ = LinearRenderProbes.trapProbe(data: dng)
        recorder.record("trapProbeSurvived", "ok", .bool(true))
    } else {
        recorder.record("trapProbeSurvived", "skipped", .string("no fixture"))
    }
}

@MainActor
func requestCamera() async -> Bool {
    let status = AVCaptureDevice.authorizationStatus(for: .video)
    if status == .authorized { return true }
    return await AVCaptureDevice.requestAccess(for: .video)
}
