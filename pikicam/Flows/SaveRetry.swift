import Foundation

enum SaveRetry {
    static func perform(
        deps: Dependencies, raw: RawCapture, rendition: Rendition?, payload: AdjustmentPayload
    ) async throws(LibraryError) -> LibraryItem {
        let policy = RetryPolicy<LibraryError>(attempts: 3, backoff: [0.5, 1, 2])
        for attempt in 0..<policy.attempts {
            do {
                return try await deps.library.save(raw, rendition: rendition, payload: payload)
            } catch {
                if attempt == policy.attempts - 1 || attempt >= policy.backoff.count {
                    throw error
                }
                try? await deps.clock.sleep(for: .seconds(policy.backoff[attempt]))
                if Task.isCancelled {
                    throw error
                }
            }
        }
        preconditionFailure("retry loop invariant: last attempt always returns or throws")
    }
}
