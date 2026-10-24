// periphery:ignore
import Foundation

#if DEBUG

    actor FakeJournal: Journal {
        private var entries: [JournalEntry]
        private var data: [CaptureID: Data]

        init() {
            self.entries = []
            self.data = [:]
        }

        func persist(
            _ raw: RawCapture, geometry: FrameGeometry, look: LookParameters
        ) throws(JournalError) -> JournalEntry {
            let entry = JournalEntry(
                id: raw.id,
                capturedAt: raw.provenance.capturedAt,
                phase: .captured,
                geometry: geometry,
                look: look,
                provenance: raw.provenance
            )
            entries.append(entry)
            data[raw.id] = raw.dng
            return entry
        }

        func pending() -> [JournalEntry] {
            entries.filter { $0.phase != .saved }
        }

        func dngData(for id: CaptureID) throws(JournalError) -> Data {
            guard let dng = data[id] else { throw JournalError.corrupt(id) }
            return dng
        }

        func complete(_ id: CaptureID) {
            entries.removeAll { $0.id == id }
            data[id] = nil
        }
    }

    actor FakeRecordingClient: RecordingClient {
        private let scenario: FakeScenario
        private var continuation: AsyncStream<RecordingState>.Continuation?

        nonisolated var states: AsyncStream<RecordingState> {
            AsyncStream { continuation in
                Task { await self.register(continuation) }
            }
        }

        init(scenario: FakeScenario) {
            self.scenario = scenario
        }

        private func register(_ continuation: AsyncStream<RecordingState>.Continuation) {
            self.continuation = continuation
            continuation.yield(.idle)
        }

        func start(
            _ intent: RecordingIntent, settings: CameraSettings, look: LookParameters, mono: MonoState?
        ) throws(RecordingError) {
            if scenario == .recorderFails {
                throw RecordingError.writerFailed(code: -11862)
            }
            continuation?.yield(.recording(since: Date()))
        }

        func stop() throws(RecordingError) -> VideoClip {
            continuation?.yield(.idle)
            guard
                let original = TemporaryClipFile.write(name: "fake-original", payload: Data([0x66, 0x74, 0x79, 0x70])),
                let renditionPayload = try? Data(contentsOf: original),
                let rendition = TemporaryClipFile.write(name: "fake-rendition", payload: renditionPayload)
            else {
                throw RecordingError.writerFailed(code: -1)
            }
            return VideoClip(
                id: ClipID(),
                originalURL: original,
                renditionURL: rendition,
                mode: .res1080p30,
                duration: 2,
                droppedFrames: 0,
                provenanceEvents: [ProvenanceEvent(timestamp: 0, kind: "start", detail: "fake")]
            )
        }

        func setMono(_ mono: MonoState?) {}
        func setZoom(_ factor: CGFloat) {}
    }

    enum TemporaryClipFile {
        static func write(name: String, payload: Data) -> URL? {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name)-\(UUID().uuidString).mov")
            do {
                try payload.write(to: url, options: [.atomic])
                return url
            } catch {
                return nil
            }
        }
    }

    actor FakeScanClient: ScanClient {
        private let scenario: FakeScenario
        private var continuation: AsyncStream<ScanState>.Continuation?

        nonisolated var states: AsyncStream<ScanState> {
            AsyncStream { continuation in
                Task { await self.register(continuation) }
            }
        }

        init(scenario: FakeScenario) {
            self.scenario = scenario
        }

        private func register(_ continuation: AsyncStream<ScanState>.Continuation) {
            self.continuation = continuation
            continuation.yield(.idle)
        }

        func start(_ config: ScanConfig, settings: CameraSettings) throws(ScanError) {
            if scenario == .scanStalls {
                throw ScanError.framesStalled
            }
            continuation?.yield(.scanning(progress: 0, since: Date()))
        }

        func stop() throws(ScanError) -> ScanResult {
            continuation?.yield(.idle)
            return ScanResult(
                id: CaptureID(),
                assemblyBytes: Data(repeating: 7, count: 64 * 48 * 2),
                width: 64,
                height: 48,
                config: ScanConfig(axis: .horizontal, slitWidth: 8, outputLength: 48, frameRate: 30),
                frameCount: 48,
                droppedFrames: 0,
                duration: 1.6,
                isPartial: false
            )
        }
    }

    actor FakePermissions: PermissionClient {
        private let scenario: FakeScenario
        private var continuation: AsyncStream<[PermissionState]>.Continuation?

        nonisolated var states: AsyncStream<[PermissionState]> {
            AsyncStream { continuation in
                Task { await self.register(continuation) }
            }
        }

        init(scenario: FakeScenario) {
            self.scenario = scenario
        }

        private func register(_ continuation: AsyncStream<[PermissionState]>.Continuation) {
            self.continuation = continuation
            continuation.yield(currentAll())
        }

        private func currentAll() -> [PermissionState] {
            let camera: PermissionState = scenario == .deniedPermissions ? .denied : .granted
            let photos: PermissionState = scenario == .deniedPermissions ? .denied : .granted
            return [camera, photos]
        }

        func request(_ permission: PikicamPermission) -> PermissionState {
            currentAll()[permission == .camera ? 0 : 1]
        }

        func current(_ permission: PikicamPermission) -> PermissionState {
            currentAll()[permission == .camera ? 0 : 1]
        }
    }

    actor FakeMotion: MotionClient {
        nonisolated var level: AsyncStream<LevelReading> {
            AsyncStream { continuation in
                continuation.yield(LevelReading(rollDegrees: 0, pitchDegrees: 0))
                continuation.finish()
            }
        }
    }

    struct DiskThumbnailFake: ThumbnailStore {
        func thumbnail(for item: LibraryItem, dng: Data, look: LookParameters) throws(DevelopError) -> Data {
            guard let cg = SolidImage.make(size: CGSize(width: 32, height: 32), tone: 128),
                let data = SolidImage.heicData(from: cg)
            else {
                throw DevelopError.encodeFailed
            }
            return data
        }
    }

#endif
