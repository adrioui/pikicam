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
    recorder.record("videoFormats", "ok", CameraProbes.videoFormatsProbe())
    recorder.record("photoSettingsDetached", "ok", CameraProbes.photoSettingsProbe())

    let fixtureData = CIRAWProbes.loadFixture()
    if let fixtureData {
        recorder.record("cirawInitModern", "ok", CIRAWProbes.initProbe(data: fixtureData))
        recorder.record("cirawInitDeprecated", "ok", CIRAWProbes.deprecatedInitProbe(data: fixtureData))
        recorder.record("cirawControlsProRAW", "ok", CIRAWProbes.controlReadbackProbe(data: fixtureData))
        recorder.record("edrHeadroom", "ok", CIRAWProbes.edrProbe(data: fixtureData))
        let heic = await CIRAWProbes.heif10Probe(data: fixtureData)
        recorder.record("heif10", "ok", heic)
    } else {
        recorder.record("fixture", "error", .string("IMG_1361.DNG not in bundle"))
    }

    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let fixturesDir = docs.appendingPathComponent("fixtures")
    try? FileManager.default.createDirectory(at: fixturesDir, withIntermediateDirectories: true)

    let cameraGranted = await requestCamera()
    recorder.record("cameraPermission", cameraGranted ? "ok" : "denied")
    if cameraGranted {
        let agent = FixtureCaptureAgent()
        let configuration = ProbeCaptureConfiguration()
        let output = AVCapturePhotoOutput()
        let outcome = await agent.captureSeries(outputDir: fixturesDir, configuration: configuration, output: output)
        recorder.record("captureSeries", "ok", .dict([
            "determinism": outcome.determinism,
            "captures": .array(outcome.captures),
        ]))

        if let outputProbeData = await withCheckedContinuation({ (cont: CheckedContinuation<JSONValue?, Never>) in
            DispatchQueue.global().async {
                let session = AVCaptureSession()
                session.sessionPreset = .photo
                guard let device = AVCaptureDevice.DiscoverySession(
                    deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back
                ).devices.first else {
                    cont.resume(returning: .dict(["error": "no device"]))
                    return
                }
                guard let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else {
                    cont.resume(returning: .dict(["error": "input failed"]))
                    return
                }
                session.addInput(input)
                let output = AVCapturePhotoOutput()
                guard session.canAddOutput(output) else {
                    cont.resume(returning: .dict(["error": "output failed"]))
                    return
                }
                session.addOutput(output)
                session.startRunning()
                let data = CameraProbes.outputProbe(output: output, device: device)
                session.stopRunning()
                cont.resume(returning: data)
            }
        }) {
            recorder.record("photoOutputAttached", "ok", outputProbeData)
        }

        let bayerURL = fixturesDir.appendingPathComponent("fixture-bayer-rich.dng")
        if let bayerData = try? Data(contentsOf: bayerURL) {
            recorder.record("cirawControlsBayer", "ok", CIRAWProbes.controlReadbackProbe(data: bayerData))
            recorder.record("edrHeadroomBayer", "ok", CIRAWProbes.edrProbe(data: bayerData))
        } else {
            recorder.record("cirawControlsBayer", "skipped", .string("no captured bayer fixture"))
        }
    }

    let photoGranted = await PhotoKitProbes.requestAuthorization()
    recorder.record("photoKitPermission", photoGranted ? "ok" : "denied")
    if photoGranted, let dng = fixtureData ?? (try? Data(contentsOf: docs.appendingPathComponent("fixtures/fixture-bayer-rich.dng"))),
       let heic = await PhotoKitProbes.makeSmallHEIC(from: dng) {
        let shapes = await PhotoKitProbes.probeShapes(dng: dng, heic: heic)
        let encoder = JSONEncoder()
        let shapesData = (try? encoder.encode(shapes)) ?? Data()
        let shapesJSON = (try? JSONDecoder().decode([JSONValue].self, from: shapesData)) ?? []
        recorder.record("photoKitShapes", "ok", .array(shapesJSON))
    } else {
        recorder.record("photoKitShapes", "skipped")
    }

    recorder.record("trap-probe", "crash-expected")
    if let dng = fixtureData ?? (try? Data(contentsOf: docs.appendingPathComponent("fixtures/fixture-bayer-rich.dng"))) {
        _ = CIRAWProbes.trapProbe(data: dng)
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
