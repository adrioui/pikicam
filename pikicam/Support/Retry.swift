// periphery:ignore
import Foundation

extension RetryPolicy {
    func run<A: Sendable>(
        _ operation: @escaping @Sendable () async throws(E) -> A,
        clock: any Clock<Duration>
    ) async throws(E) -> A {
        for attempt in 0..<max(attempts, 1) {
            do {
                return try await operation()
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
        fatalError("retry loop invariant: attempts >= 1 always returns or throws")
    }
}

func retrying<E: Error, A: Sendable>(
    _ policy: RetryPolicy<E>,
    clock: any Clock<Duration>,
    _ operation: @escaping @Sendable () async throws(E) -> A
) async throws(E) -> A {
    try await policy.run(operation, clock: clock)
}
