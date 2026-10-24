import Synchronization
import Testing
import XCTest

@testable import pikicam

private struct WrapperError: Error, Equatable, Sendable {
    let code: Int
}

private struct FlowError: Error, Equatable, Sendable {
    let code: Int

    init(code: Int) {
        self.code = code
    }

    init(mapping error: WrapperError) {
        self.code = error.code + 1000
    }
}

private let attemptState = Mutex(0)
@Sendable private func transientBody() async throws(WrapperError) {
    let attempt = attemptState.withLock { state -> Int in
        state += 1
        return state
    }
    if attempt < 3 {
        throw WrapperError(code: attempt)
    }
}

@Sendable private func alwaysFailingBody() async throws(WrapperError) {
    throw WrapperError(code: 1)
}

@Sendable private func slowBody() async throws(FlowError) -> Int {
    try? await Task.sleep(nanoseconds: 400_000_000)
    return 1
}

final class SupportWrapperTests: XCTestCase {
    func testMapErrorTransformsDeclaredErrorOnly() async {
        func body() async throws(WrapperError) -> Int {
            throw WrapperError(code: 7)
        }
        do {
            _ = try await mapError(FlowError.init(mapping:), body)
            XCTFail("expected throw")
        } catch {
            XCTAssertEqual(error, FlowError(code: 1007))
        }
    }

    func testMapErrorPassesThroughSuccess() async throws {
        func body() async throws(WrapperError) -> Int { 42 }
        let value = try await mapError(FlowError.init(mapping:), body)
        XCTAssertEqual(value, 42)
    }

    func testRetrySucceedsAfterTransientFailures() async throws {
        attemptState.withLock { $0 = 0 }
        let policy = RetryPolicy<WrapperError>(attempts: 3, backoff: [0, 0])
        try await policy.run(transientBody, clock: ContinuousClock())
        XCTAssertEqual(attemptState.withLock { $0 }, 3)
    }

    func testRetryExhaustsAndThrowsLast() async {
        let policy = RetryPolicy<WrapperError>(attempts: 2, backoff: [0, 0])
        do {
            try await policy.run(alwaysFailingBody, clock: ContinuousClock())
            XCTFail("expected throw")
        } catch {
            XCTAssertEqual(error, WrapperError(code: 1))
        }
    }

    func testTimeoutFiresOnTimeoutBranch() async {
        do {
            _ = try await withTimeout(
                .milliseconds(10), clock: ContinuousClock(), onTimeout: { FlowError(code: -99) }, slowBody)
            XCTFail("expected timeout")
        } catch {
            XCTAssertEqual(error, FlowError(code: -99))
        }
    }

    func testFlowExemplarCompilesAndRunsThroughFakes() async throws {
        let deps = Dependencies.fake(scenario: .standard)
        let request = CaptureRequest(
            id: CaptureID(),
            geometry: FrameGeometry(aspect: .native, crop: 1, sensorWidth: 4032, sensorHeight: 3024),
            settings: .standard(lens: .wide)
        )
        let raw = try await deps.capture.capture(request)
        let entry = try await deps.journal.persist(raw, geometry: request.geometry, look: .standard)
        let payload = AdjustmentPayload(entry, rendition: nil)
        _ = try await deps.library.save(raw, rendition: nil, payload: payload)
        try await deps.journal.complete(entry.id)
        let remaining = try await deps.journal.pending()
        XCTAssertTrue(remaining.isEmpty)
    }
}
