import AVFoundation
import Photos
import SwiftUI

@MainActor
@Observable
final class CameraModel {
    enum Mode: String, CaseIterable {
        case photo
        case video
        case scan
    }

    let deps: Dependencies

    var settings = CameraSettings.standard(lens: .wide)
    var shutterState: ShutterState = .ready
    var mode: Mode = .photo
    var activeLine: Int = 0
    var sessionState: SessionState = .idle
    var capabilities: DeviceCapabilities?
    var lastError: String?
    var lastThumbnail: Data?
    var isLevelsVisible = false
    var isLibraryPresented = false
    var recordState: RecordingState = .idle
    var scanState: ScanState = .idle
    var mono: MonoState?

    private var sessionTask: Task<Void, Never>?
    private var captureFlow: CaptureFlow { CaptureFlow(deps: deps) }

    init(deps: Dependencies) {
        self.deps = deps
    }

    func start() async {
        WalkMark.mark("camera-start-begin")
        await refreshCapabilities()
        sessionTask = Task { [weak self] in
            guard let states = self?.deps.capture.sessionStates else { return }
            for await state in states {
                guard let self else { return }
                self.sessionState = state
                if case .failed(let error) = state {
                    self.lastError = "\(error)"
                    self.shutterState = .failed(.capture(error))
                }
            }
        }
        do {
            try await deps.capture.start(lens: settings.lens)
            WalkMark.mark("session-started")
        } catch {
            WalkMark.mark("session-start-failed")
            lastError = "\(error)"
        }
        if ProcessInfo.processInfo.arguments.contains("-pikicam.selfwalk") {
            WalkMark.mark("selfwalk-shutter")
            await pressShutter()
            await reportPhotoPermission()
            WalkMark.mark("selfwalk-done")
        }
    }

    private func reportPhotoPermission() async {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        WalkMark.mark("photos-permission-\(status == .authorized ? "authorized" : (status == .limited ? "limited" : "not-granted"))")
    }

    func stop() {
        sessionTask?.cancel()
        Task { await deps.capture.stop() }
    }

    func refreshCapabilities() async {
        capabilities = await deps.capture.capabilities
    }

    func selectLens(_ kind: LensKind) async {
        guard capabilities?.lens(kind) != nil else { return }
        settings.lens = kind
        await deps.capture.stop()
        do {
            try await deps.capture.start(lens: kind)
        } catch {
            lastError = "\(error)"
        }
    }

    func pressShutter() async {
        guard case .ready = shutterState else { return }
        if settings.timer != .off {
            await runCountdown(settings.timer.rawValue)
            guard case .ready = shutterState else { return }
        }
        let request = CaptureRequest(id: CaptureID(), geometry: geometry(), settings: settings)
        WalkMark.mark("shutter-pressed")
        shutterState = .capturing(request.id)
        do {
            let item = try await captureFlow.run(request)
            WalkMark.mark("capture-flow-done")
            shutterState = .saving(request.id)
            lastThumbnail = try? await deps.thumbnails.thumbnail(
                for: item, dng: Data(), look: .standard
            )
            shutterState = .ready
        } catch {
            WalkMark.mark("capture-flow-failed")
            shutterState = .failed(error)
            lastError = "\(error)"
        }
    }

    private func runCountdown(_ seconds: Int) async {
        for remaining in stride(from: seconds, through: 1, by: -1) {
            shutterState = .countdown(remaining: remaining)
            try? await deps.clock.sleep(for: .seconds(1))
        }
    }

    func toggleRecording() async {
        switch recordState {
        case .idle, .failed:
            recordState = .requesting
            do {
                try await deps.recording.start(
                    RecordingIntent(mode: .res1080p30, audio: false),
                    settings: settings, look: .standard, mono: mono
                )
                recordState = .recording(since: Date())
            } catch {
                recordState = .failed(error)
                lastError = "\(error)"
            }
        case .recording(let since):
            recordState = .stopping
            do {
                let clip = try await deps.recording.stop()
                _ = try await deps.library.saveVideo(clip, payload: AdjustmentPayload(
                    look: .standard, geometry: .placeholder,
                    recipeVersion: NeutralRecipe.version, decoderVersion: 8, provenance: nil
                ))
                recordState = .idle
            } catch let error as RecordingError {
                recordState = .failed(error)
                lastError = "\(error)"
            } catch let libraryError as LibraryError {
                lastError = "\(libraryError)"
            } catch {
                lastError = "\(error)"
            }
            _ = since
        case .requesting, .stopping:
            break
        }
    }

    func toggleScan() async {
        switch scanState {
        case .idle, .failed:
            let config = ScanConfig(axis: .horizontal, slitWidth: 8, outputLength: 1080, frameRate: 30)
            do {
                try await deps.scan.start(config, settings: settings)
                scanState = .scanning(progress: 0, since: Date())
            } catch {
                scanState = .failed(error)
                lastError = "\(error)"
            }
        case .scanning:
            scanState = .finishing
            do {
                let result = try await deps.scan.stop()
                let rendition = try? await deps.developer.export(
                    result.assemblyBytes, look: currentLook(), geometry: .placeholder
                )
                _ = try? await deps.library.saveScan(
                    result, rendition: rendition, payload: AdjustmentPayload(
                        look: currentLook(), geometry: .placeholder,
                        recipeVersion: NeutralRecipe.version, decoderVersion: 8, provenance: nil
                    )
                )
                scanState = .idle
            } catch {
                scanState = .failed(error)
                lastError = "\(error)"
            }
        case .finishing:
            break
        }
    }

    private func currentLook() -> LookParameters {
        var look = LookParameters()
        look.mono = mono
        look.line = activeLine
        return look
    }

    func selectLine(_ number: Int) {
        guard let line = LineProfile.line(number), !line.isDormant else { return }
        activeLine = number
        if let look = line.look {
            settings.aspect = look.line == nil ? settings.aspect : settings.aspect
        }
        if let mono = line.mono {
            settings = settings
            _ = mono
        }
    }

    private func geometry() -> FrameGeometry {
        let dims = capabilities?.rawDimensions ?? CGSize(width: 4032, height: 3024)
        return FrameGeometry(
            aspect: settings.aspect, crop: settings.crop,
            sensorWidth: dims.width, sensorHeight: dims.height
        )
    }

    var statusBadge: String {
        let megaPixels = capabilities.map { $0.rawDimensions.width * $0.rawDimensions.height / 1_000_000 } ?? 0
        let focal = capabilities?.lens(settings.lens)?.equivalentFocalLength ?? 26
        return "[ RAW · \(focal)MM · (\(Int(megaPixels))) ]"
    }
}
