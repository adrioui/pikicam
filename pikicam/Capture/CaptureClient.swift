// periphery:ignore
import AVFoundation
import CoreGraphics
import Foundation

public protocol CaptureClient: Sendable {
    var capabilities: DeviceCapabilities { get async }
    var sessionStates: AsyncStream<SessionState> { get }
    var readings: AsyncStream<DeviceReadings> { get }
    var meters: AsyncStream<MeterReading> { get }
    var preview: PreviewSource { get }
    func start(lens: LensKind) async throws(CaptureError)
    func stop() async
    func apply(_ settings: CameraSettings) async throws(CaptureError)
    func capture(_ request: CaptureRequest) async throws(CaptureError) -> RawCapture
}

public protocol Developer: Sendable {
    func image(
        _ dng: Data, look: LookParameters, geometry: FrameGeometry, target: PreviewTarget
    ) async throws(DevelopError) -> DisplayImage
    func export(_ dng: Data, look: LookParameters, geometry: FrameGeometry) async throws(DevelopError) -> Rendition?
    func inspect(_ dng: Data) async throws(DevelopError) -> DNGFacts
}

public protocol Library: Sendable {
    func save(
        _ raw: RawCapture, rendition: Rendition?, payload: AdjustmentPayload
    ) async throws(LibraryError) -> LibraryItem
    func saveVideo(_ clip: VideoClip, payload: AdjustmentPayload) async throws(LibraryError) -> LibraryItem
    func saveScan(
        _ result: ScanResult, rendition: Rendition?, payload: AdjustmentPayload
    ) async throws(LibraryError) -> LibraryItem
    func items() async -> [LibraryItem]
    func dng(for id: AssetID) async throws(LibraryError) -> Data
    func commitEdit(_ id: AssetID, payload: AdjustmentPayload, rendition: Rendition?) async throws(LibraryError)
    func revert(_ id: AssetID) async throws(LibraryError)
    func delete(_ id: AssetID) async throws(LibraryError)
    var changes: AsyncStream<[LibraryItem]> { get }
}

public protocol Journal: Sendable {
    func persist(
        _ raw: RawCapture, geometry: FrameGeometry, look: LookParameters
    ) async throws(JournalError) -> JournalEntry
    func pending() async throws(JournalError) -> [JournalEntry]
    func dngData(for id: CaptureID) async throws(JournalError) -> Data
    func complete(_ id: CaptureID) async throws(JournalError)
}

public protocol RecordingClient: Sendable {
    var states: AsyncStream<RecordingState> { get }
    func start(
        _ intent: RecordingIntent, settings: CameraSettings, look: LookParameters, mono: MonoState?)
        async throws(RecordingError)
    func stop() async throws(RecordingError) -> VideoClip
    func setMono(_ mono: MonoState?) async
    func setZoom(_ factor: CGFloat) async
}

public protocol ScanClient: Sendable {
    var states: AsyncStream<ScanState> { get }
    func start(_ config: ScanConfig, settings: CameraSettings) async throws(ScanError)
    func stop() async throws(ScanError) -> ScanResult
}

public protocol PermissionClient: Sendable {
    var states: AsyncStream<[PermissionState]> { get }
    func request(_ permission: PikicamPermission) async -> PermissionState
    func current(_ permission: PikicamPermission) async -> PermissionState
}

public enum PikicamPermission: String, Hashable, Sendable, CaseIterable {
    case camera
    case photoLibrary
}

public protocol MotionClient: Sendable {
    var level: AsyncStream<LevelReading> { get }
}

public protocol ThumbnailStore: Sendable {
    func thumbnail(for item: LibraryItem, dng: Data, look: LookParameters) async throws(DevelopError) -> Data
}

public final class PreviewSource: @unchecked Sendable {
    private let provider: @Sendable () -> AVCaptureVideoPreviewLayer?

    public init(provider: @escaping @Sendable () -> AVCaptureVideoPreviewLayer?) {
        self.provider = provider
    }

    public var layer: AVCaptureVideoPreviewLayer? { provider() }
}
