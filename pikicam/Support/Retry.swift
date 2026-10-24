// periphery:ignore
import Foundation

extension RetryPolicy {
    func run(_ operation: @Sendable () async throws(E) -> Void, clock: any Clock<Duration>) async throws(E) {
        for attempt in 0..<max(attempts, 1) {
            do {
                try await operation()
                return
            } catch {
                if attempt >= attempts - 1 || attempt >= backoff.count {
                    throw error
                }
                let delay = backoff[attempt]
                try? await clock.sleep(for: .seconds(delay))
                if Task.isCancelled {
                    throw error
                }
            }
        }
    }
}
