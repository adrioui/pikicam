import AVFoundation
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

    private var sessionTask: Task<Void, Never>?
    private var captureFlow: CaptureFlow { CaptureFlow(deps: deps) }

    init(deps: Dependencies) {
        self.deps = deps
    }

    func start() async {
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
        } catch {
            lastError = "\(error)"
        }
        let recovery = RecoveryFlow(deps: deps)
        try? await recovery.run()
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
        shutterState = .capturing(request.id)
        do {
            let item = try await captureFlow.run(request)
            shutterState = .saving(request.id)
            lastThumbnail = try? await deps.thumbnails.thumbnail(
                for: item, dng: Data(), look: .standard
            )
            shutterState = .ready
        } catch {
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
