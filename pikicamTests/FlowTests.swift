import Foundation
import Photos
import Testing
import XCTest

@testable import pikicam

final class FlowTests: XCTestCase {
    private func makeRequest() -> CaptureRequest {
        CaptureRequest(
            id: CaptureID(),
            geometry: FrameGeometry(aspect: .native, crop: 1, sensorWidth: 4032, sensorHeight: 3024),
            settings: .standard(lens: .wide)
        )
    }

    func testCaptureHappyPathJournaledAndCompleted() async throws {
        let deps = Dependencies.fake(scenario: .standard)
        let flow = CaptureFlow(deps: deps)
        let item = try await flow.run(makeRequest())
        let pending = try await deps.journal.pending()
        XCTAssertTrue(pending.isEmpty, "journal must be empty after a completed save")
        XCTAssertEqual(item.developState, .developed)
    }

    func testDevelopFailureSavesPendingWithoutRendition() async throws {
        let deps = Dependencies.fake(scenario: .developFails)
        let flow = CaptureFlow(deps: deps)
        let item = try await flow.run(makeRequest())
        XCTAssertEqual(item.developState, .pending)
        let pending = try await deps.journal.pending()
        XCTAssertTrue(pending.isEmpty, "capture is saved even when develop fails")
    }

    func testSaveTransientFailureRetriesThenSucceeds() async throws {
        let deps = Dependencies.fake(scenario: .saveFailsTransient)
        let flow = CaptureFlow(deps: deps)
        let item = try await flow.run(makeRequest())
        XCTAssertEqual(item.developState, .developed)
    }

    func testStorageFullSurfacesTypedError() async {
        let deps = Dependencies.fake(scenario: .storageFull)
        let flow = CaptureFlow(deps: deps)
        do {
            _ = try await flow.run(makeRequest())
            XCTFail("expected storageFull")
        } catch {
            XCTAssertEqual(error, CameraError.library(.storageFull))
        }
        let pending: [JournalEntry] = (try? await deps.journal.pending()) ?? []
        XCTAssertEqual(pending.count, 1, "journal retains the capture for recovery")
    }

    func testRecoveryCompletesPendingEntryExactlyOnce() async throws {
        let deps = Dependencies.fake(scenario: .standard)
        let request = makeRequest()
        let raw = try await deps.capture.capture(request)
        _ = try await deps.journal.persist(raw, geometry: request.geometry, look: .standard)
        let recovery = RecoveryFlow(deps: deps)
        try await recovery.run()
        let pending = try await deps.journal.pending()
        XCTAssertTrue(pending.isEmpty)
        let items = await deps.library.items()
        XCTAssertEqual(items.count, 1)
    }

    func testRecordStartStopProducesClip() async throws {
        let deps = Dependencies.fake(scenario: .standard)
        let intent = RecordingIntent(mode: .res1080p30, audio: false)
        try await deps.recording.start(intent, settings: .standard(lens: .wide), look: .standard, mono: nil)
        let clip = try await deps.recording.stop()
        XCTAssertGreaterThan(clip.duration, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: clip.originalURL.path))
    }

    func testRecorderFailureIsTyped() async {
        let deps = Dependencies.fake(scenario: .recorderFails)
        let intent = RecordingIntent(mode: .res1080p30, audio: false)
        do {
            try await deps.recording.start(intent, settings: .standard(lens: .wide), look: .standard, mono: nil)
            XCTFail("expected writer failure")
        } catch {
            XCTAssertEqual(error, RecordingError.writerFailed(code: -11862))
        }
    }

    func testScanHappyPathProducesResult() async throws {
        let deps = Dependencies.fake(scenario: .standard)
        let config = ScanConfig(axis: .horizontal, slitWidth: 8, outputLength: 48, frameRate: 30)
        try await deps.scan.start(config, settings: .standard(lens: .wide))
        let result = try await deps.scan.stop()
        XCTAssertFalse(result.isPartial)
        XCTAssertEqual(result.frameCount, 48)
    }

    func testScanStallIsTyped() async {
        let deps = Dependencies.fake(scenario: .scanStalls)
        let config = ScanConfig(axis: .horizontal, slitWidth: 8, outputLength: 48, frameRate: 30)
        do {
            try await deps.scan.start(config, settings: .standard(lens: .wide))
            XCTFail("expected stall")
        } catch {
            XCTAssertEqual(error, ScanError.framesStalled)
        }
    }

    func testAdjustmentCodecRoundTripAndForeign() throws {
        let payload = AdjustmentPayload(
            look: LookParameters(exposureEV: -1, mono: MonoState(preset: .red)),
            geometry: .placeholder, recipeVersion: NeutralRecipe.version, decoderVersion: 8, provenance: .placeholder
        )
        let data = AdjustmentCodec.encode(payload)
        XCTAssertEqual(data.formatIdentifier, AdjustmentPayload.formatIdentifier)
        let decoded = try AdjustmentCodec.decode(data)
        XCTAssertEqual(decoded.look.exposureEV, -1)
        XCTAssertEqual(decoded.look.mono?.preset, .red)

        let foreign = PHAdjustmentData(formatIdentifier: "com.apple.photos", formatVersion: "1", data: Data([1]))
        do {
            _ = try AdjustmentCodec.decode(foreign)
            XCTFail("expected foreign")
        } catch {
            XCTAssertEqual(error, AdjustmentCodec.DecodeError.foreign(formatIdentifier: "com.apple.photos"))
        }
    }

    func testJournalCrashRecoveryRoundTrip() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("journal-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let journal = FileJournal(root: root)
        let request = makeRequest()
        let deps = Dependencies.fake(scenario: .standard)
        let raw = try await deps.capture.capture(request)
        _ = try await journal.persist(raw, geometry: request.geometry, look: LookParameters(exposureEV: 0.5))
        let pending = try await journal.pending()
        XCTAssertEqual(pending.count, 1)
        let data = try await journal.dngData(for: raw.id)
        XCTAssertEqual(data, raw.dng)
        try await journal.complete(raw.id)
        let after = try await journal.pending()
        XCTAssertTrue(after.isEmpty)
    }
}
