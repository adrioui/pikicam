import Foundation

struct Dependencies: Sendable {
    var capture: any CaptureClient
    var developer: any Developer
    var library: any Library
    var journal: any Journal
    var recording: any RecordingClient
    var scan: any ScanClient
    var permissions: any PermissionClient
    var motion: any MotionClient
    var thumbnails: any ThumbnailStore
    var clock: any Clock<Duration>

    static func live() -> Dependencies {
        Dependencies(
            capture: AVCaptureClient(),
            developer: CoreImageDeveloper(),
            library: InMemoryLibrary(scenario: .standard),
            journal: FakeJournal(),
            recording: FakeRecordingClient(scenario: .standard),
            scan: FakeScanClient(scenario: .standard),
            permissions: FakePermissions(scenario: .standard),
            motion: FakeMotion(),
            thumbnails: DiskThumbnailFake(),
            clock: ContinuousClock()
        )
    }

    static func fake(scenario: FakeScenario) -> Dependencies {
        Dependencies(
            capture: FakeCaptureClient(scenario: scenario),
            developer: FakeDeveloper(scenario: scenario),
            library: InMemoryLibrary(scenario: scenario),
            journal: FakeJournal(),
            recording: FakeRecordingClient(scenario: scenario),
            scan: FakeScanClient(scenario: scenario),
            permissions: FakePermissions(scenario: scenario),
            motion: FakeMotion(),
            thumbnails: DiskThumbnailFake(),
            clock: ContinuousClock()
        )
    }
}
